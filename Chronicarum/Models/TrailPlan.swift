import Foundation
import CoreLocation

/// A day built *around* a trail rather than around a set of pins: walk a day-length stretch
/// of a named path, and stop at the heritage the route passes. The point-and-line hybrid the
/// catalogue could never express — "a day on foot that strings together the castle, the two
/// churches, and a stretch of the coast path between them".
///
/// Deliberately its own planner, not folded into `TripPlanner`: here the spine is the trail,
/// and a stop is something you *pass*, ordered by how far along you are — not a destination
/// you route between. See ROADMAP "Still to come: the planner composes rather than lists".
struct TrailStopAlong: Identifiable {
    let site: Site
    /// How far into the walked stretch this site sits, kilometres — what the stops sort on.
    let distanceAlongKm: Double
    var id: String { site.id }
}

struct TrailWalk {
    let trail: Trail
    /// The whole ordered route, faint context behind the stretch.
    let fullPath: [CLLocationCoordinate2D]
    /// The day-length stretch actually walked, start to finish.
    let path: [CLLocationCoordinate2D]
    let stretchKm: Double
    /// Heritage passed, in order along the walk.
    let stops: [TrailStopAlong]
    let walkingMinutes: Int

    var visitMinutes: Int { stops.reduce(0) { $0 + $1.site.visitMinutes } }
    var totalMinutes: Int { walkingMinutes + visitMinutes }
    var start: CLLocationCoordinate2D? { path.first }
    var end: CLLocationCoordinate2D? { path.last }

    var summary: String {
        let hours = Double(totalMinutes) / 60
        let stretch = stretchKm >= 10 ? "\(Int(stretchKm.rounded())) km"
                                      : String(format: "%.1f km", stretchKm)
        let count = stops.count == 1 ? "1 stop" : "\(stops.count) stops"
        return "\(stretch) walk · \(count) · \(String(format: "%.1f", hours))h"
    }
}

enum TrailPlanner {
    /// Sites nearer than this to the route count as "on the walk".
    private static let corridorKm = 1.2
    /// A gentle walking day, and the split between moving and stopping. Half the hours go
    /// under your feet, half to the places you stop at — a 17 km march leaves only time for a
    /// single long visit, and a day on a trail should be able to breathe at more than one.
    private static let defaultHours = 6.0
    private static let walkSpeedKmh = 4.5
    private static let walkFraction = 0.5
    private static let maxStops = 8
    /// Worth stopping for — below this the walk fills with railings and gate piers.
    private static let significanceFloor = 25

    static func plan(trail: Trail,
                     from origin: CLLocationCoordinate2D,
                     hoursPerDay: Double = defaultHours,
                     catalogue: [Site] = SiteData.all) -> TrailWalk {
        let full = orderedPath(trail.segments)

        // Start where the walker is: the point on the route nearest the origin. If the whole
        // trail is far away, that is simply its beginning.
        let startIdx = nearestIndex(on: full, to: origin)

        // The stretch is capped by time on foot, not the trail's full length — a day is a day.
        let walkTargetKm = min(trail.km, walkSpeedKmh * hoursPerDay * walkFraction)

        // Which way to walk from the start matters: the nearest point on a trail is often
        // where it clips a town, and walking *away* from the town spends the day in empty
        // country. So build the stretch in both directions, and keep whichever passes more
        // heritage — the Cotswold Way from Bath should head into Bath, not out to the hills.
        let forward = stretch(of: full, from: startIdx, targetKm: walkTargetKm, forward: true)
        let backward = stretch(of: full, from: startIdx, targetKm: walkTargetKm, forward: false)
        let options = [forward, backward].map { candidate -> (path: [CLLocationCoordinate2D], km: Double, stops: [TrailStopAlong]) in
            (candidate.path, candidate.km, sitesAlong(candidate.path, catalogue: catalogue))
        }
        let chosen = options.max { rank($0.stops) < rank($1.stops) } ?? options[0]
        let path = chosen.path
        let stretchKm = chosen.km

        let walkingMinutes = Int((stretchKm / walkSpeedKmh * 60).rounded())

        var stops = chosen.stops

        // Keep the walk inside the day: if the visits overflow the remaining hours, drop the
        // least significant until they fit — order along the path is preserved.
        let visitBudget = Int(hoursPerDay * 60) - walkingMinutes
        while stops.reduce(0, { $0 + $1.site.visitMinutes }) > visitBudget, !stops.isEmpty {
            if let drop = stops.enumerated().min(by: {
                $0.element.site.significance < $1.element.site.significance
            })?.offset {
                stops.remove(at: drop)
            } else { break }
        }

        return TrailWalk(trail: trail, fullPath: full, path: path, stretchKm: stretchKm,
                         stops: stops, walkingMinutes: walkingMinutes)
    }

