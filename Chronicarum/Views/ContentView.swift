import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .map

    enum Tab: String, CaseIterable {
        case map     = "Map"
        case explore = "Explore"
        case saved   = "Saved"

        var icon: String {
            switch self {
            case .map:     return "map.fill"
            case .explore: return "safari.fill"
            case .saved:   return "bookmark.fill"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            MapRootView()
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }
                .tag(Tab.map)

            ExploreView()
                .tabItem {
                    Label("Explore", systemImage: "safari.fill")
                }
                .tag(Tab.explore)

            SavedView()
                .tabItem {
                    Label("Saved", systemImage: "bookmark.fill")
                }
                .tag(Tab.saved)
        }
        .tint(Color("AccentGold"))   // define in Assets.xcassets — #C9A84C
    }
}

#Preview {
    ContentView()
        .environmentObject(MapViewModel(locationService: LocationService()))
        .environmentObject(SiteViewModel())
}
