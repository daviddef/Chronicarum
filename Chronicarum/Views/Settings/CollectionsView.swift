import SwiftUI

/// Bounded sets you can finish, and how far through them you are.
///
/// Deliberately not a badge wall. Over a thousand collections exist and this screen shows
/// perhaps a dozen — the ones you have started and the ones where you are standing — for
/// the reason Foursquare gave when it removed its own badges: once there are hundreds, none
/// of them mean anything.
struct CollectionsView: View {
    @EnvironmentObject private var siteVM: SiteViewModel
    @EnvironmentObject private var mapVM: MapViewModel
    @State private var opened: ResolvedCollection?

    /// Stored, not computed.
    ///
    /// As a computed property this sorted and filtered 1,271 collections on *every*
    /// SwiftUI body pass, including passes caused by unrelated state — which is precisely
    /// the bug `clusteredItems` already had once in this app. Recomputed only when the
    /// inputs actually change.
    @State private var sets: (inProgress: [ResolvedCollection],
                              nearby: [ResolvedCollection],
                              worldHeritage: [ResolvedCollection]) = ([], [], [])

    var body: some View {
        Group {
            if sets.inProgress.isEmpty && sets.nearby.isEmpty && sets.worldHeritage.isEmpty {
                ContentUnavailableView(
                    "Nothing to collect yet",
                    systemImage: "checklist",
                    description: Text("Mark somewhere as visited, or open the map where you "
                                      + "are, and the sets you're partway through will "
                                      + "show up here."))
            } else {
                List {
                    section("Underway", sets.inProgress)
                    section("Around you", sets.nearby)
                    section("World Heritage", sets.worldHeritage)
                }
                .listStyle(.insetGrouped)
            }
        }
        // Resolving the store touches all 294k sites the first time, so it happens off the
        // main thread; the visited set changing is what makes a ring move, so that is what
        // recomputes it.
        .task(id: siteVM.visitedIDs) { await refresh() }
        .task(id: mapVM.userLocation.map { "\($0.latitude),\($0.longitude)" }) {
            await refresh()
        }
        .sheet(item: $opened) { collection in
            NavigationStack {
                CollectionDetailView(collection: collection)
            }
        }
    }

    private func refresh() async {
        let origin = mapVM.userLocation
        let visited = siteVM.visitedIDs
        let computed = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning:
                    SiteCollectionStore.surfaced(near: origin, visitedIDs: visited))
            }
        }
        guard !Task.isCancelled else { return }
        sets = computed
    }

    @ViewBuilder
    private func section(_ title: String, _ collections: [ResolvedCollection]) -> some View {
        if !collections.isEmpty {
            Section(title) {
                ForEach(collections) { collection in
                    Button { opened = collection } label: {
                        CollectionRow(collection: collection,
                                      visited: collection.visitedCount(in: siteVM.visitedIDs))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct CollectionRow: View {
    let collection: ResolvedCollection
    let visited: Int

    private var fraction: Double {
        collection.total == 0 ? 0 : Double(visited) / Double(collection.total)
    }

    var body: some View {
        HStack(spacing: 12) {
            ProgressRing(fraction: fraction)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(collection.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                Text(visited == collection.total
                     ? "Complete — all \(collection.total)"
                     : "\(visited) of \(collection.total)")
                    .font(.caption)
                    .foregroundColor(visited == collection.total ? Color(hex: "#C9A84C")
                                                                 : .secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }
}

/// A ring rather than a bar: it reads as a proportion of a whole, which is the entire point
/// of the set being finite.
private struct ProgressRing: View {
    let fraction: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 4)
            Circle()
                .trim(from: 0, to: max(fraction, 0.001))
                .stroke(Color(hex: "#C9A84C"),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if fraction >= 1 {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: "#C9A84C"))
            } else {
                Text("\(Int(fraction * 100))")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .animation(.easeOut(duration: 0.3), value: fraction)
    }
}

/// The members of one collection, ticked or not.
struct CollectionDetailView: View {
    let collection: ResolvedCollection
    @EnvironmentObject private var siteVM: SiteViewModel
    @EnvironmentObject private var mapVM: MapViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSite: Site?

    var body: some View {
        List {
            Section {
                Text(collection.blurb)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                // Never let the count imply a completeness it does not have — and never
                // blame one cause for the other. These are separate on purpose.
                if collection.missingFromCatalogue > 0 {
                    Label("\(collection.missingFromCatalogue) more are on UNESCO's list but "
                          + "aren't in Chronicarum yet.",
                          systemImage: "info.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if collection.excludedAsSensitive > 0 {
                    Label(collection.excludedAsSensitive == 1
                          ? "One place on this list is a site of atrocity or burial. It's in "
                            + "the app, but it isn't something to tick off, so it's left out here."
                          : "\(collection.excludedAsSensitive) places on this list are sites "
                            + "of atrocity or burial. They're in the app, but they aren't "
                            + "things to tick off, so they're left out here.",
                          systemImage: "hand.raised")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section {
                ForEach(collection.sites) { site in
                    Button { selectedSite = site } label: {
                        HStack(spacing: 10) {
                            Image(systemName: siteVM.isVisited(site)
                                  ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(siteVM.isVisited(site)
                                                 ? Color(hex: "#C9A84C") : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(site.name)
                                    .font(.subheadline)
                                    .lineLimit(2)
                                if !site.location.isEmpty {
                                    Text(site.location)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer(minLength: 0)
                            if let origin = mapVM.userLocation {
                                Text("\(Int(site.approxDistanceKm(from: origin))) km")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("\(collection.visitedCount(in: siteVM.visitedIDs)) of \(collection.total) visited")
            }
        }
        .navigationTitle(collection.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(item: $selectedSite) { site in
            SiteDetailView(site: site)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}
