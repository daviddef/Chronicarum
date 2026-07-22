import SwiftUI

/// Wraps the app in its launch sequence: the animated splash plays over the top on cold
/// start, and the first-run walkthrough appears once the splash clears.
struct RootView: View {
    @State private var showSplash = true
    /// Persisted, so the walkthrough is a first-run event, not an every-launch one.
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showOnboarding = false
    /// The app opens by asking what sort of day this is, rather than handing over a map
    /// and a filter panel. Dismissed to the map by "Just the map", and re-openable from
    /// the top bar, so it is an offer rather than a toll gate.
    @State private var showStart = false

    var body: some View {
        ContentView(showOnboarding: $showOnboarding, showStart: $showStart)
            .opacity(showSplash ? 0 : 1)
            .overlay {
                if showSplash {
                    SplashView {
                        withAnimation(.easeInOut(duration: 0.4)) { showSplash = false }
                        // Only after the splash clears, so the walkthrough isn't racing
                        // the intro animation for the screen.
                        if hasSeenOnboarding {
                            showStart = true
                        } else {
                            showOnboarding = true
                        }
                    }
                    .transition(.opacity)
                }
            }
            .onChange(of: showOnboarding) { _, isShowing in
                guard !isShowing else { return }
                hasSeenOnboarding = true
                // Straight from the walkthrough into the question it just explained.
                showStart = true
            }
            .sheet(isPresented: $showStart) {
                StartView { showStart = false }
            }
    }
}

struct ContentView: View {
    @Binding var showOnboarding: Bool
    @Binding var showStart: Bool
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
            MapRootView(showOnboarding: $showOnboarding, showStart: $showStart)
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
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
        }
    }
}

#Preview {
    RootView()
        .environmentObject(MapViewModel(locationService: LocationService()))
        .environmentObject(SiteViewModel())
}
