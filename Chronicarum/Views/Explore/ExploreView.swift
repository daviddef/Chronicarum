import SwiftUI

/// List-based discovery view with search and era/type filters.
struct ExploreView: View {
    @EnvironmentObject private var siteVM: SiteViewModel
    @EnvironmentObject private var mapVM: MapViewModel
    @State private var selectedSite: Site? = nil

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

                Divider()

                // Site list
                List(siteVM.filteredSites) { site in
                    SiteListRow(site: site)
                        .onTapGesture {
                            selectedSite = site
                        }
                }
                .listStyle(.plain)
                .searchable(text: $siteVM.searchText, prompt: "Search sites, civilisations…")
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

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: site.era.color).opacity(0.2))
                    .frame(width: 44, height: 44)
                Text(site.markerGlyph)
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(site.name)
                    .font(.body.bold())
                Text(site.location)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(site.tagline)
                    .font(.caption2.italic())
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
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
