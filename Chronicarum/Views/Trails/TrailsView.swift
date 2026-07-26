import SwiftUI
import MapKit
import CoreLocation

/// Browse the named walks and rides near you — the outdoor layer. A map of the routes that
/// pass nearby, and a nearest-first list beneath it. Tap one for its shape and length.
///
/// This is the browser, not the planner: the harder "string a stretch of the coast path
/// between two churches" composition is a later slice (see ROADMAP). Here you find a route
/// and see where it goes.
struct TrailsView: View {
    @EnvironmentObject private var mapVM: MapViewModel
    @EnvironmentObject private var focus: AppFocus
    @Environment(\.dismiss) private var dismiss

    @State private var activity: TrailActivity?
    @State private var selected: Trail?
    @State private var position: MapCameraPosition = .automatic
    @State private var trails: [Trail] = []
    @State private var loading = true

    private let gold = Color(hex: "#C9A84C")

    init(activity: TrailActivity?) {
        _activity = State(initialValue: activity)
    }

    private var origin: CLLocationCoordinate2D {
        focus.coordinate ?? mapVM.userLocation ?? mapVM.visibleRegion.center
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                map
                    .frame(height: 250)
                    .overlay(alignment: .bottomLeading) { attribution }

                filterBar

                if loading {
                    Spacer()
                    ProgressView().frame(maxWidth: .infinity)
                    Spacer()
                } else if trails.isEmpty {
                    emptyState
                } else {
                    List(trails) { trail in
                        TrailRow(trail: trail, distanceKm: trail.nearestDistanceKm(from: origin))
                            .contentShape(Rectangle())
                            .onTapGesture { selected = trail }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(focus.name.map { "Trails near \($0)" } ?? "Trails near you")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await load() }
            .onChange(of: activity) { _, _ in Task { await load() } }
            .sheet(item: $selected) { trail in
                TrailDetailView(trail: trail)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var map: some View {
        Map(position: $position) {
            ForEach(trails) { trail in
                ForEach(Array(trail.segments.enumerated()), id: \.offset) { _, seg in
                    MapPolyline(coordinates: seg)
                        .stroke(Color(hex: trail.activity.colour).opacity(0.85), lineWidth: 3)
                }
                Annotation(trail.name, coordinate: trail.coordinate) {
                    Button { selected = trail } label: {
                        Image(systemName: trail.activity.icon)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(Color(hex: trail.activity.colour), in: Circle())
                            .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                    }
                }
            }
            UserAnnotation()
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
    }

    private var filterBar: some View {
        Picker("Activity", selection: $activity) {
            Text("All").tag(TrailActivity?.none)
            Text("Walks").tag(TrailActivity?.some(.walk))
            Text("Rides").tag(TrailActivity?.some(.bike))
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }

    private var attribution: some View {
        Text(TrailData.attribution)
            .font(.system(size: 9))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.black.opacity(0.45), in: Capsule())
            .padding(8)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "map")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No national trails within 150 km")
                .font(.headline)
            Text("The outdoor layer covers Europe, North America, East Asia, and Australia so "
                 + "far. More regions to come.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    /// Find the nearby trails off the main thread — the near-you scan touches every vertex
    /// of ~10k routes, too much to run on each render.
    private func load() async {
        loading = true
        let o = origin, act = activity
        let found = await withCheckedContinuation { (cont: CheckedContinuation<[Trail], Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                cont.resume(returning: TrailData.near(o, activity: act, radiusKm: 150, limit: 40))
            }
        }
        trails = found
        loading = false
        frameOnTrails()
    }

    /// Frame the map on the trails near the origin, falling back to the origin itself.
    private func frameOnTrails() {
        let points = trails.flatMap { $0.segments.flatMap { $0 } }
        guard !points.isEmpty else {
            position = .region(MKCoordinateRegion(
                center: origin,
                span: MKCoordinateSpan(latitudeDelta: 2, longitudeDelta: 2)))
            return
        }
        var minLat = points[0].latitude, maxLat = minLat
        var minLon = points[0].longitude, maxLon = minLon
        for p in points {
            minLat = min(minLat, p.latitude); maxLat = max(maxLat, p.latitude)
            minLon = min(minLon, p.longitude); maxLon = max(maxLon, p.longitude)
        }
        // Include where the user is standing, so "near you" reads as near you.
        minLat = min(minLat, origin.latitude); maxLat = max(maxLat, origin.latitude)
        minLon = min(minLon, origin.longitude); maxLon = max(maxLon, origin.longitude)
        position = .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                           longitude: (minLon + maxLon) / 2),
            span: MKCoordinateSpan(latitudeDelta: max((maxLat - minLat) * 1.3, 0.1),
                                   longitudeDelta: max((maxLon - minLon) * 1.3, 0.1))))
    }
}

/// One trail in the near-you list.
private struct TrailRow: View {
    let trail: Trail
    let distanceKm: Double

    private var distanceLabel: String {
        distanceKm < 1 ? "\(Int(distanceKm * 1000)) m"
            : (distanceKm < 10 ? String(format: "%.1f km", distanceKm)
               : "\(Int(distanceKm.rounded()).formatted()) km")
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: trail.activity.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Color(hex: trail.activity.colour),
                            in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(trail.name)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                Text("\(trail.lengthLabel) · \(trail.networkLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 4) {
                Text(distanceLabel)
                    .font(.caption.bold())
                Text(trail.dayEstimate == 1 ? "a day" : "\(trail.dayEstimate) days")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
