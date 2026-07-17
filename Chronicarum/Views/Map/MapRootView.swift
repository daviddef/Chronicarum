import SwiftUI
import MapKit

/// Primary map view — hosts the world map, site markers, conquest overlay, and map controls.
struct MapRootView: View {
    @EnvironmentObject private var mapVM: MapViewModel
    @EnvironmentObject private var siteVM: SiteViewModel
    @State private var showSiteSheet = false
    @State private var showFilters   = false

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
                                .onTapGesture {
                                    if let site = mapVM.expandCluster(item) {
                                        mapVM.selectSite(site)
                                        showSiteSheet = true
                                    }
                                }
                        }
                    }
                    .annotationTitles(.hidden)
                }

                UserAnnotation()
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                mapVM.visibleRegion = context.region
            }
            .ignoresSafeArea()

            // ── HUD ──────────────────────────────────────────────────────────
            // The controls rail sits *below* the top bar in the same stack rather
            // than floating over it — overlaying the same corner covered the top
            // bar's filter button and made it untappable.
            VStack(spacing: 0) {
                MapTopBarView(showFilters: $showFilters)

                HStack {
                    Spacer()
                    MapControlsView()
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
        // ── Site Detail Sheet ─────────────────────────────────────────────
        .sheet(isPresented: $showSiteSheet) {
            if let site = mapVM.selectedSite {
                SiteDetailView(site: site)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
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
