import SwiftUI

/// The launch sequence: the splash plays, then the app proper — a tab bar whose first tab
/// is the home hub that everything else is reached from.
struct RootView: View {
    /// Persisted, so the walkthrough is a first-run event, not an every-launch one.
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showOnboarding = false
    /// The splash covers the moment the catalogue parses. The tab view — and the map inside
    /// it — is not built until the splash clears, so the 294,820-site load never blocks the
    /// first frame.
    @State private var showSplash = true
    @State private var hasEnteredApp = false

    var body: some View {
        ZStack {
            if hasEnteredApp {
                ContentView(showOnboarding: $showOnboarding)
                    .opacity(showSplash ? 0 : 1)
            }

            if showSplash {
                SplashView {
                    hasEnteredApp = true
                    withAnimation(.easeInOut(duration: 0.35)) { showSplash = false }
                    if !hasSeenOnboarding { showOnboarding = true }
                }
                .transition(.opacity)
            }
        }
        .onChange(of: showOnboarding) { _, isShowing in
            if !isShowing { hasSeenOnboarding = true }
        }
    }
}

/// The tab bar. Home is the launcher; Map, Explore and Saved are the three places it opens.
/// A single `AppFocus` is shared across all of them, so a search on Home moves the whole app.
struct ContentView: View {
    @Binding var showOnboarding: Bool
    @State private var selectedTab: Tab = .home

    enum Tab: String, CaseIterable {
        case home, map, explore, saved
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab)
                .tabItem { Label("Home", systemImage: "square.grid.2x2.fill") }
                .tag(Tab.home)

            MapRootView(showOnboarding: $showOnboarding)
                .tabItem { Label("Map", systemImage: "map.fill") }
                .tag(Tab.map)

            ExploreView()
                .tabItem { Label("Explore", systemImage: "safari.fill") }
                .tag(Tab.explore)

            SavedView()
                .tabItem { Label("Saved", systemImage: "bookmark.fill") }
                .tag(Tab.saved)
        }
        .tint(Color(hex: "#C9A84C"))
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
        }
    }
}
