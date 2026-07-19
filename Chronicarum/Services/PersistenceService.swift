import Foundation

/// Simple UserDefaults-backed persistence for bookmarks and visited sites.
/// Phase 2: replace with CloudKit to sync across devices.
final class PersistenceService {

    static let shared = PersistenceService()
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let bookmarked  = "chronicarum.bookmarked"
        static let visited     = "chronicarum.visited"
        static let visitDates  = "chronicarum.visitDates"
    }

    /// When each site was marked visited, keyed by site id.
    ///
    /// Stored separately from `visitedIDs` rather than replacing it, so an install that
    /// already has visits keeps them — they simply carry no date until re-marked. A
    /// migration that dropped the old key would silently erase people's records.
    var visitDates: [String: Date] {
        get {
            guard let raw = defaults.dictionary(forKey: Keys.visitDates) as? [String: Double]
            else { return [:] }
            return raw.mapValues { Date(timeIntervalSince1970: $0) }
        }
        set {
            defaults.set(newValue.mapValues(\.timeIntervalSince1970), forKey: Keys.visitDates)
        }
    }

    var bookmarkedIDs: Set<String> {
        get { Set(defaults.stringArray(forKey: Keys.bookmarked) ?? []) }
        set { defaults.set(Array(newValue), forKey: Keys.bookmarked) }
    }

    var visitedIDs: Set<String> {
        get { Set(defaults.stringArray(forKey: Keys.visited) ?? []) }
        set { defaults.set(Array(newValue), forKey: Keys.visited) }
    }

    func toggleBookmark(siteID: String) {
        var ids = bookmarkedIDs
        if ids.contains(siteID) { ids.remove(siteID) }
        else { ids.insert(siteID) }
        bookmarkedIDs = ids
    }

    func markVisited(siteID: String) {
        var ids = visitedIDs
        ids.insert(siteID)
        visitedIDs = ids
    }
}
