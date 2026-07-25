import SwiftUI
import MapKit
import CoreLocation

/// A single trail: its shape on the map, how long it is, and a way to get to the start.
struct TrailDetailView: View {
    let trail: Trail

    @Environment(\.dismiss) private var dismiss
    @State private var position: MapCameraPosition = .automatic

    private let gold = Color(hex: "#C9A84C")
    private var colour: Color { Color(hex: trail.activity.colour) }

    /// The first vertex of the first stage — a fair "start of the walk" to route to.
    private var start: CLLocationCoordinate2D? { trail.segments.first?.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    map
                        .frame(height: 240)
                        .overlay(alignment: .bottomLeading) { attribution }

                    VStack(alignment: .leading, spacing: 16) {
                        header
                        stats
                        Text("\(trail.networkLabel) · \(trail.activity.title). Sourced from "
                             + "OpenStreetMap; check the route on the ground before setting out.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let start {
                            Button {
                                openInMaps(to: start)
                            } label: {
                                Label("Get directions to the start", systemImage: "car.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(gold, in: RoundedRectangle(cornerRadius: 12))
                                    .foregroundStyle(Color(red: 0.09, green: 0.08, blue: 0.07))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
            }
            .ignoresSafeArea(edges: .top)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark.circle.fill") }
                        .foregroundStyle(.secondary)
                }
            }
            .onAppear { frameRoute() }
        }
    }

    private var map: some View {
        Map(position: $position) {
            ForEach(Array(trail.segments.enumerated()), id: \.offset) { _, seg in
                MapPolyline(coordinates: seg)
                    .stroke(colour, lineWidth: 4)
            }
            if let start {
                Annotation("Start", coordinate: start) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(colour, in: Circle())
                        .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: trail.activity.icon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(colour, in: RoundedRectangle(cornerRadius: 12))
            Text(trail.name)
                .font(.system(.title2, design: .serif).weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var stats: some View {
        HStack(spacing: 0) {
            stat(trail.lengthLabel, "length")
            Divider().frame(height: 34)
            stat(trail.dayEstimate == 1 ? "1 day" : "\(trail.dayEstimate) days", "at an easy pace")
            Divider().frame(height: 34)
            stat(trail.activity.title, trail.isInternational ? "international" : "national")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
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

    private func openInMaps(to c: CLLocationCoordinate2D) {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: c))
        item.name = "\(trail.name) — start"
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    /// Fit the camera to the whole route.
    private func frameRoute() {
        let points = trail.segments.flatMap { $0 }
        guard let first = points.first else { return }
        var minLat = first.latitude, maxLat = minLat
        var minLon = first.longitude, maxLon = minLon
        for p in points {
            minLat = min(minLat, p.latitude); maxLat = max(maxLat, p.latitude)
            minLon = min(minLon, p.longitude); maxLon = max(maxLon, p.longitude)
        }
        position = .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                           longitude: (minLon + maxLon) / 2),
            span: MKCoordinateSpan(latitudeDelta: max((maxLat - minLat) * 1.25, 0.05),
                                   longitudeDelta: max((maxLon - minLon) * 1.25, 0.05))))
    }
}
