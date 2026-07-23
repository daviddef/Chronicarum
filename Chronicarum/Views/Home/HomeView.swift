import SwiftUI
import CoreLocation

/// The home tab — search, choose how many days, pick the kind of day, or pick up a recent
/// plan. Map, Explore and Saved are tabs; this screen is the planning front door.
struct HomeView: View {
    @Binding var selectedTab: ContentView.Tab
    @EnvironmentObject private var focus: AppFocus
    @EnvironmentObject private var mapVM: MapViewModel
    @EnvironmentObject private var siteVM: SiteViewModel
    @EnvironmentObject private var recents: RecentTripsStore

    @State private var days = 1
    @State private var request: PlanRequest?
    @State private var showSearch = false
    @State private var counts: [String: Int] = [:]

    private let ink = Color(red: 0x17 / 255, green: 0x15 / 255, blue: 0x12 / 255)
    private let gold = Color(hex: "#C9A84C")
    /// Three across, small — the tiles are a picker, not a poster.
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    private var origin: CLLocationCoordinate2D {
        focus.coordinate ?? mapVM.userLocation ?? mapVM.visibleRegion.center
    }
    private var originKey: String { "\(origin.latitude),\(origin.longitude)" }

    /// Everything the plan sheet needs, whether the tap came from a card or a recent trip.
    struct PlanRequest: Identifiable {
        let id = UUID()
        let intent: DayIntent
        let origin: CLLocationCoordinate2D
        let placeName: String?
        let days: Int
    }

    var body: some View {
        ZStack {
            ink.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    Text("CHRONICARUM")
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .tracking(4)
                        .foregroundStyle(gold)
                        .padding(.top, 8)

                    // ── Search a place ───────────────────────────────────
                    Button { showSearch = true } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                            Text(focus.name ?? "Search a place").lineLimit(1)
                            Spacer()
                            if focus.coordinate != nil {
                                Button { focus.clear() } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .foregroundStyle(focus.name == nil ? .white.opacity(0.55) : gold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.white.opacity(0.08), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    // ── How long ─────────────────────────────────────────
                    VStack(spacing: 4) {
                        HStack {
                            Text("How long?")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.75))
                            Spacer()
                            Text(days == 1 ? "Just a day" : "\(days) days")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(gold)
                        }
                        Slider(value: Binding(get: { Double(days) },
                                              set: { days = Int($0.rounded()) }),
                               in: 1...14, step: 1)
                            .tint(gold)
                    }
                    .padding(.horizontal, 4)

                    // ── The seven kinds of day ───────────────────────────
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(DayIntent.all) { option in
                            Button { open(intent: option) } label: {
                                IntentCard(intent: option, count: counts[option.id])
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // ── Recent plans ─────────────────────────────────────
                    if !recents.trips.isEmpty {
                        HStack {
                            Text("Recent")
                                .font(.system(.headline, design: .serif))
                                .foregroundStyle(.white.opacity(0.9))
                            Spacer()
                            Button("Clear") { recents.clear() }
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        .padding(.top, 8)

                        VStack(spacing: 8) {
                            ForEach(recents.trips) { trip in
                                Button { open(recent: trip) } label: {
                                    RecentRow(trip: trip)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.dark)
        .task(id: originKey) { await refreshCounts() }
        .fullScreenCover(item: $request) { req in
            TripPlanView(origin: req.origin,
                         themes: req.intent.themes,
                         placeName: req.placeName,
                         initialDays: req.days,
                         initialMode: req.intent.mode,
                         tier: req.intent.tier,
                         types: req.intent.types,
                         intentCaveat: req.intent.caveat,
                         stepTarget: req.intent.stepTarget)
        }
        .sheet(isPresented: $showSearch) {
            LocationPickerView { coordinate, name in
                focus.set(coordinate, name: name)
            }
        }
    }

    private func open(intent: DayIntent) {
        let name = focus.name ?? siteVM.nearestPlaceName(to: origin)
        recents.record(intent: intent, placeName: name, coordinate: origin, days: days)
        request = PlanRequest(intent: intent, origin: origin, placeName: name, days: days)
    }

    private func open(recent trip: RecentTrip) {
        guard let intent = trip.intent else { return }
        recents.record(intent: intent, placeName: trip.placeName,
                       coordinate: trip.coordinate, days: trip.days)
        request = PlanRequest(intent: intent, origin: trip.coordinate,
                              placeName: trip.placeName, days: trip.days)
    }

    /// One background pass over the catalogue counts places of each kind near the origin.
    private func refreshCounts() async {
        let here = origin
        let computed: [String: Int] = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var result = Dictionary(uniqueKeysWithValues: DayIntent.all.map { ($0.id, 0) })
                for site in SiteData.all {
                    if site.visitMinutes < 10 { continue }
                    let distance = site.approxDistanceKm(from: here)
                    var sensitive: Bool? = nil
                    for intent in DayIntent.all {
                        let floor = intent.tier == .local ? 12 : 25
                        if site.significance < floor { continue }
                        if distance >= intent.mode.radiusKm { continue }
                        if !intent.types.isEmpty, !intent.types.contains(site.type) { continue }
                        if !site.matches(themes: intent.themes) { continue }
                        if sensitive == nil { sensitive = site.isSensitive }
                        if sensitive! { continue }
                        result[intent.id, default: 0] += 1
                    }
                }
                continuation.resume(returning: result)
            }
        }
        guard !Task.isCancelled else { return }
        counts = computed
    }
}

/// A small tile: a kind of day, and how many places of that sort are near you.
struct IntentCard: View {
    let intent: DayIntent
    var count: Int? = nil

    private var colour: Color { Color(hex: intent.colour) }

    private var countLabel: String? {
        guard let count else { return nil }
        if count == 0 { return "—" }
        if count >= 1000 { return "\(count / 1000)k+" }
        return "\(count)"
    }

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: intent.icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.white)
                .frame(height: 28)

            Text(intent.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if let countLabel {
                Text(countLabel)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(.white.opacity(0.18), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .frame(minHeight: 104)
        .background(
            LinearGradient(colors: [colour, colour.opacity(0.72)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
        )
    }
}

/// One recent plan, as a slim row that reopens it.
private struct RecentRow: View {
    let trip: RecentTrip

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: trip.intent?.icon ?? "clock")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Color(hex: trip.intent?.colour ?? "#C9A84C"), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(trip.intent?.title ?? "A trip")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                Text([trip.placeName, trip.days == 1 ? "a day" : "\(trip.days) days"]
                        .compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }
}
