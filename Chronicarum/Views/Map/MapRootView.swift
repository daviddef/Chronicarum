import SwiftUI
import MapKit

/// Primary map view — hosts the world map, site markers, conquest overlay, and map controls.
struct MapRootView: View {
    @EnvironmentObject private var mapVM: MapViewModel
    @EnvironmentObject private var siteVM: SiteViewModel
    @State private var showSiteSheet = false
    @State private var showFilters   = false
    @State private var surprisedSite: Site? = nil
    @State private var tappedCluster: SiteCluster? = nil

    /// Screen-space points of the loop being drawn, in the map's local coordinate space.
    @State private var lassoPoints: [CGPoint] = []

    /// Flat elevation throughout, deliberately. `.realistic` renders lovely 3D terrain but
    /// occludes the site annotations in imagery mode — markers simply vanish, which was
    /// verified on device. Markers are the app; terrain relief is decoration. Realistic is
    /// also A12-only, limited to Apple's 3D metros, and silently disabled whenever an
    /// overlay is present — which the conquest timeline always is.
    ///
    /// `.muted` emphasis pulls back Apple's own POI pins so 24k heritage markers read as
    /// the foreground rather than competing with restaurant labels.
    private var mapStyle: MapStyle {
        switch mapVM.styleMode {
        case .standard: return .standard(elevation: .flat, emphasis: .muted)
        case .hybrid:   return .hybrid(elevation: .flat)
        case .imagery:  return .imagery(elevation: .flat)
        }
    }

