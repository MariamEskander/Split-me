import SwiftUI
import SwiftData

struct GroupsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SavedGroup.name) private var groups: [SavedGroup]
    @State private var editing: SavedGroup?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.canvas.ignoresSafeArea()
                    .onTapGesture { KeyboardDismisser.dismiss() }

                if groups.isEmpty {
                    VStack(spacing: 26) {
                        Spacer()
                        EmptyStateView(
                            title: "No groups yet",
                            message: "Save the people you split with often and every new bill starts with them already added."
                        ) {
                            BrandArtView(art: .teamTrip, width: 150, tilt: -4)
                        }
                        Button {
                            newGroup()
                        } label: {
                            Label("Create a group", systemImage: "plus")
                        }
                        .buttonStyle(PrimaryButtonStyle(fullWidth: false))
                        Spacer()
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(groups) { group in
                            Button { editing = group } label: {
                                GroupCard(group: group)
                            }
                            .buttonStyle(.plain)
                            .plainListRow()
                        }
                        .onDelete { offsets in
                            for index in offsets { context.delete(groups[index]) }
                        }
                        Color.clear.frame(height: 8).plainListRow()
                    }
                    .listStyle(.plain)
                    .splitmeCanvas()
                }
            }
            .navigationTitle("Groups")
            .toolbarBackground(Theme.canvas, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { LanguageToggle() }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: newGroup) {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.onAccent)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Theme.brandGradient))
                    }
                    .accessibilityLabel("New group")
                }
            }
            .sheet(item: $editing) { group in
                GroupEditorView(group: group)
            }
        }
    }

    private func newGroup() {
        let group = SavedGroup(name: "", memberNames: [])
        context.insert(group)
        editing = group
    }
}

private struct GroupCard: View {
    let group: SavedGroup

    var body: some View {
        HStack(spacing: 14) {
            AvatarCluster(names: group.memberNames,
                          colorIndexes: Array(group.memberNames.indices),
                          limit: 3)
            VStack(alignment: .leading, spacing: 3) {
                (group.name.isEmpty ? Text("Untitled group") : Text(verbatim: group.name))
                    .font(Theme.label(16, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                (group.memberNames.isEmpty
                 ? Text("No members yet")
                 : Text(verbatim: group.memberNames.joined(separator: " · ")))
                    .font(Theme.label(13))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
        }
        .card()
    }
}

private struct GroupEditorView: View {
    @Bindable var group: SavedGroup
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var draft = ""
    @FocusState private var draftFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.canvas.ignoresSafeArea()
                    .onTapGesture { KeyboardDismisser.dismiss() }
                ScrollView {
                    VStack(spacing: 14) {
                        nameCard
                        membersCard
                    }
                    .padding(Theme.gutter)
                }
                .splitmeCanvas()
            }
            .navigationTitle(group.name.isEmpty ? Text("New group") : Text(verbatim: group.name))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.canvas, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: finish)
                        .font(Theme.label(16, weight: .semibold))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var nameCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Theme.accentSoft))
            TextField("Group name, e.g. Work lunch", text: $group.name)
                .font(Theme.label(16, weight: .medium))
        }
        .card()
    }

    private var membersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Members",
                          trailing: group.memberNames.isEmpty ? nil : "\(group.memberNames.count)")

            ForEach(Array(group.memberNames.enumerated()), id: \.offset) { index, _ in
                VStack(spacing: 0) {
                    memberRow(index: index)
                    if index < group.memberNames.count - 1 {
                        Divider().overlay(Theme.hairline)
                    }
                }
            }

            HStack(spacing: 12) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 30)
                TextField("Add a person", text: $draft)
                    .font(Theme.label(15))
                    .focused($draftFocused)
                    .onSubmit { add(); draftFocused = true }
                    .submitLabel(.next)
                if !draft.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button("Add", action: add)
                        .font(Theme.label(14, weight: .bold))
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .card()
    }

    private func memberRow(index: Int) -> some View {
        HStack(spacing: 12) {
            Avatar(name: group.memberNames[index], colorIndex: index, size: 30)
            TextField("Name", text: Binding(
                get: { index < group.memberNames.count ? group.memberNames[index] : "" },
                set: { if index < group.memberNames.count { group.memberNames[index] = $0 } }
            ))
            .font(Theme.label(15))
            .multilineTextAlignment(.leading)
            Spacer()
            Button {
                var updated = group.memberNames
                updated.remove(at: index)
                withAnimation { group.memberNames = updated }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 9)
    }

    private func add() {
        let name = draft.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        withAnimation(.easeOut(duration: 0.18)) { group.memberNames.append(name) }
        draft = ""
    }

    private func finish() {
        add()
        group.memberNames = group.memberNames
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if group.name.trimmingCharacters(in: .whitespaces).isEmpty, group.memberNames.isEmpty {
            context.delete(group)
        }
        dismiss()
    }
}
