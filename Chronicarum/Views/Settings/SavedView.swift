import SwiftUI

struct SavedView: View {
    @EnvironmentObject private var siteVM: SiteViewModel
    @State private var selectedTab: SavedTab = .bookmarked
    @State private var selectedSite: Site? = nil

    enum SavedTab: String, CaseIterable {
        case bookmarked = "Bookmarked"
        case visited    = "Visited"
    }

    var displayedSites: [Site] {
        switch selectedTab {
        case .bookmarked: return siteVM.bookmarkedSites
        case .visited:    return siteVM.visitedSites
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    ForEach(SavedTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                if displayedSites.isEmpty {
                    ContentUnavailableView(
                        selectedTab == .bookmarked ? "No Bookmarks Yet" : "No Visited Sites",
                        systemImage: selectedTab == .bookmarked ? "bookmark" : "checkmark.circle",
                        description: Text(
                            selectedTab == .bookmarked
                            ? "Tap the bookmark icon on any site to save it here."
                            : "Mark sites as visited after you've been there."
                        )
                    )
                } else {
                    List(displayedSites) { site in
                        SiteListRow(site: site)
                            .onTapGesture { selectedSite = site }
                            .swipeActions(edge: .trailing) {
                                if selectedTab == .bookmarked {
                                    Button(role: .destructive) {
                                        siteVM.toggleBookmark(site)
                                    } label: {
                                        Label("Remove", systemImage: "bookmark.slash")
                                    }
                                }
                            }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Saved")
            .sheet(item: $selectedSite) { site in
                SiteDetailView(site: site)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}