    // MARK: - Ordering the route

    /// Chain the stage polylines into one ordered path. OSM stages come back in no
    /// particular order and either orientation; this greedily attaches whichever remaining
    /// stage starts nearest an open end, flipping it if its far end is the closer one.
    static func orderedPath(_ segments: [[CLLocationCoordinate2D]]) -> [CLLocationCoordinate2D] {
        let usable = segments.filter { $0.count >= 2 }
        guard var path = usable.max(by: { $0.count < $1.count }) else {
            return segments.first ?? []
        }
        // Everything except the seed we started the path from (and any exact duplicate).
        var remaining = usable.filter { !coordsEqual($0, path) }

        while let (idx, attachFront, flip) = nearestSegment(to: path, in: remaining) {
            var seg = remaining[idx]
            if flip { seg.reverse() }
            if attachFront { path = seg.dropLast() + path } else { path += seg.dropFirst() }
            remaining.remove(at: idx)
        }
        return path
    }

    private static func coordsEqual(_ a: [CLLocationCoordinate2D],
                                    _ b: [CLLocationCoordinate2D]) -> Bool {
        a.count == b.count && a.first?.latitude == b.first?.latitude
            && a.last?.latitude == b.last?.latitude
    }

    /// The remaining segment with an endpoint closest to either open end of `path`, and how
    /// to attach it. Returns nil once the nearest gap is too big to be the same route.
    private static func nearestSegment(to path: [CLLocationCoordinate2D],
                                       in remaining: [[CLLocationCoordinate2D]])
        -> (index: Int, attachFront: Bool, flip: Bool)? {
        guard let front = path.first, let back = path.last else { return nil }
        var best: (d: Double, index: Int, attachFront: Bool, flip: Bool)?
        for (i, seg) in remaining.enumerated() {
            guard let s = seg.first, let e = seg.last else { continue }
            let options: [(Double, Bool, Bool)] = [
                (Trail.haversineKm(back, s),  false, false),  // append, forward
                (Trail.haversineKm(back, e),  false, true),   // append, flipped
                (Trail.haversineKm(front, e), true,  false),  // prepend, forward
                (Trail.haversineKm(front, s), true,  true),   // prepend, flipped
            ]
            for (d, attachFront, flip) in options where best == nil || d < best!.d {
                best = (d, i, attachFront, flip)
            }
        }
        guard let b = best, b.d < 5.0 else { return nil }   // >5 km gap: not one route
        return (b.index, b.attachFront, b.flip)
    }

    // MARK: - Walking the stretch

    private static func nearestIndex(on path: [CLLocationCoordinate2D],
                                     to c: CLLocationCoordinate2D) -> Int {
        var best = Double.greatestFiniteMagnitude, idx = 0
        for (i, p) in path.enumerated() {
            let d = Trail.haversineKm(c, p)
            if d < best { best = d; idx = i }
        }
        return idx
    }

