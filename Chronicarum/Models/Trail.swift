import Foundation
import CoreLocation

/// A route you travel along for its own sake — a coast path, a canal towpath, a long cycle
/// way. The outdoor layer the catalogue could not express: every `Site` is a *point* you
/// stand in front of, a `Trail` is a *line*.
///
/// Sourced from OpenStreetMap route relations (ODbL) — national and international named
/// routes only, so the list stays the good stuff rather than every local footpath. The data
/// ships in its own bundled file (`trails.json`), a collective database kept separate from
/// the heritage catalogue to honour ODbL's offer-on-request. Attribution is shown wherever a
/// trail is: see `TrailData.attribution`.
enum TrailActivity: String, Codable, CaseIterable {
    case walk, bike

    var title: String { self == .walk ? "Walk" : "Ride" }
    /// The card verb, plural — "Out for a walk", "On two wheels".
    var icon: String { self == .walk ? "figure.walk" : "bicycle" }
    var colour: String { self == .walk ? "#2E9E5B" : "#4E7BC4" }
}

struct Trail: Identifiable {
    let id: String
    let name: String
    let activity: TrailActivity
    /// OSM network tier: iwn/nwn (walk) or icn/ncn (bike).
    let tier: String
    /// Total length along the path, kilometres.
    let km: Double
    /// A representative point — the midpoint of the longest stretch — for the map pin and
    /// the near-me sort's cheap first cut.
    let latitude: Double
    let longitude: Double
    /// One polyline per stage. Kept as separate segments so an out-of-order section never
    /// draws a line jumping across the map to the next.
    let segments: [[CLLocationCoordinate2D]]
    /// Bounding box of the whole route, computed once at load. Lets a caller reject a trail
    /// that cannot be near a point with four comparisons, before any per-vertex scan.
    let minLat: Double, maxLat: Double, minLon: Double, maxLon: Double

    /// Metres of climb, where OSM records it (0 = not recorded — shown as absent, not zero).
    let ascentM: Int
    /// The route's official page, where OSM has one.
    let website: URL?
    /// A there-and-back / circular route rather than point-to-point, where tagged.
    let isLoop: Bool

    var ascentLabel: String? { ascentM > 0 ? "\(ascentM.formatted()) m of climb" : nil }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// True if any part of the route could lie within `padDeg` of the box — a cheap gate.
    func mayReach(minLat lo: Double, maxLat hi: Double,
                  minLon lw: Double, maxLon he: Double, padDeg: Double) -> Bool {
        maxLat >= lo - padDeg && minLat <= hi + padDeg
            && maxLon >= lw - padDeg && minLon <= he + padDeg
    }

    var isInternational: Bool { tier == "iwn" || tier == "icn" }
    var networkLabel: String {
        switch tier {
        case "iwn", "icn": "International route"
        case "nwn", "ncn": "National route"
        case "rwn", "rcn": "Regional route"
        default:           "Local route"
        }
    }

    var lengthLabel: String {
        km >= 10 ? "\(Int(km.rounded()).formatted()) km" : String(format: "%.1f km", km)
    }

    /// A rough sense of scale: how many days on foot/wheel this is, at an easy pace. Walking
    /// ~18 km a day, cycling ~55 km — deliberately gentle, holiday numbers not athlete ones.
    var dayEstimate: Int {
        let perDay = activity == .walk ? 18.0 : 55.0
        return max(1, Int((km / perDay).rounded()))
    }

    /// Nearest approach of the whole path to a point, scanning every stored vertex. A
    /// long-distance path passes near many places its midpoint is nowhere near, so the pin
    /// distance alone would bury it — this is what the near-me list actually sorts on.
    func nearestDistanceKm(from c: CLLocationCoordinate2D) -> Double {
        var best = Double.greatestFiniteMagnitude
        for segment in segments {
            for p in segment {
                let d = Trail.haversineKm(c, p)
                if d < best { best = d }
            }
        }
        return best
    }

