import Foundation
import CoreLocation

/// A single stop in a day: somewhere to go, and how long it takes to get there.
struct PlannedStop: Identifiable {
    let site: Site
    /// Travel minutes from the previous stop (or from the trip's start, for the first).
    let travelMinutes: Int
    /// Whether that leg is a walk. Carried rather than inferred from the minutes: a
    /// 13-minute leg is a short walk or a 10 km drive depending on which side of the
    /// threshold it fell, and guessing from duration showed a walking figure next to
    /// "Salona, 13m", which is a drive out of the city.
    let isWalk: Bool

    var id: String { site.id }
}

/// One day of an itinerary.
struct PlannedDay: Identifiable {
    let index: Int
    let stops: [PlannedStop]
    /// The actual date this day falls on, so closures can be reasoned about at all.
    let date: Date

    var id: Int { index }

    var weekdayName: String {
        date.formatted(.dateTime.weekday(.wide))
    }

    /// Stops that this kind of place is *commonly* closed on, for this day of the week.
    /// Advisory — see `OpeningPattern`; the app never claims to know a site's real hours.
    func commonlyClosedStops(calendar: Calendar = .current) -> [Site] {
        stops.map(\.site).filter {
            $0.openingPattern?.isCommonlyClosed(on: date, calendar: calendar) ?? false
        }
    }
    var visitMinutes: Int { stops.reduce(0) { $0 + $1.site.visitMinutes } }
    var travelMinutes: Int { stops.reduce(0) { $0 + $1.travelMinutes } }
    var totalMinutes: Int { visitMinutes + travelMinutes }

    var summary: String {
        let hours = Double(totalMinutes) / 60
        return "\(stops.count) stops · \(String(format: "%.1f", hours))h"
    }
}

struct TripPlan {
    let days: [PlannedDay]
    let origin: CLLocationCoordinate2D
    let themes: Theme
    let startDate: Date

    var isEmpty: Bool { days.allSatisfy(\.stops.isEmpty) }
    var totalStops: Int { days.reduce(0) { $0 + $1.stops.count } }
}

/// Builds a day-by-day itinerary from the catalogue.
///
/// This is the point the whole project has been walking towards: *"I'm going to Croatia
/// for 7 days, I like castles and Roman history — where should I go?"* Everything before
/// it — the registers, the themes, the durations, the containment, the significance
/// scores — exists so this can answer.
///
/// **Travel time is estimated, not routed.** Straight-line distance × 1.25 for road
/// winding, walked below 1.5 km and driven above. Real routing (Valhalla over OSM) is the
/// known next step; the shape of the plan does not change when it arrives, only the
/// numbers.
enum TripPlanner {

    /// A day is four to seven places. Without a cap the planner filled a Bath day with
    /// **26 stops**, most of them Georgian door numbers and gate railings.
    private static let maxStopsPerDay = 7
    private static let roadFactor = 1.25
    private static let walkingSpeedKmh = 4.5
    private static let drivingSpeedKmh = 45.0
    private static let walkThresholdKm = 1.5
    private static let parkingMinutes = 5.0

    static func travelMinutes(overKm straightLine: Double) -> Int {
        let km = straightLine * roadFactor
        if km < walkThresholdKm {
            return Int((km / walkingSpeedKmh * 60).rounded())
        }
        return Int((km / drivingSpeedKmh * 60 + parkingMinutes).rounded())
    }

    /// Put a day's chosen stops into a sensible walking/driving order.
    ///
    /// Selection and sequencing are different problems and doing them in one pass gets
    /// both wrong: the greedy picker chose the Temple of Jupiter — two minutes from the
    /// start — *last*, after driving out to Klis Fortress and back, because it was ranking
    /// by value rather than by route. Nearest-neighbour from the starting point is crude
    /// but it never produces that.
    private static func ordered(_ sites: [Site],
                                from origin: CLLocationCoordinate2D) -> [PlannedStop] {
        var remaining = sites
        var here = origin
        var result: [PlannedStop] = []

        while !remaining.isEmpty {
            var nearestIndex = 0
            var nearestKm = Double.greatestFiniteMagnitude
            for (i, site) in remaining.enumerated() {
                let km = site.approxDistanceKm(from: here)
                if km < nearestKm { nearestKm = km; nearestIndex = i }
            }
            let next = remaining.remove(at: nearestIndex)
            result.append(PlannedStop(site: next,
                                      travelMinutes: travelMinutes(overKm: nearestKm),
                                      isWalk: nearestKm * roadFactor < walkThresholdKm))
            here = next.coordinate
        }
        return result
    }

