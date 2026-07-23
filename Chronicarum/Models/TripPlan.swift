import Foundation
import CoreLocation
import MapKit

/// How you are getting around, which changes what a day can contain rather than just how
/// the legs are labelled.
///
/// Every figure here is **fitted against real MapKit ETAs**, not assumed. Walking and
/// driving were measured during the routing work; transit was measured the same way across
/// Split, Bath, Rome, Sydney and Paris — 19 minutes of getting to a stop and waiting, then
/// 25.75 km/h, at 26% RMS error. It is roughly half the speed of driving at every distance,
/// which is the whole reason a car-shaped day is the wrong shape without one.
enum TravelMode: String, CaseIterable, Identifiable {
    /// Pick the sensible mode for each leg by its length: walk what is walkable, take
    /// transit across a city, drive between them. This is `.any` — "however's easiest" —
    /// and the one case that varies per leg rather than applying one answer to the day.
    case any
    case driving
    case transit
    case walking

    var id: String { rawValue }

    /// For `.any`, the mode a single leg of this length should actually use. Everything
    /// else answers with itself — a walking day walks even the long legs, on purpose.
    func legMode(overKm straightLine: Double) -> TravelMode {
        guard self == .any else {
            // A short hop is walked whatever the day's mode: nobody drives 300 metres.
            return isWalked(overKm: straightLine) ? .walking : self
        }
        if straightLine * 1.25 < 2.0 { return .walking }   // ~2.5 km on foot
        if straightLine < 20 { return .transit }           // city-scale
        return .driving                                    // between towns
    }

    var label: String {
        switch self {
        case .any:     "However's easiest"
        case .driving: "Driving"
        case .transit: "Public transport"
        case .walking: "Walking only"
        }
    }

    var icon: String {
        switch self {
        case .any:     "arrow.triangle.swap"
        case .driving: "car.fill"
        case .transit: "tram.fill"
        case .walking: "figure.walk"
        }
    }

    /// What MapKit should be asked for when the chosen legs are measured for real.
    /// `.any` never reaches here — its legs are measured per their own `legMode`.
    var directionsType: MKDirectionsTransportType {
        switch self {
        case .any, .driving: .automobile
        case .transit: .transit
        case .walking: .walking
        }
    }

    /// How far from the start it is worth considering anything at all.
    ///
    /// Not cosmetic: with the driving radius, a walking plan would happily anchor a day on
    /// something 60 km away and then spend sixteen hours getting there.
    var radiusKm: Double {
        switch self {
        case .any, .driving: 80
        case .transit: 50
        case .walking: 6
        }
    }

    /// Minutes for one leg, from straight-line kilometres. See the type comment for where
    /// each of these numbers comes from.
    func estimatedMinutes(overKm straightLine: Double) -> Int {
        // `.any` defers to whichever mode this leg would actually use, so a mixed day is
        // costed leg by leg rather than pretending it is all one thing.
        if self == .any {
            return legMode(overKm: straightLine).estimatedMinutes(overKm: straightLine)
        }
        // A leg short enough to walk is walked, whatever the mode — and is therefore
        // charged at walking speed. Missing this priced the 46-metre stroll from the Great
        // Spa Towns to the Roman Baths at 19 minutes, because it paid the full driving
        // overhead plus parking to cross a courtyard. Every short leg in every city plan
        // was inflated the same way, and the label said "19 min walk" over a driving
        // number, which is how it was caught in print.
        if isWalked(overKm: straightLine) {
            // × 1.25 for the detour a street plan forces, at 4.5 km/h — about 3.6 km/h made
            // good, against 3.3–3.7 measured.
            return Int((straightLine * 1.25 / 4.5 * 60).rounded())
        }
        switch self {
        case .walking:
            return Int((straightLine * 1.25 / 4.5 * 60).rounded())
        case .driving:
            // Short legs are all city street and long ones mostly open road, so effective
            // speed climbs with distance; this is that curve rearranged.
            return Int((13.5 + straightLine / 53.5 * 60).rounded()) + TripPlanner.parkingMinutes
        case .transit:
            return Int((19.0 + straightLine / 25.75 * 60).rounded())
        case .any:
            return 0   // handled above
        }
    }

