import SwiftUI
import MapKit

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

                    // ── Look Around ───────────────────────────────────────
                    SiteLookAroundView(site: site)
                        .padding(.horizontal, 16)

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

                    // ── Part of a larger site ─────────────────────────────
                    if let parent = siteVM.parentSite(of: site) {
                        PartOfView(parent: parent)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                    }

                    // ── Wikipedia summary (fetched, never bundled) ────────
                    WikipediaSummaryView(site: site)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    // ── Register history (French monuments) ───────────────
                    if let history = site.monumentHistory {
                        MonumentHistoryView(text: history)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                    }

                    // ── When is it open ───────────────────────────────────
                    OpeningHoursView(site: site)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

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

                    // ── Data source ───────────────────────────────────────
                    // Only for datasets whose licence requires the credit; Wikidata is
                    // CC0 and shows nothing.
                    if let source = site.dataSource {
                        SiteDataSourceView(source: source)
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                    }

                    Spacer(minLength: 40)
                }
            }
            .navigationTitle(site.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        // The Saved tab has always had a Visited section, but nothing
                        // could fill it — there was no way to mark a site visited.
                        Button {
                            siteVM.toggleVisited(site)
                        } label: {
                            Image(systemName: siteVM.isVisited(site)
                                  ? "checkmark.circle.fill" : "checkmark.circle")
                        }
                        .accessibilityLabel(siteVM.isVisited(site) ? "Mark as not visited" : "Mark as visited")

                        Button {
                            siteVM.toggleBookmark(site)
                        } label: {
                            Image(systemName: siteVM.isBookmarked(site) ? "bookmark.fill" : "bookmark")
                        }
                        .accessibilityLabel(siteVM.isBookmarked(site) ? "Remove bookmark" : "Bookmark")

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

    /// Era-tinted panel with the site's glyph — shown while the photo loads, and kept
    /// as the final state for sites that have none.
    private var placeholder: some View {
        Rectangle()
            .fill(Color(hex: site.era.color).opacity(0.3))
            .overlay(Text(site.markerGlyph).font(.system(size: 72)))
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let url = site.imageURL(width: 900) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            // Covers both loading and failure: a broken or missing photo
                            // degrades to the glyph rather than an empty grey box.
                            placeholder
                        }
                    }
                } else {
                    placeholder
                }
            }
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .clipped()

            // Keeps the tagline legible over an arbitrary photo.
            LinearGradient(colors: [.clear, .black.opacity(0.55)],
                           startPoint: .center, endPoint: .bottom)
                .frame(height: 200)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    EraTagView(era: site.era)
                    TypeTagView(type: site.type)
                }
                if !site.tagline.isEmpty {
                    Text(site.tagline)
                        .font(.callout.italic())
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                }
            }
            .padding(12)

            // Most of these licences (CC BY-SA and friends) require naming the author,
            // so credit them on the image itself and link to the file page for the full
            // terms. Falls back to the bare source when the credit isn't known.
            if let creditURL = site.imageCreditURL {
                Link(destination: creditURL) {
                    Text(site.photoCredit?.summary ?? "Wikimedia Commons")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.4), in: Capsule())
                }
                .frame(maxWidth: 260, alignment: .trailing)
                .frame(maxWidth: .infinity, maxHeight: 200, alignment: .topTrailing)
                .padding(8)
            }
        }
        .frame(height: 200)
    }
}

/// A Wikipedia summary, fetched on demand.
///
/// Renders nothing at all until the text arrives — no spinner, no empty box. Most sites
/// have no article, and a placeholder on every one of them would be worse than silence.
struct WikipediaSummaryView: View {
    let site: Site
    @State private var summary: WikipediaExtract.Summary?

    var body: some View {
        // A VStack rather than a Group: a Group whose body resolves to EmptyView is not
        // guaranteed to be instantiated, so `.task` never ran and the summary never
        // loaded. An always-present container with conditional content does run it, and
        // collapses to nothing when there is no article.
        VStack(alignment: .leading, spacing: 8) {
            if let summary {
                    Text("About").font(.headline)
                    Text(summary.text)
                        .font(.callout)
                        .foregroundColor(.primary.opacity(0.85))
                        .lineSpacing(3)
                        .textSelection(.enabled)
                    if let url = summary.articleURL {
                        // CC BY-SA is satisfied by a link to the page reused, which is
                        // also the thing a reader wants next.
                        Link(destination: url) {
                            Text("From Wikipedia · CC BY-SA 4.0")
                                .font(.caption2)
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: site.id) {
            summary = await WikipediaExtract.summary(for: site)
        }
    }
}

/// What is *typically* true about opening, plus a way to check the truth.
///
/// Never states hours. There is no source for them — see `OpeningPattern` — and inventing
/// them would send someone across a city to a locked door.
struct OpeningHoursView: View {
    let site: Site

    var body: some View {
        if site.openingPattern != nil || site.officialWebsite != nil {
            VStack(alignment: .leading, spacing: 8) {
                Text("Visiting").font(.headline)

                if let pattern = site.openingPattern {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "clock").font(.system(size: 11))
                        Text(pattern.note)
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)

                    if pattern.isSeasonal {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "leaf").font(.system(size: 11))
                            Text("Hours usually vary by season.")
                        }
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    }
                }

                if let website = site.officialWebsite {
                    Link(destination: website) {
                        HStack(spacing: 6) {
                            Image(systemName: "safari")
                            Text("Check the official site")
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.right").font(.system(size: 10))
                        }
                        .font(.footnote.weight(.medium))
                    }
                    .padding(.top, 2)
                }

                Text("We don't know this site's actual hours — no heritage register "
                     + "records them. The above is what's typical for this kind of place.")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.8))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

/// "Part of Historical Complex of Split" — so a reader understands why a nearby record
/// covers the same stones, and a planner knows not to schedule both.
struct PartOfView: View {
    let parent: Site

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text("Part of").font(.caption2).foregroundColor(.secondary)
                Text(parent.name).font(.subheadline.weight(.medium)).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

/// The Mérimée register's own account of a French monument.
///
/// Labelled "En français" because it is not translated, and saying so is better than
/// letting a reader hit a wall of French with no warning. `.textSelection` lets anyone
/// who wants a translation lift it into one.
struct MonumentHistoryView: View {
    let text: String
    @State private var expanded = false

