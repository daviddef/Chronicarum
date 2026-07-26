import SwiftUI
import MapKit
import CoreLocation

/// A day's walk along a trail: the stretch you'd cover drawn bold over the whole route, the
/// heritage you'd pass numbered along it, in order. The composed point-and-line day.
struct TrailPlanView: View {
    let trail: Trail

    @EnvironmentObject private var focus: AppFocus
    @EnvironmentObject private var mapVM: MapViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var walk: TrailWalk?
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedSite: Site?
    @State private var pdfURL: URL?

    private let gold = Color(hex: "#C9A84C")
    private let ink = Color(red: 0.09, green: 0.08, blue: 0.07)
    private var colour: Color { Color(hex: trail.activity.colour) }

    private var origin: CLLocationCoordinate2D {
        focus.coordinate ?? mapVM.userLocation ?? trail.segments.first?.first ?? trail.coordinate
    }

    var body: some View {
        NavigationStack {
            Group {
                if let walk {
                    content(walk)
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Planning your walk…").font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("A day on the \(trail.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } }
                if let pdfURL {
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: pdfURL) { Image(systemName: "square.and.arrow.up") }
                    }
                }
            }
            .sheet(item: $selectedSite) { site in
                SiteDetailView(site: site)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .task { await compute() }
    }

    private func content(_ walk: TrailWalk) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                map(walk)
                    .frame(height: 260)
                    .overlay(alignment: .bottomLeading) { attribution }

                VStack(alignment: .leading, spacing: 16) {
                    Text(walk.summary)
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    if walk.stops.isEmpty {
                        Text("A \(walk.stretchKm >= 10 ? "\(Int(walk.stretchKm.rounded())) km" : String(format: "%.1f km", walk.stretchKm)) "
                             + "stretch. Nothing notable is catalogued right beside this part of "
                             + "the route — the walk is the thing here.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(walk.stops.enumerated()), id: \.element.id) { i, stop in
                            stopRow(number: i + 1, stop: stop)
                        }
                    }

                    Text("Walking times at an easy 4.5 km/h. \(TrailData.attribution).")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
        }
    }

    private func map(_ walk: TrailWalk) -> some View {
        Map(position: $position) {
            // The whole route, faint, for context.
            MapPolyline(coordinates: walk.fullPath)
                .stroke(colour.opacity(0.25), lineWidth: 2)
            // The stretch you'd actually walk, bold.
            MapPolyline(coordinates: walk.path)
                .stroke(colour, lineWidth: 4)

            if let start = walk.start {
                Annotation("Start", coordinate: start) { flag("flag.fill") }
            }
            if let end = walk.end {
                Annotation("Finish", coordinate: end) { flag("flag.checkered") }
            }

            ForEach(Array(walk.stops.enumerated()), id: \.element.id) { i, stop in
                Annotation(stop.site.name, coordinate: stop.site.coordinate) {
                    Button { selectedSite = stop.site } label: { numberedDisc(i + 1) }
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
        .onAppear { frame(walk) }
    }

    private func flag(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .padding(6)
            .background(ink, in: Circle())
            .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
    }

    private func numberedDisc(_ n: Int) -> some View {
        Text("\(n)")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(ink)
            .frame(width: 26, height: 26)
            .background(gold, in: Circle())
            .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
    }

    private func stopRow(number: Int, stop: TrailStopAlong) -> some View {
        Button { selectedSite = stop.site } label: {
            HStack(spacing: 12) {
                numberedDisc(number)
                VStack(alignment: .leading, spacing: 2) {
                    Text(stop.site.name).font(.body.weight(.medium)).foregroundStyle(.primary)
                        .lineLimit(2).multilineTextAlignment(.leading)
                    Text("\(distanceLabel(stop.distanceAlongKm)) in · \(stop.site.visitMinutes) min here")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                Text(String(repeating: "★", count: stop.site.tier))
                    .font(.caption2).foregroundStyle(gold)
            }
        }
        .buttonStyle(.plain)
    }

    private func distanceLabel(_ km: Double) -> String {
        km < 1 ? "\(Int(km * 1000)) m" : String(format: "%.1f km", km)
    }

    private var attribution: some View {
        Text(TrailData.attribution)
            .font(.system(size: 9))
            .foregroundStyle(.white)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(.black.opacity(0.45), in: Capsule())
            .padding(8)
    }

    private func compute() async {
        guard walk == nil else { return }
        let t = trail, o = origin
        let result = await withCheckedContinuation { (cont: CheckedContinuation<TrailWalk, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                cont.resume(returning: TrailPlanner.plan(trail: t, from: o))
            }
        }
        walk = result

        // Render the shareable PDF up front, off the main thread, so the share button has a
        // real file the moment it appears (the map snapshot inside is itself async).
        let url = await withCheckedContinuation { (cont: CheckedContinuation<URL?, Never>) in
            DispatchQueue.global(qos: .utility).async {
                cont.resume(returning: ItineraryPDF.writeTemporaryFile(result))
            }
        }
        pdfURL = url
    }

    private func frame(_ walk: TrailWalk) {
        let pts = walk.path
        guard let first = pts.first else { return }
        var minLat = first.latitude, maxLat = minLat
        var minLon = first.longitude, maxLon = minLon
        for p in pts {
            minLat = min(minLat, p.latitude); maxLat = max(maxLat, p.latitude)
            minLon = min(minLon, p.longitude); maxLon = max(maxLon, p.longitude)
        }
        position = .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                           longitude: (minLon + maxLon) / 2),
            span: MKCoordinateSpan(latitudeDelta: max((maxLat - minLat) * 1.3, 0.05),
                                   longitudeDelta: max((maxLon - minLon) * 1.3, 0.05))))
    }
}
