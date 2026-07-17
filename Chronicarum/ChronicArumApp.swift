import SwiftUI

@main
struct ChronicArumApp: App {

    @StateObject private var locationService: LocationService
    @StateObject private var mapVM: MapViewModel
    @StateObject private var siteVM = SiteViewModel()

    init() {
        let locationService = LocationService()
        _locationService = StateObject(wrappedValue: locationService)
        _mapVM = StateObject(wrappedValue: MapViewModel(locationService: locationService))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(mapVM)
                .environmentObject(siteVM)
                .environmentObject(locationService)
        }
    }
}