    /// These run to ~525 characters at the median and well past 2,000 at the tail, which
    /// would push the travel and nearby sections off the bottom of the sheet.
    private var isLong: Bool { text.count > 400 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("History")
                    .font(.headline)
                Text("En français")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
            }

            Text(text)
                .font(.callout)
                .foregroundColor(.primary.opacity(0.85))
                .lineSpacing(3)
                .lineLimit(expanded || !isLong ? nil : 6)
                .textSelection(.enabled)

            if isLong {
                Button(expanded ? "Show less" : "Read more") {
                    withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                }
                .font(.caption.bold())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Credits the register a site came from, as its licence requires.
struct SiteDataSourceView: View {
    let source: DataSource

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "building.columns")
                .font(.system(size: 10))
            Text(source.credit)
                .font(.system(size: 11))
            Spacer(minLength: 0)
            if source.url != nil {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9))
            }
        }
        .foregroundColor(.secondary)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .modifier(OptionalLink(url: source.url))
    }
}

/// Wraps the credit in a `Link` when there's somewhere to send the reader, and leaves it
/// as plain text when there isn't — so a future source without a public URL still renders.
private struct OptionalLink: ViewModifier {
    let url: URL?

    func body(content: Content) -> some View {
        if let url {
            Link(destination: url) { content }
        } else {
            content
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
            if let duration = site.visitDurationLabel {
                Divider().frame(height: 32)
                QuickFactCell(label: "Visit", value: duration)
            }
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

    private var hasTravelInfo: Bool {
        site.nearestAirport != nil || site.bestTimeToVisit != nil || site.visaNote != nil
    }

    var body: some View {
        // Bulk-imported sites carry no travel fields — skip the section entirely rather
        // than show a "Getting There" header with nothing under it.
        if hasTravelInfo {
            VStack(alignment: .leading, spacing: 8) {
                Text("Getting There")
                    .font(.headline)

                // Sites under a government warning say so up front, not buried at the
                // end of the visa paragraph.
                if site.hasTravelAdvisory {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("This site is under a government travel advisory. Check your "
                             + "foreign ministry's current guidance before making plans.")
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                }

                if let airport = site.nearestAirport {
                    TravelRow(icon: "airplane", label: "Nearest airport", value: airport)
                }
                if let timing = site.bestTimeToVisit {
                    TravelRow(icon: "sun.max", label: "Best time", value: timing)
                }
                if let visa = site.visaNote {
                    TravelRow(icon: "doc.text", label: "Visa", value: visa)
                }

                // These fields are hand-written and frozen at research time — visa rules
                // and opening arrangements move. Saying so is the honest minimum; a live
                // source is the real fix (see ROADMAP).
                Text("Travel details were researched in July 2026 and are indicative "
                     + "only. Verify with official sources before booking.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
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
            Text(site.markerGlyph)
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


// MARK: - Look Around

/// Street-level imagery for the site, when Apple has any.
///
/// Fetched lazily when the sheet opens rather than prefetched for a list: there is no
/// batch or coverage API, and firing a request per visible row trips `.loadingThrottled`.
/// Many heritage sites legitimately have no imagery — coverage follows drivable roads, and
/// a hilltop ruin or a walled archaeological site often isn't on one — so the whole
/// section simply doesn't appear rather than showing an empty frame.
struct SiteLookAroundView: View {
    let site: Site

    @State private var scene: MKLookAroundScene?
    @State private var hasLoaded = false

    var body: some View {
        Group {
            if let scene {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Look Around")
                        .font(.headline)

                    LookAroundPreview(initialScene: scene)
                        .frame(height: 170)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.top, 12)
            }
        }
        .task(id: site.id) { await loadScene() }
    }

    private func loadScene() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        // `try?` deliberately collapses "no coverage here" and "request failed" — both
        // resolve to hiding the section, so distinguishing them would change nothing the
        // reader sees.
        scene = try? await MKLookAroundSceneRequest(coordinate: site.coordinate).scene
    }
}
