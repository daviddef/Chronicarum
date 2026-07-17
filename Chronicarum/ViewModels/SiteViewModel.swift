import Foundation
import CoreLocation
import Combine

@MainActor
final class SiteViewModel: ObservableObject {

    @Published var searchText: String = ""
    @Published var bookmarkedIDs: Set<String> = []
    @Published var visitedIDs: Set<String> = []
    @Published var selectedEra: Era? = nil
    @Published var selectedType: SiteType? = nil

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
        // TODO: persist to UserDefaults / CloudKit
    }

    func markVisited(_ site: Site) {
        visitedIDs.insert(site.id)
        // TODO: persist
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
