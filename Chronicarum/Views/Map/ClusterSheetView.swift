import SwiftUI
import MapKit

/// What a count bubble opens: the places grouped there, how spread out they are, and a
/// suggested order to see them in.
///
/// Large clusters are capped rather than listed in full — a bubble at world zoom can hold
/// well over a thousand sites, and a 1,400-row list is not an answer to "what's here?".
/// Those show the most significant few and offer to zoom instead.
struct ClusterSheetView: View {
    let cluster: SiteCluster
    let userLocation: CLLocationCoordinate2D?
    let onSelect: (Site) -> Void
    let onZoomToArea: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showRoute = false
    @State private var showPlanner = false

    /// Where a trip through this region starts.
    ///
    /// Your own position if you are close enough for it to be the sensible first stop,
    /// otherwise the middle of the region itself — drawing a loop around Cornwall from a
    /// desk in Sydney should plan Cornwall, not a 17,000 km first leg.
    private var planningOrigin: CLLocationCoordinate2D {
        guard let userLocation,
              cluster.sites.contains(where: { $0.approxDistanceKm(from: userLocation) < 60 })
        else { return cluster.coordinate }
        return userLocation
    }

    /// Far enough to reach everything drawn, so the planner's own radius never clips the
    /// region the user chose. The region is the boundary; this just stops a second one
    /// being imposed on top of it.
    private var planningRadiusKm: Double {
        let origin = planningOrigin
        let furthest = cluster.sites.reduce(0.0) {
            max($0, $1.approxDistanceKm(from: origin))
        }
        return furthest + 5
    }

    /// Beyond this the list stops being browsable and zooming is the better move.
    private let listCap = 40

    private var isCapped: Bool { cluster.count > listCap }

    /// Nearest-first when we know where the user is, otherwise most significant first.
    private var orderedSites: [Site] {
        let sites = cluster.sites
        guard let origin = userLocation else {
            // `tier` is 2 for every bulk site, so "most significant" used to be an
            // arbitrary 40. `significance` is what actually ranks them.
            return Array(sites.sorted { $0.significance > $1.significance }.prefix(listCap))
        }
        return Array(sites
            .sorted { $0.approxDistanceKm(from: origin) < $1.approxDistanceKm(from: origin) }
            .prefix(listCap))
    }

    private var route: (stops: [Site], totalKm: Double) {
        // Route the capped set — a walking order through 1,400 stops is meaningless.
        SiteCluster(id: cluster.id, coordinate: cluster.coordinate, sites: orderedSites)
            .route(from: userLocation)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    summary
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                }

                if showRoute {
                    Section("Suggested order") {
                        let plan = route
                        ForEach(Array(plan.stops.enumerated()), id: \.element.id) { index, site in
                            RouteStopRow(index: index + 1,
                                         site: site,
                                         legKm: legDistance(to: index, in: plan.stops))
                                .contentShape(Rectangle())
                                .onTapGesture { onSelect(site); dismiss() }
                        }
                    }
                } else {
                    Section(isCapped ? "Most significant \(listCap)" : "Places here") {
                        ForEach(orderedSites) { site in
                            SiteListRow(site: site,
                                        distanceKm: userLocation.map { site.approxDistanceKm(from: $0) })
                                .contentShape(Rectangle())
                                .onTapGesture { onSelect(site); dismiss() }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("\(cluster.count.formatted()) places")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showPlanner) {
                // The whole cluster, not the capped list: the cap exists so a 1,400-row
                // list stays readable, and has nothing to do with what a trip may draw on.
                TripPlanView(origin: planningOrigin,
                             themes: [],
                             placeName: cluster.sites.first?.location,
                             confinedTo: cluster.sites,
                             radiusKm: planningRadiusKm)
            }
        }
    }

    /// Total visiting time across the cluster, with sites contained by another site in
    /// the same cluster folded into their container — otherwise the four records covering
    /// Diocletian's Palace would be counted as four visits.
    private var visitingLabel: String {
        let minutes = cluster.sites.visitMinutesFoldingContained
        if minutes < 60 { return "\(minutes)m" }
        let hours = Double(minutes) / 60
        return hours < 10 ? String(format: "%.1fh", hours) : "\(Int(hours))h"
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 0) {
                SummaryCell(value: cluster.count.formatted(), label: "Places")
                Divider().frame(height: 30)
                SummaryCell(value: distanceLabel(cluster.spanKm), label: "Across")
                Divider().frame(height: 30)
                // Visiting time only — travel between the stops is not modelled yet, so
                // labelling this "Time here" rather than anything that sounds like a plan.
                SummaryCell(value: visitingLabel, label: "Time here")
                if let origin = userLocation {
                    Divider().frame(height: 30)
                    let nearest = cluster.sites
                        .map { $0.approxDistanceKm(from: origin) }.min() ?? 0
                    SummaryCell(value: distanceLabel(nearest), label: "Nearest")
                }
            }

            let contained = cluster.sites.containedWithin
            if !contained.isEmpty {
                Text("\(contained.count) of these "
                     + (contained.count == 1 ? "is part of" : "are parts of")
                     + " something else here, so the time above counts "
                     + (contained.count == 1 ? "it" : "them") + " once.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if isCapped {
                Text("Too many to list — showing the most significant \(listCap). "
                     + "Zoom in to see the rest.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Two different questions, and only one of them used to be answerable here.
            // "Plan a route" orders these places for a single visit; "Plan a trip" spreads
            // them over days, which is what drawing a region around a county is asking for.
            HStack(spacing: 10) {
                Button {
                    showPlanner = true
                } label: {
                    Label("Plan a trip", systemImage: "calendar.badge.plus")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "#C9A84C"))

                Button {
                    withAnimation { showRoute.toggle() }
                } label: {
                    Label(showRoute ? "List" : "Route",
                          systemImage: showRoute ? "list.bullet" : "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)

                Button {
                    onZoomToArea(); dismiss()
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Zoom to this area")
            }

            if showRoute {
                let plan = route
                Text("\(plan.stops.count) stops · \(distanceLabel(plan.totalKm)) total, "
                     + "nearest-neighbour order — a sensible walk, not the shortest possible.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func legDistance(to index: Int, in stops: [Site]) -> Double? {
        if index == 0 {
            return userLocation.map { stops[0].approxDistanceKm(from: $0) }
        }
        return stops[index].approxDistanceKm(from: stops[index - 1].coordinate)
    }

    private func distanceLabel(_ km: Double) -> String {
        km < 1 ? "\(Int(km * 1000)) m"
               : (km < 10 ? String(format: "%.1f km", km) : "\(Int(km.rounded())) km")
    }
}

private struct SummaryCell: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.bold())
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct RouteStopRow: View {
    let index: Int
    let site: Site
    let legKm: Double?

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index)")
                .font(.caption.bold())
                .foregroundColor(.white)
                .frame(width: 22, height: 22)
                .background(Color(hex: site.era.color), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(site.name).font(.subheadline.bold())
                Text(site.location).font(.caption2).foregroundColor(.secondary)
            }

            Spacer()

            if let legKm {
                Text(legKm < 1 ? "\(Int(legKm * 1000)) m" : String(format: "%.1f km", legKm))
                    .font(.caption2)
                    .foregroundColor(Color(hex: "#C9A84C"))
            }
        }
        .padding(.vertical, 2)
    }
}
