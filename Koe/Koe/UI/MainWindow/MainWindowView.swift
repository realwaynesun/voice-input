import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case home = "Home"
    case history = "History"
    case dictionary = "Dictionary"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: "house"
        case .history: "clock"
        case .dictionary: "book"
        case .settings: "gearshape"
        }
    }
}

struct MainWindowView: View {
    @State private var selection: SidebarItem = .home

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var sidebar: some View {
        List(SidebarItem.allCases, selection: $selection) { item in
            Label(item.rawValue, systemImage: item.icon)
                .tag(item)
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        .safeAreaInset(edge: .top) {
            brandHeader
        }
    }

    private var brandHeader: some View {
        HStack(spacing: 8) {
            Text("Koe")
                .font(.title2)
                .fontWeight(.semibold)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .home: HomeView()
        case .history: HistoryView()
        case .dictionary: DictionaryView()
        case .settings: SettingsView()
        }
    }
}
