import SwiftUI
import CoreLocation

/// The home tab — search, choose how many days, and pick the kind of day.
///
/// The four navigation tiles are gone: Map, Explore and Saved are already tabs, and "plan
/// a day" was just a door to the cards this screen now shows directly. So home *is* the
/// plan screen — a search that moves the whole app, a day count, and the seven kinds of day
/// as bright tiles, each with how many places of that sort are near you.
struct HomeView: View {
    @Binding var selectedTab: ContentView.Tab
    @EnvironmentObject private var focus: AppFocus
    @EnvironmentObject private var mapVM: MapViewModel
    @EnvironmentObject private var siteVM: SiteViewModel

    @State private var days = 1
    @State private var chosen: DayIntent?
    @State private var showSearch = false
    /// Places of each kind near the current origin, keyed by intent id. Empty until the
    /// background count finishes.
    @State private var counts: [String: Int] = [:]

    private let ink = Color(red: 0x17 / 255, green: 0x15 / 255, blue: 0x12 / 255)
    private let gold = Color(hex: "#C9A84C")
    private let columns = [GridItem(.flexible(), spacing: 14),
                           GridItem(.flexible(), spacing: 14)]

    private var origin: CLLocationCoordinate2D {
        focus.coordinate ?? mapVM.userLocation ?? mapVM.visibleRegion.center
    }
    private var originKey: String { "\(origin.latitude),\(origin.longitude)" }

    var body: some View {
        ZStack {
            ink.ignoresSafeArea()
            Image(systemName: "safari")
                .font(.system(size: 260, weight: .ultraLight))
                .foregroundStyle(gold.opacity(0.05))
                .offset(y: -140)

            ScrollView {
                VStack(spacing: 18) {
                    Text("CHRONICARUM")
                        .font(.system(size: 24, weight: .bold, design: .serif))
                        .tracking(4)
                        .foregroundStyle(gold)
                        .padding(.top, 8)

                    // ── Search a place ───────────────────────────────────
                    Button {
                        showSearch = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                            Text(focus.name ?? "Search a place")
                                .lineLimit(1)
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
                        .padding(.vertical, 13)
                        .background(.white.opacity(0.08), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    // ── How many days ────────────────────────────────────
                    VStack(spacing: 6) {
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

                    Text("What kind of day?")
                        .font(.system(.headline, design: .serif))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 2)

                    // ── The seven kinds of day ───────────────────────────
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(DayIntent.all) { option in
                            Button { chosen = option } label: {
                                IntentCard(intent: option, count: counts[option.id])
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.dark)
        .task(id: originKey) { await refreshCounts() }
        .fullScreenCover(item: $chosen) { intent in
            TripPlanView(origin: origin,
                         themes: intent.themes,
                         placeName: focus.name ?? siteVM.nearestPlaceName(to: origin),
                         initialDays: days,
                         initialMode: intent.mode,
                         tier: intent.tier,
                         types: intent.types,
                         intentCaveat: intent.caveat,
                         stepTarget: intent.stepTarget)
        }
        .sheet(isPresented: $showSearch) {
            LocationPickerView { coordinate, name in
                focus.set(coordinate, name: name)
            }
        }
    }

    /// Counts, off the main thread, how many places of each kind are near the origin — one
    /// pass over the catalogue rather than seven, distance computed once per site and the
    /// costly sensitive-site check reached only after the cheap filters.
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

/// One bright card: a kind of day, and how many places of that sort are near you.
struct IntentCard: View {
    let intent: DayIntent
    var count: Int? = nil

    private var colour: Color { Color(hex: intent.colour) }

    private var countLabel: String? {
        guard let count else { return nil }
        if count == 0 { return "none nearby" }
        if count >= 1000 { return "\(count / 1000)k+ places near you" }
        return "\(count) places near you"
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: intent.icon)
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(.white)
                .frame(height: 40)

            Text(intent.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(intent.blurb)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if let countLabel {
                Text(countLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.18), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .frame(minHeight: 160)
        .background(
            LinearGradient(colors: [colour, colour.opacity(0.72)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: colour.opacity(0.35), radius: 10, y: 5)
    }
}
