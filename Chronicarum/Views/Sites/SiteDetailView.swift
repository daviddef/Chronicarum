import SwiftUI

/// Bottom sheet that appears when a map marker is tapped.
/// Shows the storyboard chapters, facts, and travel info.
struct SiteDetailView: View {
    let site: Site
    @EnvironmentObject private var siteVM: SiteViewModel
    @EnvironmentObject private var mapVM: MapViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedChapter: Int = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // ── Hero ─────────────────────────────────────────────
                    SiteHeroView(site: site)

                    // ── Quick facts strip ─────────────────────────────────
                    SiteQuickFactsView(site: site)
                        .padding(.horizontal)
                        .padding(.vertical, 12)

                    Divider()

                    // ── Chapter picker ────────────────────────────────────
                    if !site.chapters.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(Array(site.chapters.enumerated()), id: \.offset) { idx, ch in
                                    ChapterTabButton(
                                        title: ch.title,
                                        isSelected: selectedChapter == idx
                                    ) {
                                        withAnimation { selectedChapter = idx }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }

                        let chapter = site.chapters[selectedChapter]
                        ChapterContentView(chapter: chapter)
                            .padding(.horizontal, 16)
                    }

                    // ── Travel Layer ──────────────────────────────────────
                    TravelLayerView(site: site)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    // ── Nearby Sites ──────────────────────────────────────
                    let nearby = siteVM.nearbySites(to: site)
                    if !nearby.isEmpty {
                        NearbySitesView(sites: nearby)
                            .padding(.top, 16)
                    }

                    Spacer(minLength: 40)
                }
            }
            .navigationTitle(site.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            siteVM.toggleBookmark(site)
                        } label: {
                            Image(systemName: siteVM.isBookmarked(site) ? "bookmark.fill" : "bookmark")
                        }

                        Button {
                            mapVM.zoomToSite(site)
                            dismiss()
                        } label: {
                            Image(systemName: "map")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Sub-components

struct SiteHeroView: View {
    let site: Site

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Placeholder — replace with AsyncImage once photo URLs are in data
            Rectangle()
                .fill(Color(hex: site.era.color).opacity(0.3))
                .frame(height: 200)
                .overlay(
                    Text(site.type.emoji)
                        .font(.system(size: 72))
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    EraTagView(era: site.era)
                    TypeTagView(type: site.type)
                }
                Text(site.tagline)
                    .font(.callout.italic())
                    .foregroundColor(.white)
                    .shadow(radius: 2)
            }
            .padding(12)
        }
    }
}

struct SiteQuickFactsView: View {
    let site: Site

    var body: some View {
        HStack(spacing: 0) {
            QuickFactCell(label: "Built", value: site.builtDescription)
            Divider().frame(height: 32)
            QuickFactCell(label: "Civilisation", value: site.civilisation)
            Divider().frame(height: 32)
            QuickFactCell(label: "Significance", value: String(repeating: "★", count: site.tier))
        }
    }
}

struct QuickFactCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption.bold())
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ChapterTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .bold : .regular))
                .foregroundColor(isSelected ? Color(hex: "#C9A84C") : .secondary)
                .padding(.bottom, 4)
                .overlay(alignment: .bottom) {
                    if isSelected {
                        Rectangle()
                            .fill(Color(hex: "#C9A84C"))
                            .frame(height: 2)
                    }
                }
        }
    }
}

struct ChapterContentView: View {
    let chapter: Chapter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(chapter.eyebrow.uppercased())
                .font(.caption)
                .foregroundColor(.secondary)
                .tracking(1.5)

            Text(chapter.heading)
                .font(.title3.bold())

            Text(chapter.attributedBody)
                .font(.body)
                .foregroundColor(.secondary)

            if !chapter.facts.isEmpty {
                FactsGridView(facts: chapter.facts)
                    .padding(.top, 8)
            }
        }
    }
}

struct FactsGridView: View {
    let facts: [Fact]
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(facts) { fact in
                VStack(alignment: .leading, spacing: 2) {
                    Text(fact.label)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(fact.value)
                        .font(.caption.bold())
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

struct TravelLayerView: View {
    let site: Site

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Getting There")
                .font(.headline)

            if let airport = site.nearestAirport {
                TravelRow(icon: "airplane", label: "Nearest airport", value: airport)
            }
            if let timing = site.bestTimeToVisit {
                TravelRow(icon: "sun.max", label: "Best time", value: timing)
            }
            if let visa = site.visaNote {
                TravelRow(icon: "doc.text", label: "Visa", value: visa)
            }
        }
    }
}

struct TravelRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#C9A84C"))
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.caption)
            }
            Spacer()
        }
    }
}

struct NearbySitesView: View {
    let sites: [Site]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nearby Heritage Sites")
                .font(.headline)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(sites.prefix(5)) { site in
                        NearbySiteCard(site: site)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

struct NearbySiteCard: View {
    let site: Site

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(site.type.emoji)
                .font(.title2)
            Text(site.name)
                .font(.caption.bold())
                .lineLimit(2)
            Text(site.location)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(width: 110)
        .padding(10)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct EraTagView: View {
    let era: Era
    var body: some View {
        Text(era.displayName)
            .font(.caption2.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color(hex: era.color), in: Capsule())
    }
}

struct TypeTagView: View {
    let type: SiteType
    var body: some View {
        Text(type.displayName)
            .font(.caption2)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.black.opacity(0.5), in: Capsule())
    }
}
