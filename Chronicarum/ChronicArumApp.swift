import SwiftUI
import CoreLocation

@main
struct ChronicArumApp: App {

    @StateObject private var locationService: LocationService
    @StateObject private var mapVM: MapViewModel
    @StateObject private var siteVM = SiteViewModel()
    /// The searched place, shared by every tab and every sheet — injected at the root so a
    /// full-screen cover can never find it missing.
    @StateObject private var focus = AppFocus()
    @StateObject private var recents = RecentTripsStore()

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
                .environmentObject(focus)
                .environmentObject(recents)
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
        let plan = TripPlanner.plan(from: origin, themes: [], days: 3,
                                    lunchMinutes: 60, loopBack: true)
        let data = ItineraryPDF.render(plan, placeName: "Bath")
        let url = URL.documentsDirectory.appendingPathComponent("sample.pdf")
        try? data.write(to: url)
        NSLog("[sample-pdf] wrote \(data.count) bytes to \(url.path)")

        // Also render a trail-walk PDF for the nearest walking trail, so the trail-walk
        // layout can be checked headlessly the same way.
        if let trail = TrailData.near(origin, activity: .walk, radiusKm: 200, limit: 1).first {
            let walk = TrailPlanner.plan(trail: trail, from: origin)
            let walkData = ItineraryPDF.render(walk, placeName: nil)
            let walkURL = URL.documentsDirectory.appendingPathComponent("trailwalk.pdf")
            try? walkData.write(to: walkURL)
            NSLog("[sample-pdf] wrote trail walk (\(walk.trail.name), \(walk.stops.count) stops) "
                  + "\(walkData.count) bytes to \(walkURL.path)")
        }

        // A "With the kids" plan, to check the family layer flows into a real day.
        if let kids = DayIntent.all.first(where: { $0.id == "kids" }) {
            let kidsPlan = TripPlanner.plan(from: origin, themes: kids.themes, days: 1,
                                            mode: kids.mode, tier: kids.tier, types: kids.types)
            let names = kidsPlan.days.flatMap(\.stops).map { "\($0.site.type.rawValue):\($0.site.name)" }
            NSLog("[sample-pdf] kids plan: \(names.joined(separator: " | "))")
            let kidsData = ItineraryPDF.render(kidsPlan, placeName: "With the kids")
            try? kidsData.write(to: URL.documentsDirectory.appendingPathComponent("kids.pdf"))
        }
    }
#endif
}
