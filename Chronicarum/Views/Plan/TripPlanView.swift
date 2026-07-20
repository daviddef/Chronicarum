import SwiftUI
import CoreLocation

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

    @Environment(\.dismiss) private var dismiss
    @State private var days = 3
    @State private var startDate = Date()
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
                    Text(themes.isEmpty
                         ? "No interests selected, so this uses the best of everything nearby."
                         : "Built from what's near you, ranked by what's worth the detour.")
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
                            HStack {
                                Text("Day \(day.index + 1) · \(day.weekdayName)")
                                Spacer()
                                Text(day.summary).foregroundColor(.secondary)
                            }
                        }
                    }

                    Section {
                        Text("Travel times are estimated from straight-line distance, not "
                             + "routed. Opening hours are not known for any site — no "
                             + "heritage register records them — so closures here are "
                             + "what's typical for that kind of place, not fact. Check "
                             + "before you set out.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if plan != nil {
                    Section {
                        Text("Nothing nearby matches those interests. Try more days, or "
                             + "fewer interests.")
                            .foregroundColor(.secondary)
                    }
                }
            }
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
            .task(id: days) { rebuild() }
            .task(id: startDate) { rebuild() }
            .sheet(item: $selectedSite) { SiteDetailView(site: $0) }
            .overlay {
                if isBuilding { ProgressView().controlSize(.large) }
            }
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

    private func rebuild() {
        isBuilding = true
        // 260k sites and a greedy inner loop — off the main thread so the stepper stays
        // responsive while a longer trip is built.
        let requestedDays = days
        let requestedStart = startDate
        DispatchQueue.global(qos: .userInitiated).async {
            let built = TripPlanner.plan(from: origin, themes: themes,
                                         days: requestedDays, startDate: requestedStart)
            DispatchQueue.main.async {
                plan = built
                isBuilding = false
                regeneratePDF(built)
            }
        }
    }
}

private struct PlannedStopRow: View {
    let stop: PlannedStop

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 2) {
                Image(systemName: stop.isWalk ? "figure.walk" : "car.fill")
                    .font(.system(size: 10))
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
