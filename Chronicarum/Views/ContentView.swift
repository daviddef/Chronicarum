import SwiftUI

/// The launch sequence, which is now a single screen rather than three.
///
/// It used to be: an animated splash, fading to a map, with a grey list sheet thrown over
/// the top — read as three unrelated screens inside two seconds, and the sheet-over-sheet
/// made the planner unreliable to reach. `StartView` *is* the splash: it plays the same
/// intro, then settles into the menu without anything being dismissed or presented.
///
/// The map lives underneath and is revealed by choosing "just show me the map", so nothing
/// is a toll gate — and the ✨ in the map's top bar brings the question back.
struct RootView: View {
    /// Persisted, so the walkthrough is a first-run event, not an every-launch one.
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showOnboarding = false
    /// True until the map is asked for. Not a sheet — the start screen is the root.
    @State private var showStart = true

    /// The map is not built until it is wanted, and never torn down once it is.
    ///
    /// Building it eagerly behind the start screen — even at zero opacity — forced the
    /// 294,820-site catalogue to parse before SwiftUI could draw a single frame, so the
    /// static launch screen sat there for seconds and the splash animation played to
    /// nobody. The opening screen needs none of that data; it asks a question.
    @State private var hasEnteredApp = false

    var body: some View {
        ZStack {
            if hasEnteredApp {
                ContentView(showOnboarding: $showOnboarding, showStart: $showStart)
                    .opacity(showStart ? 0 : 1)
            }

            if showStart {
                StartView {
                    hasEnteredApp = true
                    withAnimation(.easeInOut(duration: 0.35)) { showStart = false }
                    if !hasSeenOnboarding { showOnboarding = true }
                }
                .transition(.opacity)
            }
        }
        .onChange(of: showStart) { _, isShowing in
            // Coming back to the question from the map must not discard the map.
            if isShowing { hasEnteredApp = true }
        }
        .onChange(of: showOnboarding) { _, isShowing in
            if !isShowing { hasSeenOnboarding = true }
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
