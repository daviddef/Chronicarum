import SwiftUI

/// List-based discovery view with search and era/type filters.
struct ExploreView: View {
    @EnvironmentObject private var siteVM: SiteViewModel
    @EnvironmentObject private var mapVM: MapViewModel
    @State private var selectedSite: Site? = nil

    @State private var showPlanner = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Era filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        EraFilterChip(label: "All", isSelected: siteVM.selectedEra == nil) {
                            siteVM.selectedEra = nil
                        }
                        ForEach(Era.allCases, id: \.self) { era in
                            EraFilterChip(
                                label: era.displayName,
                                color: Color(hex: era.color),
                                isSelected: siteVM.selectedEra == era
                            ) {
                                siteVM.selectedEra = siteVM.selectedEra == era ? nil : era
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .background(Color(.systemGroupedBackground))

                // Interest chips, above the era row because this is the question people
                // actually arrive with. Multi-select and additive, unlike the single-choice
                // era row below it.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Theme.all, id: \.rawValue) { theme in
                            let isOn = siteVM.selectedThemes.contains(theme)
                            EraFilterChip(
                                label: "\(theme.glyph) \(theme.label)",
                                color: .accentColor,
                                isSelected: isOn
                            ) {
                                if isOn { siteVM.selectedThemes.remove(theme) }
                                else    { siteVM.selectedThemes.insert(theme) }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                }
                .background(Color(.systemGroupedBackground))

                Divider()

                // Sort control — nearest by default, which is why the map asks for
                // location on launch.
                Picker("Sort", selection: $siteVM.sortMode) {
                    ForEach(SiteViewModel.SortMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                if siteVM.sortMode == .nearest && mapVM.userLocation == nil {
                    Text("Showing most significant — allow location to sort by distance.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 6)
                }

                // Site list
                List(siteVM.filteredSites(near: mapVM.userLocation)) { site in
                    SiteListRow(site: site,
                                distanceKm: mapVM.userLocation.map { site.approxDistanceKm(from: $0) })
                        .onTapGesture {
                            selectedSite = site
                        }
                }
                .listStyle(.plain)
                .searchable(text: $siteVM.searchText, prompt: "Search sites, civilisations…")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showPlanner = true
                        } label: {
                            Label("Plan a trip", systemImage: "calendar.badge.plus")
                        }
                        .disabled(mapVM.userLocation == nil)
                    }
                }
                .sheet(isPresented: $showPlanner) {
                    if let origin = mapVM.userLocation {
                        TripPlanView(origin: origin,
                                     themes: siteVM.selectedThemes,
                                     placeName: siteVM.nearestPlaceName(to: origin))
                    }
                }
            }
            .navigationTitle("Explore")
            .sheet(item: $selectedSite) { site in
                SiteDetailView(site: site)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

struct EraFilterChip: View {
    let label: String
    var color: Color = .primary
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color : color.opacity(0.12), in: Capsule())
        }
    }
}

struct SiteListRow: View {
    let site: Site
    /// Shown in the Saved tab's Visited list; nil everywhere else.
    var visitedOn: Date? = nil
    /// Straight-line distance from the user, when their location is known.
    var distanceKm: Double? = nil

    var body: some View {
        HStack(spacing: 12) {
            // Small thumbnail; the glyph tile stays as the loading and no-photo state.
            // Requests a 120px image rather than the hero's 900 so a long list doesn't
            // pull full-size photos for rows the reader scrolls straight past.
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: site.era.color).opacity(0.2))
                Text(site.markerGlyph)
                    .font(.title3)

                if let url = site.imageURL(width: 120) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.clear
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(site.name)
                    .font(.body.bold())
                Text(site.location)
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let visitedOn {
                    Text("Visited \(visitedOn.formatted(.dateTime.day().month(.abbreviated).year()))")
                        .font(.caption2)
                        .foregroundColor(Color(hex: "#C9A84C"))
                } else {
                    Text(site.tagline)
                        .font(.caption2.italic())
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let distanceKm {
                    Text(distanceKm < 1 ? "\(Int(distanceKm * 1000)) m"
                         : (distanceKm < 10 ? String(format: "%.1f km", distanceKm)
                            : "\(Int(distanceKm.rounded()).formatted()) km"))
                        .font(.caption.bold())
                        .foregroundColor(.primary)
                }
                Text(site.era.displayName)
                    .font(.caption2)
                    .foregroundColor(Color(hex: site.era.color))
                Text(String(repeating: "★", count: site.tier))
                    .font(.caption2)
                    .foregroundColor(Color(hex: "#C9A84C"))
            }
        }
        .padding(.vertical, 4)
    }
}
