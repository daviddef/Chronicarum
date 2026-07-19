import SwiftUI

struct SavedView: View {
    @EnvironmentObject private var siteVM: SiteViewModel
    @EnvironmentObject private var mapVM: MapViewModel
    @State private var selectedTab: SavedTab = .bookmarked
    @State private var selectedSite: Site? = nil

    enum SavedTab: String, CaseIterable {
        case bookmarked = "Bookmarked"
        case visited    = "Visited"
    }

    var displayedSites: [Site] {
        switch selectedTab {
        case .bookmarked: return siteVM.bookmarkedSites
        case .visited:    return siteVM.visitedSites
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    ForEach(SavedTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                if displayedSites.isEmpty {
                    ContentUnavailableView(
                        selectedTab == .bookmarked ? "No Bookmarks Yet" : "No Visited Sites",
                        systemImage: selectedTab == .bookmarked ? "bookmark" : "checkmark.circle",
                        description: Text(
                            selectedTab == .bookmarked
                            ? "Tap the bookmark icon on any site to save it here."
                            : "Mark sites as visited after you've been there."
                        )
                    )
                } else {
                    List {
                        // The record turns a flat list into something worth revisiting —
                        // shown only for Visited, where the figures mean something.
                        if selectedTab == .visited {
                            TravelRecordView(record: siteVM.travelRecord(from: mapVM.userLocation))
                                .listRowInsets(EdgeInsets(top: 8, leading: 16,
                                                          bottom: 12, trailing: 16))
                                .listRowSeparator(.hidden)
                        }

                        ForEach(displayedSites) { site in
                            SiteListRow(site: site,
                                        visitedOn: selectedTab == .visited
                                            ? siteVM.visitDate(for: site) : nil)
                                .onTapGesture { selectedSite = site }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        if selectedTab == .bookmarked {
                                            siteVM.toggleBookmark(site)
                                        } else {
                                            siteVM.toggleVisited(site)
                                        }
                                    } label: {
                                        Label("Remove", systemImage: selectedTab == .bookmarked
                                              ? "bookmark.slash" : "xmark.circle")
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Saved")
            .sheet(item: $selectedSite) { site in
                SiteDetailView(site: site)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}


// MARK: - Travel record

/// Summary of everywhere the user has been. Deliberately superlatives and counts rather
/// than a score — the research on collection loops is that a personal archive retains,
/// while points across heterogeneous places read as arbitrary.
struct TravelRecordView: View {
    let record: SiteViewModel.TravelRecord

    private var lastVisitText: String? {
        guard let last = record.lastVisit else { return nil }
        let days = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
        switch days {
        case 0:      return "Today"
        case 1:      return "Yesterday"
        case 2...30: return "\(days) days ago"
        default:     return last.formatted(.dateTime.month(.abbreviated).year())
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your Record")
                .font(.headline)

            HStack(spacing: 0) {
                RecordCell(value: "\(record.visitedCount)", label: "Sites")
                Divider().frame(height: 30)
                RecordCell(value: "\(record.countries)", label: "Countries")
                if let km = record.furthestKm {
                    Divider().frame(height: 30)
                    RecordCell(value: "\(km.formatted()) km", label: "Furthest")
                }
            }

            if let oldest = record.oldestSite {
                RecordLine(icon: "hourglass",
                           text: "Oldest: **\(oldest.name)** — \(oldest.builtDescription)")
            }
            if let furthest = record.furthestSite {
                RecordLine(icon: "location.north.line",
                           text: "Furthest from you: **\(furthest.name)**")
            }
            if let last = lastVisitText {
                RecordLine(icon: "calendar", text: "Last visited: **\(last)**")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#C9A84C").opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct RecordCell: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.bold())
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct RecordLine: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(Color(hex: "#C9A84C"))
                .frame(width: 16)
            Text(.init(text)).font(.caption)
            Spacer()
        }
    }
}
