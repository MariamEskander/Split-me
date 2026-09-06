import SwiftUI
import SwiftData

/// The list of things you keep forgetting, and the switch that has the phone
/// read them back to you on the way out.
struct EssentialsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Essential.sortIndex) private var essentials: [Essential]

    @State private var reminders = GoingOutReminders()
    @State private var draft = ""
    @FocusState private var draftFocused: Bool

    private var activeNames: [String] {
        essentials.filter(\.isEnabled).map(\.name)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.canvas.ignoresSafeArea()
                    .onTapGesture { KeyboardDismisser.dismiss() }

                ScrollView {
                    VStack(spacing: 14) {
                        armSwitch
                        if essentials.isEmpty { suggestions } else { list }
                        addField
                        if !essentials.isEmpty { previewButton }
                    }
                    .padding(Theme.gutter)
                    .padding(.bottom, 24)
                }
                .splitmeCanvas()
            }
            .navigationTitle("Essentials")
            .toolbarBackground(Theme.canvas, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { LanguageToggle() }
            }
            .task {
                await reminders.refreshStatus()
                await reminders.reschedule(items: activeNames)
            }
            // Whatever is on screen is what is scheduled — no drift.
            .onChange(of: activeNames) { _, names in
                Task { await reminders.reschedule(items: names) }
            }
            .onChange(of: reminders.isEnabled) { _, _ in
                Task { await reminders.reschedule(items: activeNames) }
            }
        }
    }

    // MARK: Arming

    private var armSwitch: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: $reminders.isEnabled) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Remind me on the way out")
                        .font(Theme.label(16, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("A notification when you leave home, listing what is ticked below.")
                        .font(Theme.label(12))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .tint(Theme.accent)

            if reminders.isEnabled {
                Divider().overlay(Theme.hairline)
                statusRows
            }
        }
        .card()
    }

    @ViewBuilder
    private var statusRows: some View {
        switch reminders.readiness {
        case .needsNotificationPermission:
            actionRow(
                icon: "bell.badge",
                title: "Allow notifications",
                detail: "Without them there is nothing to remind you with.",
                button: "Allow"
            ) {
                Task { await reminders.requestNotificationPermission() }
            }

        case .needsLocation:
            actionRow(
                icon: "location.circle",
                title: "Allow location — always",
                detail: "Leaving home can only be noticed if iOS may check your location in the background. Pick “Always” when asked.",
                button: "Allow"
            ) {
                reminders.requestLocationPermission()
            }

        case .needsHome:
            actionRow(
                icon: "house",
                title: "Set home",
                detail: "Stand at home and tap Set — the reminder fires when you leave this spot.",
                button: "Set"
            ) {
                reminders.useCurrentLocationAsHome()
            }

        case .armedByLocation:
            VStack(alignment: .leading, spacing: 12) {
                NoticeBanner(icon: "checkmark.seal.fill",
                             title: "Armed — you'll be reminded when you leave home",
                             detail: nil,
                             tint: Theme.positive)
                HStack {
                    Text("Leaves home after")
                        .font(Theme.label(14))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text("\(Int(reminders.radius)) m")
                        .font(Theme.number(14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                }
                Slider(value: $reminders.radius, in: 100...400, step: 25)
                    .tint(Theme.accent)
                Button("Move home to where I am now") {
                    reminders.useCurrentLocationAsHome()
                }
                .font(Theme.label(13, weight: .semibold))
                .foregroundStyle(Theme.accent)
            }

        case .armedByTime:
            VStack(alignment: .leading, spacing: 12) {
                NoticeBanner(
                    icon: "clock.badge.exclamationmark",
                    title: "Reminding you daily instead",
                    detail: "Location is set to “while using the app”, which cannot notice you leaving. Allow it always for that."
                )
                DatePicker("Remind me at",
                           selection: Binding(
                               get: {
                                   Calendar.current.date(from: DateComponents(
                                       hour: reminders.fallbackHour,
                                       minute: reminders.fallbackMinute)) ?? Date()
                               },
                               set: { date in
                                   let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                                   reminders.fallbackHour = parts.hour ?? 9
                                   reminders.fallbackMinute = parts.minute ?? 0
                                   Task { await reminders.reschedule(items: activeNames) }
                               }),
                           displayedComponents: .hourAndMinute)
                    .font(Theme.label(14))
                    .tint(Theme.accent)
                Button("Switch to Always") {
                    reminders.requestLocationPermission()
                }
                .font(Theme.label(13, weight: .semibold))
                .foregroundStyle(Theme.accent)
            }

        case .off:
            EmptyView()
        }
    }

    private func actionRow(icon: String, title: LocalizedStringKey,
                           detail: LocalizedStringKey, button: LocalizedStringKey,
                           action: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.warning)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Theme.warning.opacity(0.14)))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Theme.label(14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(detail)
                    .font(Theme.label(12))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer(minLength: 6)
            Button(button, action: action)
                .font(Theme.label(13, weight: .bold))
                .foregroundStyle(Theme.accent)
        }
    }

    // MARK: The list

    private var list: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Don't let me forget",
                          trailing: "\(activeNames.count)/\(essentials.count)")

            VStack(spacing: 0) {
                ForEach(essentials) { item in
                    row(item)
                    if item.id != essentials.last?.id {
                        Divider().overlay(Theme.hairline)
                    }
                }
            }
        }
        .card()
    }

    private func row(_ item: Essential) -> some View {
        HStack(spacing: 12) {
            Button {
                item.isEnabled.toggle()
            } label: {
                Image(systemName: item.isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(item.isEnabled ? Theme.accent : Theme.textTertiary)
            }
            .buttonStyle(.plain)

            Image(systemName: item.symbol)
                .font(.system(size: 14))
                .foregroundStyle(item.isEnabled ? Theme.textPrimary : Theme.textTertiary)
                .frame(width: 22)

            TextField("Thing", text: Binding(
                get: { item.name }, set: { item.name = $0 }
            ))
            .font(Theme.label(15))
            .foregroundStyle(item.isEnabled ? Theme.textPrimary : Theme.textTertiary)
            .alignedToReadingEdge(of: item.name)

            Spacer(minLength: 0)

            Button {
                context.delete(item)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 9)
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "What do you forget?")
            Text("Tap the usual suspects, or type your own below.")
                .font(Theme.label(12))
                .foregroundStyle(Theme.textTertiary)

            WrapLayout(spacing: 8, lineSpacing: 8) {
                ForEach(Essential.suggestions, id: \.name) { suggestion in
                    Button {
                        add(name: String(localized: .init(suggestion.name)),
                            symbol: suggestion.symbol)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: suggestion.symbol)
                                .font(.system(size: 11))
                            Text(LocalizedStringKey(suggestion.name))
                                .font(Theme.label(13, weight: .medium))
                        }
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Theme.surfaceSunken))
                        .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .card()
    }

    private var addField: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent)
            TextField("Add something", text: $draft)
                .font(Theme.label(15))
                .focused($draftFocused)
                .onSubmit { commitDraft() }
                .submitLabel(.done)
            if !draft.trimmingCharacters(in: .whitespaces).isEmpty {
                Button("Add") { commitDraft() }
                    .font(Theme.label(14, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .card()
    }

    private var previewButton: some View {
        Button {
            Task { await reminders.sendPreview(items: activeNames) }
        } label: {
            Label("Preview the reminder", systemImage: "bell.badge")
        }
        .buttonStyle(QuietButtonStyle())
        .disabled(activeNames.isEmpty)
        .opacity(activeNames.isEmpty ? 0.45 : 1)
    }

    // MARK: Editing

    private func commitDraft() {
        let name = draft.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        add(name: name, symbol: "shippingbox.fill")
        draft = ""
        draftFocused = true
    }

    private func add(name: String, symbol: String) {
        guard !essentials.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })
        else { return }
        let next = (essentials.map(\.sortIndex).max() ?? -1) + 1
        withAnimation(.easeOut(duration: 0.18)) {
            context.insert(Essential(name: name, symbol: symbol, sortIndex: next))
        }
    }
}