    var body: some View {
        ZStack(alignment: .top) {

            // ── Base Map ─────────────────────────────────────────────────────
            // `MapReader` hands us a proxy that converts between screen points and map
            // coordinates — the one capability the draw-a-region feature needs.
            // Content order is z-order: empire fills sit beneath their labels,
            // which sit beneath the site markers.
            MapReader { proxy in
            Map(position: $mapVM.cameraPosition) {

                if mapVM.timelineState.isVisible, let period = mapVM.timelineState.currentPeriod {

                    // Empire territory polygons
                    ForEach(period.empires) { empire in
                        MapPolygon(coordinates: empire.coordinates)
                            .foregroundStyle(Color(hex: empire.color).opacity(0.32))
                            .stroke(Color(hex: empire.color), lineWidth: 1.5)
                    }

                    // Historical region names (ROMA, PERSIA, …)
                    ForEach(period.regionLabels) { label in
                        Annotation("", coordinate: label.coordinate) {
                            Text(label.name)
                                .font(.system(size: 9, weight: .semibold, design: .serif))
                                .tracking(0.5)
                                .foregroundStyle(.primary.opacity(0.75))
                                .shadow(color: .white.opacity(0.7), radius: 1)
                        }
                        .annotationTitles(.hidden)
                    }
                }

                // Site markers — clustered at the current zoom so dense regions stay
                // legible. A single-site cluster renders as its marker; a group renders
                // as a count bubble that zooms in when tapped.
                ForEach(mapVM.clusteredItems) { item in
                    Annotation("", coordinate: item.coordinate) {
                        if item.isSingle {
                            let site = item.representative
                            SiteMarkerView(site: site, isSelected: mapVM.selectedSite?.id == site.id)
                                .onTapGesture {
                                    mapVM.selectSite(site)
                                    showSiteSheet = true
                                }
                        } else {
                            ClusterMarkerView(cluster: item)
                                .onTapGesture { tappedCluster = item }
                        }
                    }
                    .annotationTitles(.hidden)
                }

                UserAnnotation()
            }
            .mapStyle(mapStyle)
            .onMapCameraChange(frequency: .onEnd) { context in
                mapVM.noteCameraChanged(to: context.region)
            }
            .ignoresSafeArea()
            .task { mapVM.requestInitialLocationIfNeeded() }
            // ── Draw-a-region layer ──────────────────────────────────────
            // Only present while lassoing, so it never steals the map's pan/zoom the
            // rest of the time. It sits on top and captures the drag itself, tracing a
            // loop; on release the loop becomes coordinates and then a cluster.
            .overlay {
                if mapVM.isLassoActive {
                    LassoDrawingLayer(points: $lassoPoints) {
                        finishLasso(using: proxy)
                    }
                }
            }
            } // MapReader

            // ── HUD ──────────────────────────────────────────────────────────
            // The controls rail sits *below* the top bar in the same stack rather
            // than floating over it — overlaying the same corner covered the top
            // bar's filter button and made it untappable.
            VStack(spacing: 0) {
                MapTopBarView(showFilters: $showFilters)

                HStack {
                    Spacer()
                    MapControlsView(surprisedSite: $surprisedSite)
                        .padding(.trailing, 12)
                        .padding(.top, 12)
                }

                Spacer()

                if mapVM.isLassoActive {
                    Text("Draw a loop around the places you want to explore")
                        .font(.footnote.weight(.medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: Capsule())
                        .shadow(radius: 3)
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if mapVM.timelineState.isVisible {
                    ConquestTimelineBar()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onChange(of: surprisedSite?.id) { _, newID in
            if newID != nil { showSiteSheet = true }
        }
        // ── Site Detail Sheet ─────────────────────────────────────────────
        .sheet(isPresented: $showSiteSheet) {
            if let site = mapVM.selectedSite {
                SiteDetailView(site: site)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        // ── Cluster Overlay ───────────────────────────────────────────────
        .sheet(item: $tappedCluster) { cluster in
            ClusterSheetView(
                cluster: cluster,
                userLocation: mapVM.userLocation,
                onSelect: { site in
                    mapVM.selectSite(site)
                    // Let the cluster sheet finish dismissing before the detail appears;
                    // presenting both in the same runloop turn drops the second one.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        showSiteSheet = true
                    }
                },
                onZoomToArea: { mapVM.expandCluster(cluster) }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        // ── Filter Sheet ──────────────────────────────────────────────────
        .sheet(isPresented: $showFilters) {
            MapFilterView()
                .presentationDetents([.medium])
        }
        .animation(.easeInOut(duration: 0.3), value: mapVM.timelineState.isVisible)
        .animation(.easeInOut(duration: 0.2), value: mapVM.isLassoActive)
    }

    /// Turn the drawn screen loop into a cluster of the sites inside it.
    private func finishLasso(using proxy: MapProxy) {
        defer {
            lassoPoints = []
            mapVM.isLassoActive = false
        }
        // A stray tap is not a region. Three points is the minimum for an area, and a few
        // more avoids treating an accidental flick as a loop.
        guard lassoPoints.count >= 5 else { return }

        // Screen points → coordinates. Points that fall off the projected map (past the
        // poles, off the edge of an imagery tile) simply drop out.
        let coords = lassoPoints.compactMap { proxy.convert($0, from: .local) }
        guard coords.count >= 3, let cluster = mapVM.lassoCluster(from: coords) else { return }
        tappedCluster = cluster
    }
}

/// The transparent layer that captures the drag and traces the loop while the user draws.
///
/// It sits over the map only while lassoing and swallows the gesture, so the map's own
/// pan and zoom never fight the drawing. The trace is closed back to its start as it goes,
/// so the shape reads as an enclosed region rather than an open squiggle.
private struct LassoDrawingLayer: View {
    @Binding var points: [CGPoint]
    let onEnd: () -> Void

    var body: some View {
        Canvas { context, _ in
            guard points.count > 1 else { return }
            var path = Path()
            path.addLines(points)
            path.closeSubpath()
            context.stroke(path, with: .color(Color(hex: "#C9A84C")),
                           style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            context.fill(path, with: .color(Color(hex: "#C9A84C").opacity(0.12)))
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in points.append(value.location) }
                .onEnded { _ in onEnd() }
        )
    }
}

#Preview {
    MapRootView()
        .environmentObject(MapViewModel(locationService: LocationService()))
        .environmentObject(SiteViewModel())
}
