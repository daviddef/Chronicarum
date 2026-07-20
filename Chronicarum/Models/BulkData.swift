import Foundation

/// The bulk catalogue layer, decoded from the bundled columnar import.
///
/// Bulk sites carry a name, a place, a type, a best-effort era and a one-line description
/// — not the curated storyboards the featured sites have.
///
/// The on-disk shape is **columnar**: one array per field, rather than an array of
/// records. That is a performance decision, measured on a Release build at 187,507 rows:
///
///     JSONDecoder over [BulkSite]          1,457 ms      40 MB
///     JSONSerialization, row dictionaries  1,918 ms      40 MB
///     JSONSerialization, columnar            967 ms      29 MB
///
/// Reaching for `JSONSerialization` to escape `Codable` made it *worse*: it returns
/// `NSDictionary`, so every `row["name"] as? String` crosses the Objective-C bridge, and
/// ~1.9M bridged casts cost more than the reflection they replaced. Columnar pays that
/// cost once per field instead of once per row — ten array casts, then indexed access.
///
/// `bulk_sites.json` remains the row-wise source of truth for the import scripts and is
/// excluded from the app target; `scripts/build_columnar.py` produces what ships.
enum BulkSite {

    static func loadColumnar(from data: Data) -> [Site] {
        guard let columns = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ids       = columns["id"]      as? [String],
              let names     = columns["name"]    as? [String],
              let lats      = columns["lat"]     as? [Double],
              let lons      = columns["lon"]     as? [Double],
              let types     = columns["type"]    as? [String],
              let eras      = columns["era"]     as? [String],
              let countries = columns["country"] as? [String],
              let descs     = columns["desc"]    as? [String],
              let images    = columns["img"]     as? [String],
              let sources   = columns["src"]     as? [String]
        else { return [] }

        // A short column would mean a truncated write; better an empty layer than rows
        // silently paired with the wrong name.
        let count = ids.count
        let columnLengths = [names.count, lats.count, lons.count, types.count, eras.count,
                             countries.count, descs.count, images.count, sources.count]
        guard columnLengths.allSatisfy({ $0 == count }) else {
            assertionFailure("bulk_columnar.json has ragged columns — rebuild it")
            return []
        }

        var sites = [Site]()
        sites.reserveCapacity(count)

        for i in 0..<count {
            sites.append(Site(
                id: ids[i],
                name: names[i],
                location: countries[i],
                latitude: lats[i],
                longitude: lons[i],
                era: Era(rawValue: eras[i]) ?? .unknown,
                type: SiteType(rawValue: types[i]) ?? .heritage,
                // Below the curated 3–5 band, so the significance filter doubles as a
                // "featured only" switch — raise the minimum tier to hide the bulk layer.
                tier: 2,
                builtDescription: "—",
                civilisation: "—",
                tagline: descs[i],
                chapters: [],
                nearestAirport: nil,
                bestTimeToVisit: nil,
                visaNote: nil,
                // Absent values are written as "" so each column stays homogeneous.
                imageFile: images[i].isEmpty ? nil : images[i],
                dataSource: sources[i].isEmpty ? nil : DataSource(rawValue: sources[i])
            ))
        }
        return sites
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
        guard let url = Bundle.main.url(forResource: "bulk_columnar", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return BulkSite.loadColumnar(from: data)
    }()
}
