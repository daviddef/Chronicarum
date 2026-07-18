import Foundation
import CoreLocation
import Combine

@MainActor
final class SiteViewModel: ObservableObject {

    @Published var searchText: String = ""
    @Published private(set) var bookmarkedIDs: Set<String> = []
    @Published private(set) var visitedIDs: Set<String> = []
    @Published var selectedEra: Era? = nil
    @Published var selectedType: SiteType? = nil

    private let persistence: PersistenceService

    /// Saved state is read once at construction; every mutation below writes straight
    /// back through, so a bookmark survives the app being killed.
    init(persistence: PersistenceService = .shared) {
        self.persistence = persistence
        self.bookmarkedIDs = persistence.bookmarkedIDs
        self.visitedIDs = persistence.visitedIDs
    }

    var allSites: [Site] { SiteData.all }

    var filteredSites: [Site] {
        allSites.filter { site in
            let matchesSearch = searchText.isEmpty ||
                site.name.localizedCaseInsensitiveContains(searchText) ||
                site.location.localizedCaseInsensitiveContains(searchText) ||
                site.civilisation.localizedCaseInsensitiveContains(searchText)

            let matchesEra  = selectedEra == nil  || site.era == selectedEra
            let matchesType = selectedType == nil || site.type == selectedType

            return matchesSearch && matchesEra && matchesType
        }
        .sorted { $0.tier > $1.tier }
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
    func toggleVisited(_ site: Site) {
        if visitedIDs.contains(site.id) {
            visitedIDs.remove(site.id)
        } else {
            visitedIDs.insert(site.id)
        }
        persistence.visitedIDs = visitedIDs
    }

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
