import Foundation
import CoreLocation

/// The reverse composition. `TrailPlanner` builds a day *around* a trail; this looks at a day
/// built around heritage and notices where a walked leg between two stops happens to run
/// along a named path — so "13 min walk" can become "walk 1.4 km along the Thames Path", and
/// the leg can draw as the river really bends rather than as a straight line.
///
/// Purely additive: it only ever *sets* `trailLeg` on a leg that qualifies, and qualifies
/// almost none. A plan with nothing underfoot comes back exactly as it went in.
enum TrailComposer {
    /// Both stops must sit essentially *on* the path — tighter than the trail planner's
    /// corridor, because the claim here is "you walk along it", not "it's nearby".
    private static let corridorKm = 0.5
    /// Following the trail mustn't be a wild detour versus walking straight between the stops.
    private static let maxDetourFactor = 2.5
    /// Below this a leg is a few steps across a courtyard — not worth naming a trail for.
    private static let minLegKm = 0.4

    static func enrich(_ plan: TripPlan, trails: [Trail] = TrailData.all) -> TripPlan {
        // Nothing is walked → nothing to compose. This keeps every driving plan free of the
        // work entirely: the common case pays one array scan and returns.
        guard plan.days.contains(where: { $0.stops.contains(where: \.isWalk) }) else {
            return plan
        }
        var cache: [String: [CLLocationCoordinate2D]] = [:]   // trail id → ordered path
        let days = plan.days.map { enrichDay($0, origin: plan.origin, trails: trails, cache: &cache) }
        return TripPlan(days: days, origin: plan.origin, themes: plan.themes,
                        startDate: plan.startDate, mode: plan.mode, relaxedTier: plan.relaxedTier)
    }

    private static func enrichDay(_ day: PlannedDay, origin: CLLocationCoordinate2D,
                                  trails: [Trail],
                                  cache: inout [String: [CLLocationCoordinate2D]]) -> PlannedDay {
        guard day.stops.contains(where: \.isWalk) else { return day }

        // Candidate trails: bounding box of the day's points, padded by the corridor. The
        // box test is four comparisons per trail — cheap enough to run over all ~10k before
        // any trail's geometry is touched.
        let pts = [origin] + day.stops.map(\.site.coordinate)
        var lo = pts[0].latitude, hi = pts[0].latitude
        var lw = pts[0].longitude, he = pts[0].longitude
        for p in pts {
            lo = min(lo, p.latitude);  hi = max(hi, p.latitude)
            lw = min(lw, p.longitude); he = max(he, p.longitude)
        }
        let padDeg = corridorKm / 111.0 + 0.001
        let candidates = trails.filter {
            $0.activity == .walk
                && $0.mayReach(minLat: lo, maxLat: hi, minLon: lw, maxLon: he, padDeg: padDeg)
        }
        guard !candidates.isEmpty else { return day }

        var stops = day.stops
        for i in stops.indices where stops[i].isWalk {
            let prev = i == 0 ? origin : stops[i - 1].site.coordinate
            let cur = stops[i].site.coordinate
            stops[i].trailLeg = bestLeg(prev: prev, cur: cur,
                                        candidates: candidates, cache: &cache)
        }
        return PlannedDay(index: day.index, stops: stops,
                          date: day.date, returnMinutes: day.returnMinutes)
    }

    /// The trail giving the shortest along-path route between the two stops, if one sits on a
    /// path at all and doesn't wander to get there.
    private static func bestLeg(prev: CLLocationCoordinate2D, cur: CLLocationCoordinate2D,
                                candidates: [Trail],
                                cache: inout [String: [CLLocationCoordinate2D]]) -> TrailLeg? {
        let straight = Trail.haversineKm(prev, cur)
        guard straight >= minLegKm else { return nil }

        var best: (leg: TrailLeg, along: Double)?
        for trail in candidates {
            let path: [CLLocationCoordinate2D]
            if let cached = cache[trail.id] {
                path = cached
            } else {
                path = TrailPlanner.orderedPath(trail.segments)
                cache[trail.id] = path
            }
            guard path.count >= 2 else { continue }

            let (iPrev, dPrev) = nearest(on: path, to: prev)
            let (iCur, dCur) = nearest(on: path, to: cur)
            guard dPrev <= corridorKm, dCur <= corridorKm, iPrev != iCur else { continue }

            let a = min(iPrev, iCur), b = max(iPrev, iCur)
            let sub = Array(path[a...b])
            let along = length(of: sub)
            guard along >= minLegKm, along <= straight * maxDetourFactor + 0.5 else { continue }

            if best == nil || along < best!.along {
                best = (TrailLeg(trailName: trail.name, coordinates: sub, alongKm: along), along)
            }
        }
        return best?.leg
    }

    private static func nearest(on path: [CLLocationCoordinate2D],
                                to c: CLLocationCoordinate2D) -> (index: Int, distanceKm: Double) {
        var bestD = Double.greatestFiniteMagnitude, bestI = 0
        for (i, p) in path.enumerated() {
            let d = Trail.haversineKm(c, p)
            if d < bestD { bestD = d; bestI = i }
        }
        return (bestI, bestD)
    }

    private static func length(of path: [CLLocationCoordinate2D]) -> Double {
        guard path.count > 1 else { return 0 }
        return (1..<path.count).reduce(0.0) { $0 + Trail.haversineKm(path[$1 - 1], path[$1]) }
    }
}