    /// Whether a leg of this length is walked even in this mode — used for the icon, and
    /// for asking MapKit the right question. Nobody catches a bus 300 metres.
    func isWalked(overKm straightLine: Double) -> Bool {
        switch self {
        case .walking: true
        case .any: straightLine * 1.25 < 2.0
        case .driving, .transit: straightLine * 1.25 < 1.5
        }
    }
}

/// A single stop in a day: somewhere to go, and how long it takes to get there.
struct PlannedStop: Identifiable {
    let site: Site
    /// Travel minutes from the previous stop (or from the trip's start, for the first).
    let travelMinutes: Int
    /// How this leg is actually made — walk, tram or car. For a fixed-mode day it is the
    /// day's mode, except short hops which always walk; for an "however's easiest" day it
    /// varies leg by leg, which is the whole point of that mode. Carried rather than
    /// inferred from the minutes: a 13-minute leg is a short walk or a 10 km drive
    /// depending which side of the threshold it fell, and guessing from duration once put
    /// a walking figure beside "Salona, 13m", a drive out of the city.
    let legMode: TravelMode

    /// Convenience for the several places that only care whether the leg is on foot.
    var isWalk: Bool { legMode == .walking }
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
    /// Minutes to walk back to where the day began, for a there-and-back day. `nil` for an
    /// ordinary point-to-point day, which does not loop. A step-goal walk should return you
    /// home, one way or another, so the tally counts the whole round trip.
    var returnMinutes: Int? = nil

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
    /// Stops MapKit could find no route to in the chosen mode. Driving, that is almost
    /// always water; on public transport it means there is no service.
    var unreachableStops: [Site] { stops.filter(\.noRoadRoute).map(\.site) }

    var visitMinutes: Int { stops.reduce(0) { $0 + $1.site.visitMinutes } }
    var travelMinutes: Int { stops.reduce(0) { $0 + $1.travelMinutes } + (returnMinutes ?? 0) }
    var totalMinutes: Int { visitMinutes + travelMinutes }

    var summary: String {
        let hours = Double(totalMinutes) / 60
        return "\(stops.count) stops · \(String(format: "%.1f", hours))h"
    }

    /// The day laid out against the clock, with a lunch break dropped in around midday and
    /// each stop given the time you'd arrive. Numbers continue from `startingNumber` so the
    /// list matches the numbered pins on the map.
    enum ScheduleItem: Identifiable {
        case stop(number: Int, PlannedStop, arrive: Date)
        case lunch(at: Date, minutes: Int)
        var id: String {
            switch self {
            case .stop(let n, let s, _): "stop-\(n)-\(s.id)"
            case .lunch(let at, _):      "lunch-\(at.timeIntervalSinceReferenceDate)"
            }
        }
    }

    func schedule(startingNumber: Int, startHour: Int, startMinute: Int,
                  lunchMinutes: Int, calendar: Calendar = .current) -> [ScheduleItem] {
        var comps = calendar.dateComponents([.year, .month, .day], from: date)
        comps.hour = startHour
        comps.minute = startMinute
        var clock = calendar.date(from: comps) ?? date
        // Lunch lands before the first stop you'd reach after 12:30 — a reasonable middle
        // of the day, and never mid-visit.
        let lunchStart = calendar.date(bySettingHour: 12, minute: 30, second: 0, of: clock) ?? clock
        var lunchPending = lunchMinutes > 0
        var number = startingNumber
        var items: [ScheduleItem] = []
        for stop in stops {
            clock = clock.addingTimeInterval(Double(stop.travelMinutes) * 60)   // arrive
            if lunchPending, clock >= lunchStart {
                items.append(.lunch(at: clock, minutes: lunchMinutes))
                clock = clock.addingTimeInterval(Double(lunchMinutes) * 60)
                lunchPending = false
            }
            items.append(.stop(number: number, stop, arrive: clock))
            number += 1
            clock = clock.addingTimeInterval(Double(stop.site.visitMinutes) * 60)   // leave
        }
        return items
    }
}

