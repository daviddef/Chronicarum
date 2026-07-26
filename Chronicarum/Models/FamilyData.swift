import Foundation

/// The family layer — playgrounds, parks, beaches, the zoo — decoded from the bundled
/// `family.json` and folded into the catalogue as ordinary `Site`s, so the planner strings a
/// playground into a day beside a castle without knowing it is any different.
///
/// Sourced from OpenStreetMap (ODbL); each row is stamped `dataSource: .openStreetMap` so the
/// attribution shows wherever it appears. Kept as its own bundled file — a collective
/// database, separate from the Wikidata heritage layer — the same footing as the trails.
///
/// Columnar on disk for the same reason the bulk layer is: one array per field decodes far
/// faster than a list of records. These carry no era (a playground has none), so era is
/// `.unknown`; significance is the family-richness score the import computed.
enum FamilyData {

    static func loadColumnar(from data: Data) -> [Site] {
        guard let cols = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ids   = cols["id"]   as? [String],
              let names = cols["name"] as? [String],
              let lats  = cols["lat"]  as? [Double],
              let lons  = cols["lon"]  as? [Double],
              let types = cols["type"] as? [String],
              let sigs  = cols["sig"]  as? [Int],
              let durs  = cols["dur"]  as? [Int],
              let masks = cols["th"]   as? [Int],
              let descs = cols["desc"] as? [String]
        else { return [] }

        let count = ids.count
        guard [names.count, lats.count, lons.count, types.count, sigs.count,
               durs.count, masks.count, descs.count].allSatisfy({ $0 == count }) else {
            assertionFailure("family.json has ragged columns — rebuild it")
            return []
        }

        var sites = [Site]()
        sites.reserveCapacity(count)
        for i in 0..<count {
            sites.append(Site(
                id: ids[i],
                name: names[i],
                location: "",
                latitude: lats[i],
                longitude: lons[i],
                era: .unknown,
                type: SiteType(rawValue: types[i]) ?? .park,
                tier: 2,
                builtDescription: "—",
                civilisation: "—",
                tagline: descs[i],
                chapters: [],
                nearestAirport: nil,
                bestTimeToVisit: nil,
                visaNote: nil,
                imageFile: nil,
                dataSource: .openStreetMap,
                themeMask: masks[i],
                visitMinutes: durs[i],
                parentID: nil,
                significance: sigs[i]))
        }
        return sites
    }
}

extension SiteData {
    /// Decoded once, lazily. An absent or unreadable file yields an empty layer.
    static let family: [Site] = {
        guard let url = Bundle.main.url(forResource: "family", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return FamilyData.loadColumnar(from: data)
    }()
}
