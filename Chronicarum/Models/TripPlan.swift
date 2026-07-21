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
    /// True once `RouteService` has replaced the straight-line guess with a real routed
    /// time. Carried so the caveats can say which of the two the reader is looking at —
    /// "estimated" printed over a measured number is as misleading as the reverse.
    var isMeasured: Bool = false
    /// Set when MapKit could find no driving route at all over a distance where there
    /// plainly should be one. In practice that means water: the site is on an island, and
    /// getting there needs a ferry the planner knows nothing about. The leg keeps its
    /// straight-line estimate, which would otherwise present a sea crossing as a drive.
    var noRoadRoute: Bool = false

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
    /// Stops with no road route to them — almost always an island. See `noRoadRoute`.
    var unreachableStops: [Site] { stops.filter(\.noRoadRoute).map(\.site) }

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

    /// How many legs carry a real routed time. Partial is the normal case, not an error:
    /// MapKit answers for most legs and not for some, and the wording adapts rather than
    /// claiming all or nothing.
    var measuredLegs: Int {
        days.reduce(0) { $0 + $1.stops.filter(\.isMeasured).count }
    }
    var isFullyRouted: Bool { totalStops > 0 && measuredLegs == totalStops }

    /// One sentence about how much to trust the travel numbers, written from what actually
    /// happened rather than from a fixed claim. Shared by the screen and the printed page
    /// so the two can never disagree.
    var travelCaveat: String {
        if isFullyRouted {
            return "Travel times are real routed times, without traffic. Add time for "
                 + "parking and for getting lost."
        }
        if measuredLegs > 0 {
            return "Most travel times are real routed times; the rest are estimated from "
                 + "straight-line distance where no route could be found."
        }
        return "Travel times are estimated from straight-line distance, not routed."
    }
}

/// Builds a day-by-day itinerary from the catalogue.
///
/// This is the point the whole project has been walking towards: *"I'm going to Croatia
/// for 7 days, I like castles and Roman history — where should I go?"* Everything before
/// it — the registers, the themes, the durations, the containment, the significance
/// scores — exists so this can answer.
///
/// **Selection runs on estimated travel; the chosen legs are then routed for real.**
/// A cheap estimate — see `travelMinutes` — is what ranks thousands of candidate legs.
/// `RouteService` then measures the forty-odd legs that survived, using MapKit. The shape
/// of the plan comes from the estimate, its printed numbers from the measurement, which is
/// why the estimate still has to be good: it decides what a day can hold.
enum TripPlanner {

    /// A day is four to seven places. Without a cap the planner filled a Bath day with
    /// **26 stops**, most of them Georgian door numbers and gate railings.
    private static let maxStopsPerDay = 7
    /// Walking: straight-line × 1.25 at 4.5 km/h, i.e. ~3.6 km/h made good. Checked
    /// against MapKit walking ETAs in five cities, which come out at 3.3–3.7 km/h made
    /// good. This part was right and is unchanged.
    private static let roadFactor = 1.25
    private static let walkingSpeedKmh = 4.5
    private static let walkThresholdKm = 1.5

    /// Driving: **fitted, not assumed.** The old model — straight-line × 1.25 at a flat
    /// 45 km/h — was measured against 48 real MapKit ETAs across Split, Bath, Rome, Sydney
    /// and Paris and was wrong by 44% RMS, almost always *optimistic*: it called the
    /// 5 km hop from Diocletian's Palace to Salona 13 minutes against a real 34.
    ///
    /// Effective speed is not constant — it climbs with distance, because a short leg is
    /// all city street and a long one is mostly open road. Fitting `v = vmax·d/(d+d₀)`
    /// gives vmax 53.5 km/h and d₀ 12 km, which rearranges to something simpler to read:
    /// **13.5 minutes of getting out of one place and into another, then 53 km/h.** RMS
    /// error 24%, near the irreducible scatter — Paris and Sydney genuinely differ.
    private static let driveOverheadMinutes = 13.5
    private static let drivingSpeedKmh = 53.5
    /// Finding somewhere to leave the car. Added on top of a routed drive too — MapKit
    /// times the road, not the ten minutes circling a walled town looking for a space.
    static let parkingMinutes = 5

    static func travelMinutes(overKm straightLine: Double) -> Int {
        if straightLine * roadFactor < walkThresholdKm {
            return Int((straightLine * roadFactor / walkingSpeedKmh * 60).rounded())
        }
        // Straight-line distance goes in directly: the fit absorbed road winding, so
        // applying `roadFactor` here as well would count it twice.
        let driving = driveOverheadMinutes + straightLine / drivingSpeedKmh * 60
        return Int(driving.rounded()) + parkingMinutes
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

        // A site and the site containing it are one visit, not two. Which of the two to
        // drop is the whole question, and the obvious answer — keep the container, it is
        // the bigger thing — is wrong often enough to matter:
        //
        //     Fulham Palace moated site (20)  contains  Fulham Palace (65)
        //     Portsmouth Dockyard docks (23)  contains  HMS Victory (56), Mary Rose (43)
        //
        // A scheduled area is frequently a designation drawn *around* something rather than
        // a destination itself, so keeping the container would spend an afternoon at a
        // dockyard wall and never board HMS Victory. Keeping whichever end is worth more
        // gets both families right: the Georgian terrace beats its 39 listed houses, and
        // the ships beat the basin they float in.
        var byID: [String: Site] = [:]
        for site in pool { byID[site.id] = site }
        var suppressed = Set<String>()
        for site in pool {
            guard let parentID = site.parentID, let parent = byID[parentID] else { continue }
            // Ties go to the container, which is the safer default: it is the reading that
            // removes more stops, and over-counting a place is the failure this exists for.
            suppressed.insert(site.significance > parent.significance ? parentID : site.id)
        }
        pool = pool.filter { !suppressed.contains($0.id) }

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