struct TripPlan {
    let days: [PlannedDay]
    let origin: CLLocationCoordinate2D
    let themes: Theme
    let startDate: Date
    let mode: TravelMode
    /// True when the quality bar had to be lowered to find enough nearby — "nothing
    /// tier-one is within range, so here is the best there is".
    var relaxedTier: Bool = false

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
        let tail: String
        switch mode {
        case .any: tail = " Each leg uses whatever suits its length — walk, transit or "
                        + "car — so times mix parking, waiting and getting lost."
        case .driving: tail = " Add time for parking and for getting lost."
        case .transit: tail = " They assume services are running as timetabled, which on a "
                            + "Sunday or a holiday they may not be."
        case .walking: tail = " They are flat-ground times and take no account of hills."
        }
        if isFullyRouted {
            return "Travel times are real routed \(mode.label.lowercased()) times." + tail
        }
        if measuredLegs > 0 {
            return "Most travel times are real routed times; the rest are estimated from "
                 + "straight-line distance where no route could be found." + tail
        }
        return "Travel times are estimated from straight-line distance, not routed." + tail
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
    /// Finding somewhere to leave the car, on top of any driving leg. MapKit times the
    /// road, not the ten minutes circling a walled town looking for a space.
    static let parkingMinutes = 5

    /// Put a day's chosen stops into a sensible walking/driving order.
    ///
    /// Selection and sequencing are different problems and doing them in one pass gets
    /// both wrong: the greedy picker chose the Temple of Jupiter — two minutes from the
    /// start — *last*, after driving out to Klis Fortress and back, because it was ranking
    /// by value rather than by route. Nearest-neighbour from the starting point is crude
    /// but it never produces that.
    private static func ordered(_ sites: [Site],
                                from origin: CLLocationCoordinate2D,
                                mode: TravelMode) -> [PlannedStop] {
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
                                      travelMinutes: mode.estimatedMinutes(overKm: nearestKm),
                                      legMode: mode.legMode(overKm: nearestKm)))
            here = next.coordinate
        }
        return result
    }

    static func plan(from origin: CLLocationCoordinate2D,
                     themes: Theme,
                     days: Int,
                     startDate: Date = Date(),
                     hoursPerDay: Double = 8,
                     lunchMinutes: Int = 0,
                     loopBack: Bool = false,
                     mode: TravelMode = .driving,
                     tier: SignificanceTier = .worthALook,
                     types: Set<SiteType> = [],
                     radiusKm: Double? = nil,
                     catalogue: [Site] = SiteData.all) -> TripPlan {

        // The mode decides how far is worth considering unless a caller has drawn its own
        // boundary — a walking day anchored 60 km away is sixteen hours of pavement.
        let reach = radiusKm ?? mode.radiusKm
        var pool = catalogue.filter { site in
            site.matches(themes: themes)
                && site.approxDistanceKm(from: origin) < reach
                && (types.isEmpty || types.contains(site.type))
                // A day with children, or in the rain, should never offer up a massacre
                // site because it happens to be indoors and highly rated.
                && !site.isSensitive
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
        pool = pool.filter { $0.visitMinutes >= 10 }

        // The tier is a **preference, not a gate.** "The greatest hits" asks for
        // significance ≥ 70, which is 618 sites on Earth: Bath clears it, Perth and Boise
        // hold nothing at all, and the plan came back empty with "try fewer interests" —
        // advice that could not help, because interests were not the problem. So the floor
        // is relaxed one tier at a time until there is enough to build the days asked for,
        // and `relaxedTier` records that it happened so the plan can say "nothing tier-one
        // is near you; here is the best there is" rather than an unexplained downgrade.
        let requestedFloor = max(tier.minimumSignificance, tier == .local ? 12 : 25)
        let wanted = max(4, days * 3)
        var floorSignificance = requestedFloor
        for candidate in [requestedFloor, 50, 33, 25, 12] where candidate <= requestedFloor {
            floorSignificance = candidate
            if pool.filter({ $0.significance >= candidate }).count >= wanted { break }
        }
        // Derived from where the floor actually landed, not set inside the loop: the loop
        // breaks the moment it finds enough, so a flag set *after* the break check was
        // never reached on the common path — Perth relaxed 70→50 and still claimed it
        // hadn't. This cannot disagree with the floor it reports on.
        let relaxedTier = floorSignificance < requestedFloor
        pool = pool.filter { $0.significance >= floorSignificance }

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

            // Lunch is time not spent sightseeing, so it shrinks the day rather than
            // being squeezed in on top — otherwise a lunch break would silently push the
            // last stop past the hours you actually have.
            var budget = hoursPerDay * 60 - Double(lunchMinutes)
            var here = origin
            var stops: [PlannedStop] = []
            var lastTheme: Theme = []

            // Anchor first. Choosing purely by value-per-minute defers the expensive
            // flagship indefinitely — it put the Historical Complex of Split, the best
            // thing in the city, on day 3 while spending day 1 on its own gates.
            // Getting there has to fit the day too. This used to test the *visit* alone,
            // which was survivable while everything was driven and is not once it might be
            // walked: a 6 km anchor is a 20-minute drive and a 100-minute walk, and the day
            // would open by spending its entire budget on the pavement before arriving.
            guard let anchor = pool
                .filter({ site in
                    guard !used.contains(site.id) else { return false }
                    let travel = mode.estimatedMinutes(overKm: site.approxDistanceKm(from: here))
                    return Double(travel + site.visitMinutes) <= budget
                })
                .max(by: { a, b in
                    a.detourScore(from: origin) * closureFactor(a)
                        < b.detourScore(from: origin) * closureFactor(b)
                }) else { break }

            let anchorTravel = mode.estimatedMinutes(overKm: anchor.approxDistanceKm(from: here))
            used.insert(anchor.id)
            stops.append(PlannedStop(site: anchor, travelMinutes: anchorTravel,
                                     legMode: mode))   // legMode replaced by `ordered` below
            budget -= Double(anchorTravel + anchor.visitMinutes)
            here = anchor.coordinate
            lastTheme = anchor.themes

            let floor = max(25.0, 0.4 * Double(anchor.significance))

            while stops.count < maxStopsPerDay {
                var best: (site: Site, travel: Int, value: Double)?

                for site in pool where !used.contains(site.id) {
                    guard Double(site.significance) >= floor else { continue }
                    let travel = mode.estimatedMinutes(overKm: site.approxDistanceKm(from: here))
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
                                         legMode: mode))
                budget -= Double(pick.travel + pick.site.visitMinutes)
                here = pick.site.coordinate
                lastTheme = pick.site.themes
            }

            let dayStops = ordered(stops.map(\.site), from: origin, mode: mode)
            // A there-and-back day returns you to where you began. Only worth doing when
            // it is a walk — nobody wants a "drive 40 min back to the start" line — so it
            // rides on the walking modes, which is exactly when it is asked for (a step
            // goal). The return is the walk from the last stop home.
            var returnMinutes: Int? = nil
            if loopBack, let last = dayStops.last {
                let backKm = last.site.approxDistanceKm(from: origin)
                returnMinutes = TravelMode.walking.estimatedMinutes(overKm: backKm)
            }
            built.append(PlannedDay(index: dayIndex, stops: dayStops,
                                    date: dayDate, returnMinutes: returnMinutes))
        }

        return TripPlan(days: built, origin: origin, themes: themes,
                        startDate: startDate, mode: mode, relaxedTier: relaxedTier)
    }
}
