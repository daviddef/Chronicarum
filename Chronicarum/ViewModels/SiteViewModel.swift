import Foundation
import CoreLocation
import Combine

@MainActor
final class SiteViewModel: ObservableObject {

    @Published var searchText: String = ""
    @Published private(set) var bookmarkedIDs: Set<String> = []
    @Published private(set) var visitedIDs: Set<String> = []
    @Published private(set) var visitDates: [String: Date] = [:]
    @Published var selectedEra: Era? = nil
    @Published var selectedType: SiteType? = nil

    private let persistence: PersistenceService

    /// Saved state is read once at construction; every mutation below writes straight
    /// back through, so a bookmark survives the app being killed.
    init(persistence: PersistenceService = .shared) {
        self.persistence = persistence
        self.bookmarkedIDs = persistence.bookmarkedIDs
        self.visitedIDs = persistence.visitedIDs
        self.visitDates = persistence.visitDates
    }

    // MARK: - Travel record

    /// A summary of everywhere the user has been, in the spirit of the archive loops that
    /// actually retain people (Letterboxd's stats, Polarsteps' superlatives) rather than
    /// a score. Every figure is derived from data already stored — nothing new to collect.
    struct TravelRecord {
        var visitedCount: Int
        var countries: Int
        var oldestSite: Site?
        var furthestSite: Site?
        var furthestKm: Int?
        var lastVisit: Date?
        var eraCounts: [(era: Era, count: Int)]
    }

    /// `from` is the user's location when known, used only for the "furthest" superlative.
    func travelRecord(from origin: CLLocationCoordinate2D? = nil) -> TravelRecord {
        let sites = visitedSites

        // Ranks eras by how long ago they began, so "oldest" means earliest in time
        // rather than first in the enum. Undated and geological sites can't be ranked.
        let order: [Era: Int] = [.ancient: 0, .classical: 1, .medieval: 2,
                                 .renaissance: 3, .modern: 4]
        let oldest = sites
            .compactMap { site in order[site.era].map { (site, $0) } }
            .min { $0.1 < $1.1 }?.0

        var furthest: Site?
        var furthestKm: Int?
        if let origin {
            let here = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
            let ranked = sites
                .map { ($0, here.distance(from: CLLocation(latitude: $0.latitude,
                                                            longitude: $0.longitude))) }
                .max { $0.1 < $1.1 }
            furthest = ranked?.0
            furthestKm = ranked.map { Int(($0.1 / 1000).rounded()) }
        }

        let counts = Dictionary(grouping: sites, by: \.era)
            .map { (era: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }

        return TravelRecord(
            visitedCount: sites.count,
            countries: Set(sites.map { $0.location.split(separator: ",").last.map(String.init)?
                .trimmingCharacters(in: .whitespaces) ?? $0.location }).count,
            oldestSite: oldest,
            furthestSite: furthest,
            furthestKm: furthestKm,
            lastVisit: visitDates.values.max(),
            eraCounts: counts
        )
    }

    /// Sorted once, not per keystroke. `filteredSites` is recomputed on every character
    /// typed, and re-sorting ~24k sites each time was its dominant cost. Filtering
    /// preserves order, so the sort hoists out. Tier-descending also keeps the curated
    /// sites (tier 3–5) above the bulk layer (tier 2) for free.
    private static let sitesByTier: [Site] = SiteData.all.sorted { $0.tier > $1.tier }

    var allSites: [Site] { Self.sitesByTier }

    var filteredSites: [Site] {
        // Cheap predicates first: era/type are enum compares, the text search is
        // locale-aware and far more expensive, so && short-circuits away most of it.
        allSites.filter { site in
            guard selectedEra == nil  || site.era == selectedEra   else { return false }
            guard selectedType == nil || site.type == selectedType else { return false }
            guard !searchText.isEmpty else { return true }

            return site.name.localizedCaseInsensitiveContains(searchText)
                || site.location.localizedCaseInsensitiveContains(searchText)
                || site.civilisation.localizedCaseInsensitiveContains(searchText)
        }
    }

    var bookmarkedSites: [Site] {
        allSites.filter { bookmarkedIDs.contains($0.id) }
    }

    var visitedSites: [Site] {
        allSites.filter { visitedIDs.contains($0.id) }
    }

    func toggleBookmark(_ site: Site) {
        if bookmarkedIDs.contains(site.id) {
            bookmarkedIDs.remove(site.id)
        } else {
            bookmarkedIDs.insert(site.id)
        }
        persistence.bookmarkedIDs = bookmarkedIDs
    }

    /// Toggles rather than only setting: marking a site visited by mistake should be
    /// undoable, and the Saved tab offers no other way to take it back.
    func toggleVisited(_ site: Site, on date: Date = Date()) {
        if visitedIDs.contains(site.id) {
            visitedIDs.remove(site.id)
            visitDates[site.id] = nil
        } else {
            visitedIDs.insert(site.id)
            visitDates[site.id] = date
        }
        persistence.visitedIDs = visitedIDs
        persistence.visitDates = visitDates
    }

    func visitDate(for site: Site) -> Date? { visitDates[site.id] }

    func isBookmarked(_ site: Site) -> Bool {
        bookmarkedIDs.contains(site.id)
    }

    func isVisited(_ site: Site) -> Bool {
        visitedIDs.contains(site.id)
    }

    func nearbySites(to site: Site, radiusKm: Double = 100) -> [Site] {
        let origin = CLLocation(latitude: site.latitude, longitude: site.longitude)
        return allSites
            .filter { $0.id != site.id }
            .map { (site: $0, metres: origin.distance(from: CLLocation(latitude: $0.latitude,
                                                                       longitude: $0.longitude))) }
            .filter { $0.metres <= radiusKm * 1000 }
            .sorted { $0.metres < $1.metres }
            .map(\.site)
    }
}
