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

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var isInternational: Bool { tier == "iwn" || tier == "icn" }
    var networkLabel: String { isInternational ? "International route" : "National route" }

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
    static func near(_ c: CLLocationCoordinate2D,
                     activity: TrailActivity? = nil,
                     radiusKm: Double = 120,
                     limit: Int = 40) -> [Trail] {
        all
            .filter { activity == nil || $0.activity == activity }
            .map { (trail: $0, d: $0.nearestDistanceKm(from: c)) }
            .filter { $0.d <= radiusKm }
            .sorted { $0.d < $1.d }
            .prefix(limit)
            .map(\.trail)
    }

    private static func load() -> [Trail] {
        guard let url = Bundle.main.url(forResource: "trails", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let cols = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ids   = cols["id"]   as? [String],
              let names = cols["name"] as? [String],
              let acts  = cols["activity"] as? [String],
              let tiers = cols["tier"] as? [String],
              let kms   = cols["km"]   as? [Double],
              let lats  = cols["lat"]  as? [Double],
              let lons  = cols["lon"]  as? [Double],
              let polys = cols["poly"] as? [String]
        else { return [] }

        let count = ids.count
        guard [names.count, acts.count, tiers.count, kms.count,
               lats.count, lons.count, polys.count].allSatisfy({ $0 == count }) else {
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
            trails.append(Trail(
                id: ids[i],
                name: names[i],
                activity: TrailActivity(rawValue: acts[i]) ?? .walk,
                tier: tiers[i],
                km: kms[i],
                latitude: lats[i],
                longitude: lons[i],
                segments: segments))
        }
        return trails
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