    /// Ranks a candidate stretch: more stops first, then more total significance. The empty
    /// walk always loses to any walk that passes something.
    private static func rank(_ stops: [TrailStopAlong]) -> (Int, Int) {
        (stops.count, stops.reduce(0) { $0 + $1.site.significance })
    }

    /// From a start index, cover `targetKm` weighted in one direction — forward first (then
    /// back-filling if the tail is short), or backward first. Running it both ways lets the
    /// planner keep whichever direction is worth walking.
    private static func stretch(of path: [CLLocationCoordinate2D],
                                from start: Int,
                                targetKm: Double,
                                forward: Bool) -> (path: [CLLocationCoordinate2D], km: Double) {
        guard path.count >= 2 else { return (path, 0) }
        var begin = start, end = start, km = 0.0
        func extendEnd() -> Bool {
            guard end + 1 < path.count else { return false }
            km += Trail.haversineKm(path[end], path[end + 1]); end += 1; return true
        }
        func extendBegin() -> Bool {
            guard begin > 0 else { return false }
            km += Trail.haversineKm(path[begin - 1], path[begin]); begin -= 1; return true
        }
        let (primary, secondary) = forward ? (extendEnd, extendBegin) : (extendBegin, extendEnd)
        while km < targetKm, primary() {}
        while km < targetKm, secondary() {}
        return (Array(path[begin...end]), km)
    }

    // MARK: - Sites along the walk

    private static func sitesAlong(_ path: [CLLocationCoordinate2D],
                                   catalogue: [Site]) -> [TrailStopAlong] {
        guard !path.isEmpty else { return [] }
        // Bounding box of the stretch, padded by the corridor, to cut 250k sites to a
        // handful before the exact per-point distance test.
        let pad = corridorKm / 111.0 + 0.005
        var minLat = path[0].latitude, maxLat = minLat
        var minLon = path[0].longitude, maxLon = minLon
        for p in path {
            minLat = min(minLat, p.latitude); maxLat = max(maxLat, p.latitude)
            minLon = min(minLon, p.longitude); maxLon = max(maxLon, p.longitude)
        }
        let box = catalogue.filter {
            $0.latitude >= minLat - pad && $0.latitude <= maxLat + pad
                && $0.longitude >= minLon - pad && $0.longitude <= maxLon + pad
        }

        // Cumulative distance at each path vertex, so a matched site can report how far in.
        var cumulative = [Double](repeating: 0, count: path.count)
        for i in 1..<path.count {
            cumulative[i] = cumulative[i - 1] + Trail.haversineKm(path[i - 1], path[i])
        }

        var found: [TrailStopAlong] = []
        for site in box {
            guard site.visitMinutes >= 10, site.significance >= significanceFloor,
                  !site.isSensitive else { continue }
            let c = site.coordinate
            var best = Double.greatestFiniteMagnitude, at = 0
            for (i, p) in path.enumerated() {
                let d = Trail.haversineKm(c, p)
                if d < best { best = d; at = i }
            }
            if best <= corridorKm {
                found.append(TrailStopAlong(site: site, distanceAlongKm: cumulative[at]))
            }
        }

        // A site and the area drawn around it are one stop — keep whichever is worth more,
        // the same rule the trip planner uses.
        var byID: [String: Site] = [:]
        for s in found { byID[s.site.id] = s.site }
        var suppressed = Set<String>()
        for s in found {
            guard let pid = s.site.parentID, let parent = byID[pid] else { continue }
            suppressed.insert(s.site.significance > parent.significance ? pid : s.site.id)
        }
        found = found.filter { !suppressed.contains($0.site.id) }

        found.sort { $0.distanceAlongKm < $1.distanceAlongKm }
        // If the corridor is generous, cap to the best few so a stretch past a city is a
        // walk, not a marathon of stops.
        if found.count > maxStops {
            let keep = Set(found.sorted { $0.site.significance > $1.site.significance }
                            .prefix(maxStops).map(\.id))
            found = found.filter { keep.contains($0.id) }
        }
        return found
    }
}
