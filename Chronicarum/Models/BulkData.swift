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
            visaNote: nil
        )
    }
}

extension SiteData {
    /// The full catalogue: curated featured sites first, then the bulk import.
    static let all: [Site] = featured + bulk

    /// Decoded once, lazily, from the app bundle. An absent or unreadable file yields an
    /// empty layer rather than a crash — the featured sites still work.
    static let bulk: [Site] = {
        guard let url = Bundle.main.url(forResource: "bulk_sites", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let rows = try? JSONDecoder().decode([BulkSite].self, from: data)
        else { return [] }
        return rows.map(\.asSite)
    }()
}
