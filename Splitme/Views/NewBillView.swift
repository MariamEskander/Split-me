import SwiftUI
import SwiftData

/// Collects the title, currency and the people, then hands back an unsaved Bill.
struct NewBillView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \SavedGroup.lastUsedAt, order: .reverse) private var groups: [SavedGroup]

    var onCreate: (Bill) -> Void

    @State private var title = ""
    @State private var currencyCode = AppDefaults.currencyCode
    @State private var names: [String] = []
    @State private var draftName = ""
    @State private var saveAsGroupName = ""
    @State private var places = PlacePicker()
    @State private var chosenPlace: Place?
    @FocusState private var draftFocused: Bool

    private var trimmedNames: [String] {
        names.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.canvas.ignoresSafeArea()
                    .onTapGesture { KeyboardDismisser.dismiss() }
                ScrollView {
                    VStack(spacing: 14) {
                        BrandArtView(art: .fairIsFun, width: 112, tilt: -4)
                        whereCard
                        if !groups.isEmpty { groupStrip }
                        peopleCard
                        if trimmedNames.count >= 2 { saveGroupCard }
                        Button("Create bill", action: create)
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(trimmedNames.count < 2)
                            .opacity(trimmedNames.count < 2 ? 0.45 : 1)
                            .padding(.top, 4)
                    }
                    .padding(Theme.gutter)
                }
                .splitmeCanvas()
            }
            .navigationTitle("New bill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.canvas, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Cards

    private var whereCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: chosenPlace?.symbol ?? "fork.knife")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Theme.accentSoft))

                VStack(alignment: .leading, spacing: 1) {
                    TextField("Where were you?", text: $title)
                        .font(Theme.label(16, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .onChange(of: title) { _, newValue in
                            // Typing invalidates a previously tapped place, and
                            // searches Maps around here for what was typed.
                            if let chosenPlace, chosenPlace.name != newValue {
                                self.chosenPlace = nil
                            }
                            if places.hasLocation { places.search(newValue) }
                        }
                    if let detail = chosenPlace?.detail {
                        Text(verbatim: detail)
                            .font(Theme.label(11))
                            .foregroundStyle(Theme.textTertiary)
                            .lineLimit(1)
                    }
                }

                nearbyControl
            }

            placeSuggestions

            Divider().overlay(Theme.hairline)
            HStack {
                Text("Currency")
                    .font(Theme.label(14))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Picker("", selection: $currencyCode) {
                    ForEach(Self.currencyOptions, id: \.self) { Text(verbatim: $0).tag($0) }
                }
                .pickerStyle(.menu)
                .tint(Theme.accent)
            }
        }
        .card()
    }

    /// Location is requested only when tapped — the sheet does not fire a
    /// permission prompt at someone who just wants to type a name.
    @ViewBuilder
    private var nearbyControl: some View {
        switch places.status {
        case .locating, .searching:
            ProgressView().controlSize(.small).tint(Theme.accent)
        case .denied:
            EmptyView()
        default:
            Button {
                places.findNearby()
            } label: {
                Image(systemName: "location.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(7)
                    .background(Circle().fill(Theme.accentSoft))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Find nearby places")
        }
    }

    @ViewBuilder
    private var placeSuggestions: some View {
        switch places.status {
        case .ready(let found):
            VStack(spacing: 0) {
                ForEach(found) { place in
                    Button {
                        title = place.name
                        chosenPlace = place
                        places.dismiss()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: place.symbol)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.accent)
                                .frame(width: 18)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(verbatim: place.name)
                                    .font(Theme.label(14, weight: .medium))
                                    .foregroundStyle(Theme.textPrimary)
                                    .lineLimit(1)
                                if let detail = place.detail {
                                    Text(verbatim: detail)
                                        .font(Theme.label(11))
                                        .foregroundStyle(Theme.textTertiary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if place.id != found.last?.id {
                        Divider().overlay(Theme.hairline)
                    }
                }
            }
            .padding(.horizontal, 2)

        case .noResults:
            note("Nothing found nearby — just type the name.")
        case .denied:
            note("Location is off, so nearby places can't be suggested. Typing still works.")
        case .failed(let message):
            note(verbatim: message)
        case .idle, .locating, .searching:
            EmptyView()
        }
    }

    private func note(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(Theme.label(11))
            .foregroundStyle(Theme.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// For provider error text, which is already in the system's words.
    private func note(verbatim text: String) -> some View {
        Text(verbatim: text)
            .font(Theme.label(11))
            .foregroundStyle(Theme.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var groupStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Start from a group")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(groups) { group in
                        GroupPill(group: group, isActive: names == group.memberNames) {
                            withAnimation(.easeOut(duration: 0.2)) { names = group.memberNames }
                            group.lastUsedAt = Date()
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(.horizontal, 4)
    }

    private var peopleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Who is splitting",
                          trailing: trimmedNames.isEmpty ? nil : "\(trimmedNames.count)")

            ForEach(Array(names.enumerated()), id: \.offset) { index, _ in
                VStack(spacing: 0) {
                    personRow(index: index)
                    if index < names.count - 1 { Divider().overlay(Theme.hairline) }
                }
            }

            HStack(spacing: 12) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 30)
                TextField("Add a person", text: $draftName)
                    .font(Theme.label(15))
                    .focused($draftFocused)
                    .onSubmit { addDraft(); draftFocused = true }
                    .submitLabel(.next)
                if !draftName.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button("Add", action: addDraft)
                        .font(Theme.label(14, weight: .bold))
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(.top, names.isEmpty ? 0 : 4)

            if trimmedNames.count < 2 {
                Text("Add at least two people.")
                    .font(Theme.label(12))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .card()
    }

    private func personRow(index: Int) -> some View {
        HStack(spacing: 12) {
            Avatar(name: names[index], colorIndex: index, size: 30)
            TextField("Name", text: Binding(
                get: { index < names.count ? names[index] : "" },
                set: { if index < names.count { names[index] = $0 } }
            ))
            .font(Theme.label(15))
            .multilineTextAlignment(.leading)
            Spacer()
            Button {
                var updated = names
                updated.remove(at: index)
                withAnimation { names = updated }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 9)
    }

    private var saveGroupCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Save as a group")
            HStack(spacing: 12) {
                Image(systemName: "bookmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 28)
                TextField("Optional, e.g. Work lunch", text: $saveAsGroupName)
                    .font(Theme.label(15))
            }
        }
        .card()
    }

    private func addDraft() {
        let name = draftName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        withAnimation(.easeOut(duration: 0.18)) { names.append(name) }
        draftName = ""
    }

    private func create() {
        addDraft()
        let bill = Bill(title: title, currencyCode: currencyCode)
        if let chosenPlace {
            bill.placeName = chosenPlace.name
            bill.placeDetail = chosenPlace.detail
            bill.latitude = chosenPlace.latitude
            bill.longitude = chosenPlace.longitude
        }
        for name in trimmedNames { _ = bill.addParticipant(name: name) }

        let groupName = saveAsGroupName.trimmingCharacters(in: .whitespaces)
        if !groupName.isEmpty {
            let group = SavedGroup(name: groupName, memberNames: trimmedNames)
            group.lastUsedAt = Date()
            context.insert(group)
        }
        onCreate(bill)
        dismiss()
    }

    /// EGP first — the app's home currency — then the ones people here travel
    /// with, then whatever the device is set to if it is none of those.
    static let currencyOptions: [String] = {
        var list = [AppDefaults.currencyCode,
                    "USD", "EUR", "GBP", "SAR", "AED", "KWD", "QAR", "JOD", "TRY"]
        if let local = Locale.current.currency?.identifier, !list.contains(local) {
            list.append(local)
        }
        return list
    }()
}

private struct GroupPill: View {
    var group: SavedGroup
    var isActive: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                AvatarCluster(names: group.memberNames,
                              colorIndexes: Array(group.memberNames.indices),
                              limit: 3)
                Text(group.name)
                    .font(Theme.label(14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text("\(group.memberNames.count) people")
                    .font(Theme.label(11))
                    .foregroundStyle(Theme.textTertiary)
            }
            .frame(width: 132, alignment: .leading)
            .padding(13)
            .background(RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                .fill(isActive ? Theme.accentSoft : Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                .strokeBorder(isActive ? Theme.accent.opacity(0.5) : Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