    /// The point on the path closest to `c` — where a long route actually meets your area.
    /// The stored `coordinate` is the geometric midpoint, which for a 761 km national route is
    /// somewhere in the middle of the country; pinning there scatters the map. This pins the
    /// route where it passes you.
    func nearestPoint(from c: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        var best = coordinate
        var bestD = Double.greatestFiniteMagnitude
        for segment in segments {
            for p in segment {
                let d = Trail.haversineKm(c, p)
                if d < bestD { bestD = d; best = p }
            }
        }
        return best
    }

    /// Only the stretch of the path near `c` — each segment reduced to the runs of consecutive
    /// vertices within `windowKm`, split where it leaves and re-enters. A through-route that
    /// merely grazes the area then draws as the few kilometres actually here, not as a line
    /// across three countries — which also lets the map frame itself on your surroundings
    /// instead of zooming out to hold the whole route.
    func localSegments(around c: CLLocationCoordinate2D, windowKm: Double) -> [[CLLocationCoordinate2D]] {
        var runs: [[CLLocationCoordinate2D]] = []
        for segment in segments {
            var run: [CLLocationCoordinate2D] = []
            for p in segment {
                if Trail.haversineKm(c, p) <= windowKm {
                    run.append(p)
                } else if !run.isEmpty {
                    runs.append(run)
                    run = []
                }
            }
            if !run.isEmpty { runs.append(run) }
        }
        return runs
    }

    static func haversineKm(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let r = 6371.0
        let lat1 = a.latitude * .pi / 180, lat2 = b.latitude * .pi / 180
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2)
              + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * r * asin(min(1, sqrt(h)))
    }
}

/// Loads and queries the bundled trail layer.
enum TrailData {
    /// Shown on every surface a trail appears on, to satisfy ODbL attribution.
    static let attribution = "Trail data © OpenStreetMap contributors, ODbL"

    /// Decoded once, lazily. An absent or unreadable file yields an empty layer — the rest
    /// of the app is unaffected.
    static let all: [Trail] = load()

    /// Trails whose path passes within `radiusKm` of a point, nearest first. Trails are big,
    /// so the default radius is generous.
    ///
    /// Deduplicated by name: a long international route with gaps in OSM (EuroVelo 13, the E1)
    /// is imported as several geographic fragments, and a near-you list that showed the same
    /// name three times would read as a bug. The nearest fragment of each route wins.
    static func near(_ c: CLLocationCoordinate2D,
                     activity: TrailActivity? = nil,
                     radiusKm: Double = 120,
                     limit: Int = 40,
                     including extra: [Trail] = []) -> [Trail] {
        var seen = Set<String>()
        return (all + extra)
            .filter { activity == nil || $0.activity == activity }
            .map { (trail: $0, d: $0.nearestDistanceKm(from: c)) }
            .filter { $0.d <= radiusKm }
            .sorted { $0.d < $1.d }
            .compactMap { seen.insert($0.trail.name).inserted ? $0.trail : nil }
            .prefix(limit)
            .map { $0 }
    }

    private static func load() -> [Trail] {
        guard let url = Bundle.main.url(forResource: "trails", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let cols = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [] }
        return decode(cols)
    }

