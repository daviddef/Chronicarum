import Foundation

/// A lightweight site decoded from the bundled Wikidata import (`bulk_sites.json`).
///
/// Kept separate from `Site`'s own Codable so the compact on-disk shape (short keys, no
/// chapters/facts) stays decoupled from the app model. Bulk sites carry a name, a place,
/// a type, a best-effort era, and a one-line description — not the curated storyboards
/// the featured sites have.
struct BulkSite: Decodable {
    let id: String
    let name: String
    let lat: Double
    let lon: Double
    let type: String
    let era: String
    let country: String
    let desc: String
    /// Wikimedia Commons filename; absent for the ~7% of sites with no P18 image.
    let img: String?

    var asSite: Site {
        Site(
            id: id,
            name: name,
            location: country,
            latitude: lat,
            longitude: lon,
            era: Era(rawValue: era) ?? .unknown,
            type: SiteType(rawValue: type) ?? .heritage,
            // Below the curated 3–5 band, so the significance filter doubles as a
            // "featured only" switch — raise the minimum tier to hide the bulk layer.
            tier: 2,
            builtDescription: "—",
            civilisation: "—",
            tagline: desc,
            chapters: [],
            nearestAirport: nil,
            bestTimeToVisit: nil,
            visaNote: nil,
            imageFile: img
        )
    }
}

extension SiteData {
    /// The full catalogue: curated featured sites first, then the bulk import.
    static let all: [Site] = featuredWithPhotos + bulk

    /// The hand-authored sites are written in Swift and carry no Wikidata id, so they
    /// have no photo of their own. The import records the Commons image of each bulk
    /// entry it dropped as a duplicate of a curated site — that mapping is applied here.
    private static let featuredWithPhotos: [Site] = {
        let photos = loadJSON([String: String].self, named: "featured_images") ?? [:]
        return featured.map { site in
            guard site.imageFile == nil, let file = photos[site.id] else { return site }
            var copy = site
            copy.imageFile = file
            return copy
        }
    }()

    private static func loadJSON<T: Decodable>(_ type: T.Type, named name: String) -> T? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    /// Decoded once, lazily, from the app bundle. An absent or unreadable file yields an
    /// empty layer rather than a crash — the featured sites still work.
    static let bulk: [Site] = {
        guard let rows = loadJSON([BulkSite].self, named: "bulk_sites") else { return [] }
        return rows.map(\.asSite)
    }()
}
