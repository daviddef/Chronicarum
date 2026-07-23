import SwiftUI
import CoreLocation
import MapKit

/// The itinerary screen: pick how long you have, get a day-by-day plan.
///
/// Deliberately shows its working — travel time between stops, visiting time at each,
/// and the day's total — because a plan you cannot sanity-check is a plan you cannot
/// trust. The estimates are labelled as estimates for the same reason.
struct TripPlanView: View {
    let origin: CLLocationCoordinate2D
    let themes: Theme
    /// Where the trip starts, in words — used to title the PDF. Best effort: the location
    /// line of the nearest notable site, which is a place name far more often than not.
    var placeName: String? = nil
    /// Restrict the plan to a specific set of places rather than the whole catalogue.
    ///
    /// This is what a region drawn on the map produces: "three days around *these*", not
    /// "three days around here". `nil` means the usual behaviour — everything within
    /// `radiusKm` of the origin.
    var confinedTo: [Site]? = nil
    /// How far from the origin to consider. Widened when confined to a drawn region, since
    /// the region is already the boundary and the default 80 km would clip it.
    var radiusKm: Double = 80
    /// Pre-answers from the "what kind of day?" screen, so the plan opens already shaped
    /// rather than making someone set it up twice.
    var initialDays: Int = 3
    var initialMode: TravelMode = .driving
    var tier: SignificanceTier = .worthALook
    var types: Set<SiteType> = []
    /// Carried from the intent when its recipe is a proxy rather than a recorded fact.
    var intentCaveat: String? = nil
    /// Set when the walking itself is the point, so the plan can report progress toward it.
    var stepTarget: Int? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var days = 3
    @State private var startDate = Date()
    @State private var mode: TravelMode = .driving
    /// Applies the caller's choices once, without freezing them — the pickers still work.
    @State private var hasAdoptedDefaults = false
    @State private var plan: TripPlan?
    @State private var isBuilding = false
    @State private var selectedSite: Site?
    @State private var pdfURL: URL?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Stepper("\(days) \(days == 1 ? "day" : "days")", value: $days, in: 1...14)
                    DatePicker("Starting", selection: $startDate, displayedComponents: .date)
                    Picker("Getting around", selection: $mode) {
                        ForEach(TravelMode.allCases) { option in
                            Label(option.label, systemImage: option.icon).tag(option)
                        }
                    }
                    if !themes.isEmpty {
                        HStack {
                            Text("Interests").foregroundColor(.secondary)
                            Spacer()
                            Text(themes.components.map(\.label).formatted(.list(type: .and)))
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(.secondary)
                        }
                        .font(.footnote)
                    }
                } header: {
                    Text("Your trip")
                } footer: {
                    if let confinedTo {
                        Text("Only the \(confinedTo.count) places inside the region you drew"
                             + (themes.isEmpty ? "." : ", matching your interests.")
                             + modeFooter)
                    } else {
                        Text((themes.isEmpty
                              ? "No interests selected, so this uses the best of everything nearby."
                              : "Built from what's near you, ranked by what's worth the detour.")
                             + modeFooter)
                    }
                }

                if let plan, !plan.isEmpty {
                    ForEach(plan.days) { day in
                        Section {
                            ForEach(day.stops) { stop in
                                Button { selectedSite = stop.site } label: {
                                    PlannedStopRow(stop: stop)
                                }
                                .buttonStyle(.plain)
                            }
                            // Ahead of the closure note: somewhere you cannot get to at all
                            // is a bigger problem with the day than somewhere that might be
                            // shut. What "cannot get to" means depends on the mode — water
                            // if you are driving, no service if you are not.
                            let unreachable = day.unreachableStops
                            if !unreachable.isEmpty {
                                Label(unreachableNote(unreachable, mode: plan.mode),
                                      systemImage: plan.mode == .driving ? "ferry" : "exclamationmark.triangle")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }

                            let closed = day.commonlyClosedStops()
                            if !closed.isEmpty {
                                // Advisory, never a claim. See `OpeningPattern`: there is
                                // no source for real hours, so the app says what is
                                // typical and tells you to check.
                                Label(closed.count == 1
                                      ? "\(closed[0].name) may be closed on a \(day.weekdayName) — worth checking."
                                      : "\(closed.count) of these are commonly closed on a \(day.weekdayName) — worth checking.",
                                      systemImage: "exclamationmark.triangle")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        } header: {
                            HStack(alignment: .firstTextBaseline) {
                                Text("Day \(day.index + 1)")
                                    .font(.system(.headline, design: .serif))
                                    .foregroundColor(Color(hex: "#C9A84C"))
                                Text("· \(day.weekdayName)")
                                    .font(.system(.subheadline, design: .serif))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(day.summary)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .textCase(nil)
                        }
                    }

                    Section {
                        TripMapView(plan: plan)
                            .frame(height: 220)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    } header: {
                        Text("On the map").textCase(nil)
                            .foregroundColor(.secondary)
                    }

                    if let stepTarget {
                        Section {
                            let km = plan.days.first.map(walkedKm) ?? 0
                            let steps = Int(km * DayIntent.stepsPerKm)
                            Label("Day 1 walks about \(Int(km)) km — roughly "
                                  + "\(steps.formatted()) steps of your "
                                  + "\(stepTarget.formatted()).",
                                  systemImage: "figure.walk.motion")
                                .font(.caption)
                                .foregroundColor(steps >= stepTarget ? Color(hex: "#C9A84C") : .secondary)
                        }
                    }

                    if let intentCaveat {
                        Section {
                            Text(intentCaveat)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if plan.relaxedTier {
                        Section {
                            Label("Nothing top-tier is within range of here, so this is the "
                                  + "best there is nearby rather than the greatest hits.",
                                  systemImage: "sparkle.magnifyingglass")
                                .font(.caption)
                                .foregroundColor(Color(hex: "#C9A84C"))
                        }
                    }

                    Section {
                        Text(plan.travelCaveat
                             + " Opening hours are not known for any site — no heritage "
                             + "register records them — so closures here are what's "
                             + "typical for that kind of place, not fact. Check before "
                             + "you set out.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if plan != nil {
                    Section {
                        // With the tier now relaxing to fill the days, a genuinely empty
                        // plan means there is nothing designated near here at all — deep
                        // ocean, remote desert. Interests and days are no longer plausible
                        // causes, so the message no longer suggests them.
                        Text(confinedTo == nil
                             ? "There's nothing on the heritage registers close enough to "
                               + "build a day around here. You'd need to start somewhere "
                               + "with more nearby."
                             : "Nothing in the region you drew is worth a planned stop — the "
                               + "places there are too minor, or don't match your interests. "
                               + "Try drawing wider.")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(red: 0x17 / 255, green: 0x15 / 255, blue: 0x12 / 255).ignoresSafeArea())
            .tint(Color(hex: "#C9A84C"))
            .preferredColorScheme(.dark)
            .navigationTitle("Plan a trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    if let plan, !plan.isEmpty {
                        // ShareLink rather than a bespoke export screen: the system sheet
                        // already offers print, Files, Mail and everything else, and
                        // sending on someone's behalf should be their gesture, not ours.
                        ShareLink(item: pdfURL ?? URL(fileURLWithPath: "/dev/null"),
                                  preview: SharePreview("Itinerary")) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .disabled(pdfURL == nil)
                        .onAppear { regeneratePDF(plan) }
                        .onChange(of: plan.days.count) { _, _ in regeneratePDF(plan) }
                    }
                }
            }
            // One task over both inputs, not two. Separate `.task(id:)` modifiers each
            // fired on their own input and built the same plan twice.
            .task {
                guard !hasAdoptedDefaults else { return }
                hasAdoptedDefaults = true
                days = initialDays
                mode = initialMode
            }
            .task(id: "\(days)|\(startDate.timeIntervalSinceReferenceDate)|\(mode.rawValue)") {
                await rebuild()
            }
            .sheet(item: $selectedSite) { SiteDetailView(site: $0) }
            .overlay {
                if isBuilding { ProgressView().controlSize(.large) }
            }
        }
    }

    /// Straight-line kilometres walked across a day's legs — only the walked ones count.
    private func walkedKm(_ day: PlannedDay) -> Double {
        // The estimator is invertible: walking minutes are straight-line × 1.25 ÷ 4.5.
        Double(day.stops.filter(\.isWalk).reduce(0) { $0 + $1.travelMinutes }) / 60 * 4.5 / 1.25
    }

    /// Says what could not be reached, in the terms of the mode that failed to reach it.
    private func unreachableNote(_ sites: [Site], mode: TravelMode) -> String {
        let names = sites.count == 1 ? sites[0].name : "\(sites.count) of these"
        switch mode {
        case .any, .driving:
            return sites.count == 1
                ? "There's no road route to \(names) — it's likely an island, so you'd need a "
                  + "boat. The time shown doesn't include the crossing."
                : "\(names) have no road route — likely an island, so you'd need a boat. The "
                  + "times shown don't include the crossing."
        case .transit:
            return sites.count == 1
                ? "Apple Maps knows no public transport to \(names). The time shown is a "
                  + "straight-line guess, so treat it as a taxi or a lift."
                : "Apple Maps knows no public transport to \(names). Those times are "
                  + "straight-line guesses, so treat them as taxis or lifts."
        case .walking:
            return sites.count == 1
                ? "There's no walking route to \(names) — likely water or a motorway in the way."
                : "\(names) have no walking route — likely water or a motorway in the way."
        }
    }

    /// What choosing a mode actually changed, in a line — the reach is the part people
    /// would otherwise read as the app having simply found less.
    private var modeFooter: String {
        switch mode {
        case .any, .driving: return ""
        case .transit: return " On public transport, so nothing further than "
                            + "\(Int(TravelMode.transit.radiusKm)) km out."
        case .walking: return " On foot, so only what's within "
                            + "\(Int(TravelMode.walking.radiusKm)) km — a day you could "
                            + "actually walk."
        }
    }

    /// The PDF is rendered up front rather than on tap, so `ShareLink` has a real file to
    /// offer — it captures its item when the sheet is built, not when it is opened.
    private func regeneratePDF(_ plan: TripPlan) {
        DispatchQueue.global(qos: .utility).async {
            let url = ItineraryPDF.writeTemporaryFile(plan, placeName: placeName)
            DispatchQueue.main.async { pdfURL = url }
        }
    }

    /// Two passes, and the first one is what the user sees.
    ///
    /// The estimated plan is shown as soon as it exists; routing then measures the chosen
    /// legs and the numbers settle a moment later. Waiting for MapKit before showing
    /// anything would trade a complete plan now for a slightly better one after several
    /// seconds of blank screen, which is the wrong way round — and routing can fail
    /// entirely, in which case there would be nothing to fall back to.
    private func rebuild() async {
        isBuilding = true
        // 260k sites and a greedy inner loop — off the main thread so the stepper stays
        // responsive while a longer trip is built.
        let requestedDays = days
        let requestedStart = startDate
        let catalogue = confinedTo ?? SiteData.all
        let requestedMode = mode
        let requestedTier = tier
        let requestedTypes = types
        // A drawn region is its own boundary; otherwise the mode decides how far is
        // reachable, which is the difference between a walkable day and a fantasy.
        let requestedRadius: Double? = confinedTo == nil ? nil : radiusKm
        let built: TripPlan = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning:
                    TripPlanner.plan(from: origin, themes: themes,
                                     days: requestedDays, startDate: requestedStart,
                                     mode: requestedMode,
                                     tier: requestedTier,
                                     types: requestedTypes,
                                     radiusKm: requestedRadius,
                                     catalogue: catalogue))
            }
        }
        guard !Task.isCancelled else { return }
        plan = built
        isBuilding = false
        regeneratePDF(built)

        guard !built.isEmpty else { return }
        let routed = await TripRouteRefiner.refined(built)
        // The stepper may have moved while MapKit was answering; that run's plan is stale.
        guard !Task.isCancelled else { return }
        plan = routed
        regeneratePDF(routed)
    }
}

