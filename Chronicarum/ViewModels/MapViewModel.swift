import Foundation
import SwiftUI
import MapKit
import Combine

@MainActor
final class MapViewModel: ObservableObject {

    // MARK: - Map state

    /// Drives the map camera. Assign to move the map.
    @Published var cameraPosition: MapCameraPosition = .region(MapViewModel.mediterraneanRegion)

    /// Mirrors what the map is actually showing — kept in sync via `onMapCameraChange`.
    /// Read this (not `cameraPosition`) when you need the current span, e.g. to zoom relative to it.
    @Published var visibleRegion: MKCoordinateRegion = MapViewModel.mediterraneanRegion

    @Published var selectedSite: Site? = nil
    @Published var userLocation: CLLocationCoordinate2D? = nil
    @Published var isLocating: Bool = false
    @Published var locationError: String? = nil

    private var hasRequestedInitialLocation = false
    /// True between "the map appeared" and "we've centred once on a fix".
    private var wantsInitialCentre = false
    /// Set the moment the user pans or zooms, so a late location fix can't yank the map.
    private(set) var hasUserMovedMap = false

    // MARK: - Filters
    @Published var activeEras: Set<Era> = Set(Era.allCases)
    @Published var activeTypes: Set<SiteType> = Set(SiteType.allCases)
    @Published var minimumTier: Int = 1

    /// What the user is actually interested in — "castles and Roman history". Empty means
    /// no preference expressed, which shows everything; see `Site.matches(themes:)`.
    @Published var activeThemes: Theme = []

    // MARK: - Conquest timeline
    @Published var timelineState: TimelineState = TimelineState()

    // MARK: - Map style

    /// Cycled from the controls rail. Satellite earns its place here more than in most
    /// apps: the Nazca Lines, Giza and Uluru are shapes you can only read from above.
    enum StyleMode: String, CaseIterable {
        case standard, hybrid, imagery

        var icon: String {
            switch self {
            case .standard: return "map"
            case .hybrid:   return "globe.americas"
            case .imagery:  return "globe.americas.fill"
            }
        }

        var label: String {
            switch self {
            case .standard: return "Map"
            case .hybrid:   return "Hybrid"
            case .imagery:  return "Satellite"
            }
        }

        var next: StyleMode {
            let all = StyleMode.allCases
            return all[(all.firstIndex(of: self)! + 1) % all.count]
        }
    }

    @Published var styleMode: StyleMode = .standard

    func cycleMapStyle() {
        styleMode = styleMode.next
    }

    // MARK: - Dependencies
    private let locationService: LocationService
    private var cancellables = Set<AnyCancellable>()

    init(locationService: LocationService) {
        self.locationService = locationService
        bindLocationService()
        bindClusterInputs()
    }

    /// Recomputes the clusters when — and only when — one of their inputs changes: the
    /// visible region (set by `onMapCameraChange` and `setRegion`) or any of the filters.
    /// `CombineLatest4` fires once immediately, which populates the initial clusters.
    ///
    /// The recompute takes its inputs as parameters rather than reading them back off
    /// `self`. `@Published` emits during `willSet`, so at the moment this fires the stored
    /// properties still hold their *previous* values — reading them here would leave the
    /// map one update behind every pan.
    private func bindClusterInputs() {
        // CombineLatest4 is at its arity limit, so the two scalar filters travel together
        // as a pair rather than reaching for CombineLatest5 (which does not exist).
        let filters = Publishers.CombineLatest($minimumTier, $activeThemes)
        Publishers.CombineLatest4($visibleRegion, $activeEras, $activeTypes, filters)
            .sink { [weak self] region, eras, types, filters in
                self?.recomputeClusters(region: region, eras: eras, types: types,
                                        minTier: filters.0, themes: filters.1)
            }
            .store(in: &cancellables)
    }

