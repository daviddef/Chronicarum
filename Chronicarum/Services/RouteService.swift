import Foundation
import MapKit

/// Real road and walking times for a planned day, from MapKit's own routing.
///
/// The roadmap's answer to "travel time is a straight line × 1.25" was self-hosted
/// Valhalla over OSM — accurate, and a server, which is a category of thing this project
/// has never needed. `MKDirections` gives the same answer for the only legs that matter:
/// it is on-device, free, needs no key, and knows about ferries, one-way systems and the
/// fact that the two sides of a river are not adjacent.
///
/// **It refines, it never plans.** Selection considers thousands of candidate legs, and
/// asking MapKit for each would be both slow and instantly throttled. So the planner keeps
/// its straight-line heuristic for *choosing* stops, and this measures only the handful of
/// legs that survived — about six a day. The plan's shape is unchanged; its numbers stop
/// being guesses.
///
/// **Every failure is silent and keeps the estimate.** No route between two points, no
/// network, a throttle — all of them mean the leg keeps the number it already had. A
/// missing measurement must never be worse than never having asked.
actor RouteService {
    static let shared = RouteService()

    /// Keyed on coordinates rounded to ~11 m, which is well inside the error of the thing
    /// being measured and means re-planning the same trip costs nothing.
    private struct Leg: Hashable {
        let fromLat: Int, fromLon: Int, toLat: Int, toLon: Int
        let walking: Bool

        init(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D, walking: Bool) {
            func q(_ d: Double) -> Int { Int((d * 10_000).rounded()) }
            fromLat = q(from.latitude);  fromLon = q(from.longitude)
            toLat   = q(to.latitude);    toLon   = q(to.longitude)
            self.walking = walking
        }
    }

    private var cache: [Leg: Int] = [:]

    /// Measured minutes for one leg, or `nil` if MapKit could not answer.
    func minutes(from: CLLocationCoordinate2D,
                 to: CLLocationCoordinate2D,
                 walking: Bool) async -> Int? {
        let leg = Leg(from: from, to: to, walking: walking)
        if let hit = cache[leg] { return hit }

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        request.transportType = walking ? .walking : .automobile

        // `calculateETA` rather than `calculate`: we want a number, not a polyline, and
        // the ETA endpoint is the cheaper of the two.
        guard let response = try? await MKDirections(request: request).calculateETA()
        else { return nil }

        let minutes = Int((response.expectedTravelTime / 60).rounded())
        cache[leg] = minutes
        return minutes
    }
}

/// Replaces a plan's estimated leg times with measured ones, where MapKit can supply them.
enum TripRouteRefiner {

    /// A ceiling on how much routing one plan may ask for. Fourteen days at seven stops is
    /// 98 legs; MapKit throttles well before that and the later days of a two-week trip are
    /// the least likely to be read carefully. Days are refined in order, so what the user
    /// looks at first is what gets measured.
    private static let maxLegs = 60

    /// Below this, a missing route is more likely a quirk of where the pin sits — inside a
    /// pedestrianised old town, on a footpath — than a genuine absence of road. Above it,
    /// on a leg the planner intended to drive, it means there is no road.
    private static let noRoadRouteThresholdKm = 2.0

    static func refined(_ plan: TripPlan) async -> TripPlan {
        var budget = maxLegs
        var days: [PlannedDay] = []

        for day in plan.days {
            guard budget > 0 else { days.append(day); break }

            var here = plan.origin
            var stops: [PlannedStop] = []

            for stop in day.stops {
                var refinedStop = stop
                if budget > 0 {
                    budget -= 1
                    let measured = await RouteService.shared.minutes(from: here,
                                                                     to: stop.site.coordinate,
                                                                     walking: stop.isWalk)
                    if let measured {
                        // Parking stays on top of a drive: MapKit times the road, not
                        // finding somewhere to leave the car at the other end.
                        let parking = stop.isWalk ? 0 : TripPlanner.parkingMinutes
                        refinedStop = PlannedStop(site: stop.site,
                                                  travelMinutes: measured + parking,
                                                  isWalk: stop.isWalk,
                                                  isMeasured: true)
                    } else if !stop.isWalk,
                              stop.site.approxDistanceKm(from: here) >= noRoadRouteThresholdKm {
                        // A drive of this length with no route at all is not a routing
                        // hiccup, it is water. Split to Hvar is 42 km of open sea and
                        // MapKit says so; without this the day claims a 50-minute drive to
                        // an island.
                        refinedStop.noRoadRoute = true
                    }
                }
                stops.append(refinedStop)
                here = stop.site.coordinate
            }

            days.append(PlannedDay(index: day.index, stops: stops, date: day.date))
        }

        // Any day past the budget is carried through untouched rather than dropped.
        if days.count < plan.days.count {
            days.append(contentsOf: plan.days.dropFirst(days.count))
        }

        return TripPlan(days: days, origin: plan.origin,
                        themes: plan.themes, startDate: plan.startDate)
    }
}
