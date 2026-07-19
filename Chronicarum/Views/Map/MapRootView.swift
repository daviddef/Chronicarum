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
            // Content order is z-order: empire fills sit beneath their labels,
            // which sit beneath the site markers.
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
    }
}

#Preview {
    MapRootView()
        .environmentObject(MapViewModel(locationService: LocationService()))
        .environmentObject(SiteViewModel())
}