    private func bindLocationService() {
        locationService.$userLocation
            .compactMap { $0 }
            .sink { [weak self] coordinate in
                guard let self else { return }
                self.userLocation = coordinate
                // Only follow the user to their location when they asked us to;
                // otherwise a background fix would yank the map out from under them.
                if self.isLocating {
                    self.isLocating = false
                    guard !self.hasUserMovedMap else { return }
                    self.setRegion(MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 5, longitudeDelta: 5)
                    ))
                } else {
                    // An unsolicited fix — from the authorisation callback — still counts
                    // for the open-where-I-am behaviour.
                    self.centreOnInitialFix(coordinate)
                }
            }
            .store(in: &cancellables)

        locationService.$error
            .sink { [weak self] error in
                guard let self else { return }
                guard let error else { self.locationError = nil; return }
                self.isLocating = false
                self.locationError = error.localizedDescription
            }
            .store(in: &cancellables)
    }

    // MARK: - Derived
    var visibleSites: [Site] {
        SiteData.all.filter { site in
            activeEras.contains(site.era) &&
            activeTypes.contains(site.type) &&
            site.tier >= minimumTier &&
            site.matches(themes: activeThemes)
        }
    }

    /// Sites bucketed into grid cells sized relative to the current zoom, so a dense
    /// region collapses to a few count-bubbles when zoomed out and breaks apart as you
    /// zoom in. Recomputes when `visibleRegion` changes (via `onMapCameraChange`).
    ///
    /// Culls to the visible region (plus a margin) *before* clustering. With a catalogue
    /// of tens of thousands this is essential — without it, a zoomed-in view would still
    /// build an annotation for every distant off-screen site. Culled span ≈ 1.2× the
    /// screen and cells are span/9, so the on-screen marker count stays near ~100
    /// regardless of zoom or catalogue size.
    ///
    /// Stored, not computed. As a computed property this re-filtered all 24k sites on
    /// every SwiftUI `body` pass — including passes triggered by entirely unrelated state
    /// such as presenting a sheet or ticking the timeline animation. It now recomputes
    /// only when something it actually depends on changes.
    @Published private(set) var clusteredItems: [SiteCluster] = []

    private func recomputeClusters(region: MKCoordinateRegion,
                                   eras: Set<Era>,
                                   types: Set<SiteType>,
                                   minTier: Int,
                                   themes: Theme) {
        let latPad = region.span.latitudeDelta  * 0.6
        let lonPad = region.span.longitudeDelta * 0.6
        let latMin = region.center.latitude  - latPad, latMax = region.center.latitude  + latPad
        let lonMin = region.center.longitude - lonPad, lonMax = region.center.longitude + lonPad

        // Bounds first: it rejects most of the catalogue with two comparisons, before the
        // set lookups run.
        let inView = SiteData.all.filter { site in
            site.latitude  >= latMin && site.latitude  <= latMax &&
            site.longitude >= lonMin && site.longitude <= lonMax &&
            eras.contains(site.era) && types.contains(site.type) && site.tier >= minTier &&
            // Cheapest of the four — an integer AND — but it goes last because bounds
            // already rejected most of the catalogue and this is the least selective
            // when no preference is set.
            site.matches(themes: themes)
        }
        clusteredItems = Self.cluster(inView, in: region)
    }

    /// Number of grid columns across the visible span. Higher = finer cells = sites
    /// merge only when very close on screen.
    private static let clusterDivisions = 9.0

    static func cluster(_ sites: [Site], in region: MKCoordinateRegion) -> [SiteCluster] {
        let cellLat = max(region.span.latitudeDelta / clusterDivisions, 0.00001)
        let cellLon = max(region.span.longitudeDelta / clusterDivisions, 0.00001)

        var buckets: [String: [Site]] = [:]
        for site in sites {
            let row = (site.latitude  / cellLat).rounded(.down)
            let col = (site.longitude / cellLon).rounded(.down)
            buckets["\(row):\(col)", default: []].append(site)
        }

        return buckets.map { key, group in
            // Centroid keeps the bubble visually over its members.
            let lat = group.reduce(0) { $0 + $1.latitude }  / Double(group.count)
            let lon = group.reduce(0) { $0 + $1.longitude } / Double(group.count)
            return SiteCluster(id: key,
                               coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                               sites: group)
        }
    }

    var nearestSite: (site: Site, distanceKm: Int)? {
        guard let userLoc = userLocation else { return nil }
        let origin = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
        let nearest = SiteData.all
            .map { (site: $0, metres: origin.distance(from: CLLocation(latitude: $0.latitude,
                                                                       longitude: $0.longitude))) }
            .min { $0.metres < $1.metres }
        guard let nearest else { return nil }
        return (site: nearest.site, distanceKm: Int((nearest.metres / 1000).rounded()))
    }

    // MARK: - Default regions
    static let mediterraneanRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37, longitude: 22),
        span: MKCoordinateSpan(latitudeDelta: 35, longitudeDelta: 50)
    )

    static let worldRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 160, longitudeDelta: 360)
    )

    // MARK: - Actions

    func selectSite(_ site: Site) {
        selectedSite = site
    }

    func clearSelection() {
        selectedSite = nil
    }

    func zoomToSite(_ site: Site, span: Double = 0.5) {
        setRegion(MKCoordinateRegion(
            center: site.coordinate,
            span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
        ))
    }

    func resetToDefaultView() {
        setRegion(MapViewModel.mediterraneanRegion)
    }

    /// Zooms to frame a cluster's members. Returns the site to open directly when the
    /// group can't be split further (all members share one point, e.g. the Mona Lisa
    /// and the Louvre) — the caller shows its detail instead of leaving a dead tap.
    @discardableResult
    func expandCluster(_ cluster: SiteCluster) -> Site? {
        let lats = cluster.sites.map(\.latitude)
        let lons = cluster.sites.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return nil }

        // Members effectively co-located — zooming would never separate them.
        if maxLat - minLat < 0.0005 && maxLon - minLon < 0.0005 {
            return cluster.representative
        }

        setRegion(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                           longitude: (minLon + maxLon) / 2),
            span: MKCoordinateSpan(latitudeDelta: max((maxLat - minLat) * 1.5, 0.15),
                                   longitudeDelta: max((maxLon - minLon) * 1.5, 0.15))
        ))
        return nil
    }

    /// A random notable site, flown to and selected — the "show me something" button.
    ///
    /// Drawn from the curated sites plus World Heritage entries with a photo, not the
    /// whole catalogue: a uniform pick across 24k would usually land on a minor regional
    /// museum, which is accurate but a poor answer to "surprise me".
    /// Sensitive sites are excluded: a dice roll is a playful surface, and landing a user
    /// on a death camp as a fun surprise is exactly the failure this guard exists for.
    private static let surprisePool: [Site] = {
        let curated = SiteData.featured
        let heritage = SiteData.bulk.filter { $0.type == .heritage && $0.imageFile != nil }
        return (curated + heritage).filter { !$0.isSensitive }
    }()

    @discardableResult
    func surpriseMe() -> Site? {
        // Avoid repeating the site already on screen when the pool allows it.
        let pool = Self.surprisePool.filter { $0.id != selectedSite?.id }
        guard let site = pool.randomElement() ?? Self.surprisePool.randomElement() else { return nil }
        selectSite(site)
        setRegion(MKCoordinateRegion(
            center: site.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        ))
        return site
    }

    /// Asks for a location fix and centres the map on it once it arrives.
    func requestUserLocation() {
        isLocating = true
        locationError = nil
        locationService.requestLocation()
    }

    /// Called once when the map first appears, so the app opens where the user is rather
    /// than in the Mediterranean.
    ///
    /// Sets `isLocating`, which is what makes the fix recentre the map — but the sink
    /// checks `hasUserMovedMap` first, so a fix arriving after the user has already
    /// started panning is recorded without hijacking their view. A location prompt on a
    /// map screen is expected; a map that jumps out from under you is not.
    func requestInitialLocationIfNeeded() {
        guard !hasRequestedInitialLocation else { return }
        hasRequestedInitialLocation = true
        wantsInitialCentre = true

        // A fix may already be in hand: LocationService requests one as soon as it sees
        // an authorised status, which typically resolves before the map's first layout.
        // Asking again here would also race that in-flight request — CLLocationManager
        // cancels the earlier one and reports a failure, which is what silently defeated
        // the first version of this.
        if let existing = userLocation {
            centreOnInitialFix(existing)
        } else {
            locationService.requestLocation()
        }
    }

    /// Centres once, on whichever fix arrives first, and never against the user's wishes.
    private func centreOnInitialFix(_ coordinate: CLLocationCoordinate2D) {
        guard wantsInitialCentre, !hasUserMovedMap else { return }
        wantsInitialCentre = false
        setRegion(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 3, longitudeDelta: 3)
        ))
    }

    func setRegion(_ region: MKCoordinateRegion) {
        expectedRegion = region
        visibleRegion = region
        cameraPosition = .region(region)
    }

    /// Called from `onMapCameraChange`. Distinguishes our own camera writes from the
    /// user's gestures, so a location fix arriving mid-pan doesn't hijack the view.
    ///
    /// Compares against the region we last asked for rather than using a simple flag:
    /// the map settles at *approximately* what we requested (MapKit adjusts the span to
    /// the view's aspect ratio), and `onMapCameraChange` also fires once on first layout
    /// before any interaction. A flag treated that first layout as a user gesture, which
    /// silently defeated the whole start-at-my-location feature.
    func noteCameraChanged(to region: MKCoordinateRegion) {
        if let expected = expectedRegion, Self.regionsRoughlyMatch(expected, region) {
            // Deliberately *not* cleared. MapKit emits onMapCameraChange more than once
            // for a single settle — twice on first layout with an identical region — so
            // consuming the expectation on first match made the second event look like a
            // user gesture and silently cancelled the open-at-my-location behaviour.
            // Keeping it means only a genuinely different region counts as movement.
        } else {
            hasUserMovedMap = true
        }
        visibleRegion = region
    }

    /// Seeded with the initial camera, so the first layout event is recognised as ours.
    private var expectedRegion: MKCoordinateRegion? = MapViewModel.mediterraneanRegion

    private static func regionsRoughlyMatch(_ a: MKCoordinateRegion,
                                            _ b: MKCoordinateRegion) -> Bool {
        // Within a tenth of the span counts as "the map landed where we put it".
        let latTolerance = max(a.span.latitudeDelta, b.span.latitudeDelta) * 0.1
        let lonTolerance = max(a.span.longitudeDelta, b.span.longitudeDelta) * 0.1
        return abs(a.center.latitude - b.center.latitude) <= latTolerance
            && abs(a.center.longitude - b.center.longitude) <= lonTolerance
    }

    func zoomIn() {
        var r = visibleRegion
        r.span.latitudeDelta  = max(r.span.latitudeDelta  * 0.5, 0.2)
        r.span.longitudeDelta = max(r.span.longitudeDelta * 0.5, 0.2)
        setRegion(r)
    }

    func zoomOut() {
        var r = visibleRegion
        r.span.latitudeDelta  = min(r.span.latitudeDelta  * 2.0, 160)
        r.span.longitudeDelta = min(r.span.longitudeDelta * 2.0, 360)
        setRegion(r)
    }

    func toggleConquest() {
        timelineState.isVisible.toggle()
    }

    func advanceTimeline() {
        let next = timelineState.periodIndex + 1
        guard next < TimelineData.periods.count else { return }
        timelineState.periodIndex = next
    }

    func rewindTimeline() {
        let prev = timelineState.periodIndex - 1
        guard prev >= 0 else { return }
        timelineState.periodIndex = prev
    }

    func playTimeline() {
        guard !timelineState.isAnimating else {
            timelineState.isAnimating = false
            return
        }
        timelineState.isAnimating = true
        animateNext()
    }

    private func animateNext() {
        guard timelineState.isAnimating else { return }
        let next = timelineState.periodIndex + 1
        if next >= TimelineData.periods.count {
            timelineState.isAnimating = false
            return
        }
        Task {
            try? await Task.sleep(for: .seconds(3.2))
            guard timelineState.isAnimating else { return }
            timelineState.periodIndex = next
            animateNext()
        }
    }
}