    /// Decode the columnar trail form (bundled `trails.json`, or an on-demand fetch that
    /// builds the same columns) into `Trail`s. Shared so the live layer produces trails
    /// identical in shape to the bundled ones.
    static func decode(_ cols: [String: Any]) -> [Trail] {
        guard let ids   = cols["id"]   as? [String],
              let names = cols["name"] as? [String],
              let acts  = cols["activity"] as? [String],
              let tiers = cols["tier"] as? [String],
              let kms   = cols["km"]   as? [Double],
              let lats  = cols["lat"]  as? [Double],
              let lons  = cols["lon"]  as? [Double],
              let polys = cols["poly"] as? [String]
        else { return [] }

        // Metadata columns are newer; tolerate their absence so an older bundle still loads.
        let ascents = cols["ascent"] as? [Int] ?? Array(repeating: 0, count: ids.count)
        let urls    = cols["url"]    as? [String] ?? Array(repeating: "", count: ids.count)
        let loops   = cols["loop"]   as? [Int] ?? Array(repeating: 0, count: ids.count)

        let count = ids.count
        guard [names.count, acts.count, tiers.count, kms.count,
               lats.count, lons.count, polys.count,
               ascents.count, urls.count, loops.count].allSatisfy({ $0 == count }) else {
            assertionFailure("trails.json has ragged columns — rebuild it")
            return []
        }

        var trails = [Trail]()
        trails.reserveCapacity(count)
        for i in 0..<count {
            let segments = polys[i]
                .split(separator: ";", omittingEmptySubsequences: true)
                .map { decodePolyline(String($0)) }
                .filter { !$0.isEmpty }
            var loLat = lats[i], hiLat = lats[i], loLon = lons[i], hiLon = lons[i]
            for seg in segments {
                for p in seg {
                    loLat = min(loLat, p.latitude); hiLat = max(hiLat, p.latitude)
                    loLon = min(loLon, p.longitude); hiLon = max(hiLon, p.longitude)
                }
            }
            trails.append(Trail(
                id: ids[i],
                name: names[i],
                activity: TrailActivity(rawValue: acts[i]) ?? .walk,
                tier: tiers[i],
                km: kms[i],
                latitude: lats[i],
                longitude: lons[i],
                segments: segments,
                minLat: loLat, maxLat: hiLat, minLon: loLon, maxLon: hiLon,
                ascentM: ascents[i],
                website: officialWebsite(urls[i]),
                isLoop: loops[i] == 1))
        }
        return trails
    }

    /// An OSM `website` tag is only shown as the route's *official page* if it actually is
    /// one — a link to the OpenStreetMap wiki or a Wikipedia article is reference material,
    /// not the operator's site, and mislabelling it "official" would be worse than absent.
    private static func officialWebsite(_ raw: String) -> URL? {
        guard !raw.isEmpty, let url = URL(string: raw),
              let host = url.host?.lowercased() else { return nil }
        let meta = ["openstreetmap.org", "wikipedia.org", "wikimedia.org", "wikidata.org"]
        return meta.contains(where: host.contains) ? nil : url
    }

    /// Encode a polyline (precision 5) — the inverse of `decodePolyline`, used to cache
    /// on-demand trails in the same compact columnar shape the bundle ships.
    static func encodePolyline(_ points: [CLLocationCoordinate2D]) -> String {
        var result = "", prevLat = 0, prevLon = 0
        func emit(_ delta0: Int) {
            var value = delta0 << 1
            if value < 0 { value = ~value }
            while value >= 0x20 {
                result.unicodeScalars.append(UnicodeScalar(UInt8((0x20 | (value & 0x1f)) + 63)))
                value >>= 5
            }
            result.unicodeScalars.append(UnicodeScalar(UInt8(value + 63)))
        }
        for p in points {
            let iLat = Int((p.latitude * 1e5).rounded()), iLon = Int((p.longitude * 1e5).rounded())
            emit(iLat - prevLat); emit(iLon - prevLon)
            prevLat = iLat; prevLon = iLon
        }
        return result
    }

    /// Decode a Google-algorithm encoded polyline (precision 5) — the compact form the
    /// import writes.
    static func decodePolyline(_ str: String) -> [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D]()
        let scalars = Array(str.unicodeScalars)
        var index = 0
        var lat = 0, lon = 0
        while index < scalars.count {
            for isLat in [true, false] {
                var shift = 0, result = 0, byte = 0x20
                while byte >= 0x20, index < scalars.count {
                    byte = Int(scalars[index].value) - 63
                    index += 1
                    result |= (byte & 0x1f) << shift
                    shift += 5
                }
                let delta = (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
                if isLat { lat += delta } else { lon += delta }
            }
            coords.append(CLLocationCoordinate2D(latitude: Double(lat) / 1e5,
                                                 longitude: Double(lon) / 1e5))
        }
        return coords
    }
}