    static func plan(from origin: CLLocationCoordinate2D,
                     themes: Theme,
                     days: Int,
                     startDate: Date = Date(),
                     hoursPerDay: Double = 8,
                     radiusKm: Double = 80,
                     catalogue: [Site] = SiteData.all) -> TripPlan {

        var pool = catalogue.filter { site in
            site.matches(themes: themes)
                && site.approxDistanceKm(from: origin) < radiusKm
        }

        // Anything contained by another site in the pool is something you see while
        // visiting that site, not a separate stop.
        let present = Set(pool.map(\.id))
        pool = pool.filter { site in
            guard let parent = site.parentID else { return true }
            return !present.contains(parent)
        }

        // A stop has to be worth stopping for. Without this the day fills with railings
        // and gate piers — they are real listed structures and nobody plans around them.
        pool = pool.filter { $0.visitMinutes >= 10 && $0.significance >= 25 }

        // Best-first, so the anchor of each day is the best thing still unseen.
        pool.sort { $0.detourScore(from: origin) > $1.detourScore(from: origin) }

        var used = Set<String>()
        var built: [PlannedDay] = []

        let calendar = Calendar.current

        for dayIndex in 0..<max(days, 1) {
            let dayDate = calendar.date(byAdding: .day, value: dayIndex, to: startDate) ?? startDate

            // Weekday-aware. Nothing is excluded outright — the patterns are typical, not
            // known, and refusing to show the one museum in town because it is Monday
            // would be trusting a guess further than it deserves. Instead a commonly-shut
            // place is heavily demoted, so it lands on another day when there is one, and
            // still appears (flagged) when there is not.
            func closureFactor(_ site: Site) -> Double {
                (site.openingPattern?.isCommonlyClosed(on: dayDate, calendar: calendar) ?? false)
                    ? 0.35 : 1.0
            }

            var budget = hoursPerDay * 60
            var here = origin
            var stops: [PlannedStop] = []
            var lastTheme: Theme = []

            // Anchor first. Choosing purely by value-per-minute defers the expensive
            // flagship indefinitely — it put the Historical Complex of Split, the best
            // thing in the city, on day 3 while spending day 1 on its own gates.
            guard let anchor = pool
                .filter({ !used.contains($0.id) && Double($0.visitMinutes) <= budget })
                .max(by: { a, b in
                    a.detourScore(from: origin) * closureFactor(a)
                        < b.detourScore(from: origin) * closureFactor(b)
                }) else { break }

            let anchorTravel = travelMinutes(overKm: anchor.approxDistanceKm(from: here))
            used.insert(anchor.id)
            stops.append(PlannedStop(site: anchor, travelMinutes: anchorTravel,
                                     isWalk: false))   // replaced by `ordered` below
            budget -= Double(anchorTravel + anchor.visitMinutes)
            here = anchor.coordinate
            lastTheme = anchor.themes

            let floor = max(25.0, 0.4 * Double(anchor.significance))

            while stops.count < maxStopsPerDay {
                var best: (site: Site, travel: Int, value: Double)?

                for site in pool where !used.contains(site.id) {
                    guard Double(site.significance) >= floor else { continue }
                    let travel = travelMinutes(overKm: site.approxDistanceKm(from: here))
                    let cost = Double(travel + site.visitMinutes)
                    guard cost <= budget else { continue }

                    // NOT significance/cost. A ratio rewards cheap filler: a 10-minute
                    // railing at 33 beats the Roman Baths at 86. Significance minus a
                    // travel penalty keeps the good things and still prefers the nearer
                    // of two comparable ones.
                    let variety = lastTheme.isEmpty || site.themes.intersection(lastTheme).isEmpty
                        ? 1.0 : 0.75
                    let value = Double(site.significance) * variety * closureFactor(site)
                        - 0.5 * Double(travel)

                    if best == nil || value > best!.value {
                        best = (site, travel, value)
                    }
                }

                guard let pick = best else { break }
                used.insert(pick.site.id)
                stops.append(PlannedStop(site: pick.site, travelMinutes: pick.travel,
                                         isWalk: false))
                budget -= Double(pick.travel + pick.site.visitMinutes)
                here = pick.site.coordinate
                lastTheme = pick.site.themes
            }

            built.append(PlannedDay(index: dayIndex,
                                    stops: ordered(stops.map(\.site), from: origin),
                                    date: dayDate))
        }

        return TripPlan(days: built, origin: origin, themes: themes, startDate: startDate)
    }
}
