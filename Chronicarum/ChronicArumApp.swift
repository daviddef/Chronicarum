import SwiftUI
import CoreLocation

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
            RootView()
                .environmentObject(mapVM)
                .environmentObject(siteVM)
                .environmentObject(locationService)
#if DEBUG
                .task { Self.renderSamplePDFIfRequested() }
#endif
        }
    }

#if DEBUG
    /// Renders a sample itinerary PDF straight into the app container.
    ///
    /// Debug-only, and behind a launch argument rather than always on: the printed document
    /// is the one artefact that cannot be reviewed by reading the code, and driving the UI
    /// to reach it is not always possible. Launch with `-RenderSamplePDF <lat> <lon>`.
    static func renderSamplePDFIfRequested() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-RenderSamplePDF"),
              arguments.count > index + 2,
              let lat = Double(arguments[index + 1]),
              let lon = Double(arguments[index + 2]) else { return }

        let origin = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let plan = TripPlanner.plan(from: origin, themes: [], days: 3)
        let data = ItineraryPDF.render(plan, placeName: "Bath")
        let url = URL.documentsDirectory.appendingPathComponent("sample.pdf")
        try? data.write(to: url)
        NSLog("[sample-pdf] wrote \(data.count) bytes to \(url.path)")
    }
#endif
}