private struct PlannedStopRow: View {
    let stop: PlannedStop

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 2) {
                // The mode this leg actually uses — the same icon whatever the day's
                // setting, so an "however's easiest" day reads as walk / tram / car down
                // the column and you can see the shape of it at a glance.
                Image(systemName: stop.legMode.icon)
                    .font(.system(size: 11))
                Text("\(stop.travelMinutes)m")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(.secondary)
            .frame(width: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(stop.site.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                HStack(spacing: 6) {
                    if let duration = stop.site.visitDurationLabel {
                        Text(duration)
                    }
                    if let theme = stop.site.themes.components.first {
                        Text("· \(theme.label)")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }
}

/// A small map of the whole trip: every stop as a numbered gold pin, each day's stops
/// joined in visiting order.
///
/// Deliberately a summary, not a route line — the joins are drawn per day, so a multi-day
/// trip does not draw a stray line from the last stop of Tuesday back across the county to
/// the first of Wednesday. It frames itself to fit whatever the plan covers, whether that
/// is four streets or four counties.
private struct TripMapView: View {
    let plan: TripPlan

    private var days: [[Site]] {
        plan.days.map { $0.stops.map(\.site) }.filter { !$0.isEmpty }
    }
    private var allSites: [Site] { days.flatMap { $0 } }

    /// A region that holds every stop with a little air around it. A single stop gets a
    /// sensible default span rather than an infinite zoom.
    private var region: MKCoordinateRegion {
        let coords = allSites.map(\.coordinate)
        guard let first = coords.first else {
            return MKCoordinateRegion(center: plan.origin,
                                      span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))
        }
        var minLat = first.latitude, maxLat = first.latitude
        var minLon = first.longitude, maxLon = first.longitude
        for c in coords {
            minLat = min(minLat, c.latitude);  maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude); maxLon = max(maxLon, c.longitude)
        }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                            longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.01),
            longitudeDelta: max((maxLon - minLon) * 1.4, 0.01))
        return MKCoordinateRegion(center: center, span: span)
    }

    var body: some View {
        let gold = Color(hex: "#C9A84C")
        return Map(initialPosition: .region(region)) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, dayStops in
                MapPolyline(coordinates: dayStops.map(\.coordinate))
                    .stroke(gold.opacity(0.8), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }
            // Numbered continuously across the trip, so the pins read in the order you'd
            // do them. `enumerated` keeps the index stable rather than mutating a captured
            // counter, which a ViewBuilder re-evaluates unpredictably.
            ForEach(Array(allSites.enumerated()), id: \.element.id) { index, site in
                Annotation("", coordinate: site.coordinate) {
                    Text("\(index + 1)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(red: 0x17 / 255, green: 0x15 / 255, blue: 0x12 / 255))
                        .frame(width: 22, height: 22)
                        .background(gold, in: Circle())
                        .overlay(Circle().strokeBorder(.white.opacity(0.85), lineWidth: 1))
                        .shadow(radius: 1.5)
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted))
    }
}
