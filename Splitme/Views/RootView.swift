import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    #if DEBUG
    @Query(sort: \Bill.createdAt, order: .reverse) private var bills: [Bill]
    #endif

    var body: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-previewEssentials") {
            EssentialsView().tint(Theme.accent).preferredColorScheme(.dark)
        } else if ProcessInfo.processInfo.arguments.contains("-previewCurrency") {
            CurrencyView().tint(Theme.accent).preferredColorScheme(.dark)
        } else if ProcessInfo.processInfo.arguments.contains("-previewArt") {
            ArtGalleryView()
        } else if let tab = SampleData.previewTab, let bill = bills.first {
            NavigationStack {
                BillEditorView(bill: bill, initialTab: tab)
            }
            .tint(Theme.accent)
            .preferredColorScheme(.dark)
        } else {
            main
        }
        #else
        main
        #endif
    }

    private var main: some View {
        TabView {
            BillsListView()
                .tabItem { Label("Bills", systemImage: "doc.plaintext.fill") }
            GroupsView()
                .tabItem { Label("Groups", systemImage: "person.3.fill") }
            EssentialsView()
                .tabItem { Label("Essentials", systemImage: "checklist") }
            CurrencyView()
                .tabItem { Label("Currency", systemImage: "arrow.left.arrow.right") }
        }
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    RootView()
        .modelContainer(for: [Bill.self, SavedGroup.self], inMemory: true)
}

#if DEBUG
/// `-previewArt` renders every piece of brand artwork on the real canvas, so
/// contrast problems (dark artwork on a dark ground) show up before shipping.
private struct ArtGalleryView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(BrandArt.allCases, id: \.rawValue) { art in
                    VStack(spacing: 4) {
                        BrandArtView(art: art, width: art == .highFive ? 300 : 150)
                        Text(art.rawValue)
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                BrandLogo(size: 110)
            }
            .padding(12)
        }
        .background(Theme.canvas)
        .preferredColorScheme(.dark)
    }
}
#endif
