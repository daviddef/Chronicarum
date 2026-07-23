import SwiftUI
import CoreLocation

/// The home tab — the one place the whole app is reached from.
///
/// Search a place at the top, and it flows everywhere: Explore lists near it, the map
/// centres on it, a plan builds around it. Below that, the four things you can do —
/// the map, explore, plan a day, your saved things — as big bright tiles rather than a
/// list of links.
struct HomeView: View {
    @Binding var selectedTab: ContentView.Tab
    @EnvironmentObject private var focus: AppFocus
    @EnvironmentObject private var mapVM: MapViewModel

    @State private var showPlan = false
    @State private var showSearch = false

    private let ink = Color(red: 0x17 / 255, green: 0x15 / 255, blue: 0x12 / 255)
    private let gold = Color(hex: "#C9A84C")
    private let columns = [GridItem(.flexible(), spacing: 14),
                           GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ZStack {
            ink.ignoresSafeArea()
            Image(systemName: "safari")
                .font(.system(size: 260, weight: .ultraLight))
                .foregroundStyle(gold.opacity(0.05))
                .offset(y: -120)

            ScrollView {
                VStack(spacing: 20) {
                    Text("CHRONICARUM")
                        .font(.system(size: 24, weight: .bold, design: .serif))
                        .tracking(4)
                        .foregroundStyle(gold)
                        .padding(.top, 12)

                    // ── Search a place ───────────────────────────────────
                    Button {
                        showSearch = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                            Text(focus.name ?? "Search a place")
                                .lineLimit(1)
                            Spacer()
                            if focus.coordinate != nil {
                                Button {
                                    focus.clear()
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .foregroundStyle(focus.name == nil ? .white.opacity(0.55) : gold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                        .background(.white.opacity(0.08), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    if focus.coordinate != nil {
                        Text("Everything below is now centred on \(focus.name ?? "there").")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // ── The four things ──────────────────────────────────
                    LazyVGrid(columns: columns, spacing: 14) {
                        HomeTile(title: "The map", subtitle: "Browse and draw a region",
                                 icon: "map.fill", colour: gold) { selectedTab = .map }
                        HomeTile(title: "Explore", subtitle: focus.name.map { "Places around \($0)" } ?? "Places near me",
                                 icon: "safari.fill", colour: Color(hex: "#2FA39B")) { selectedTab = .explore }
                        HomeTile(title: "Plan a day", subtitle: "What kind of day?",
                                 icon: "sparkles", colour: Color(hex: "#C2603C")) { showPlan = true }
                        HomeTile(title: "Saved", subtitle: "Trips, bookmarks and visits",
                                 icon: "bookmark.fill", colour: Color(hex: "#4E7BC4")) { selectedTab = .saved }
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $showPlan) {
            PlanIntentView()
        }
        .sheet(isPresented: $showSearch) {
            LocationPickerView { coordinate, name in
                focus.set(coordinate, name: name)
            }
        }
    }
}

/// A big colourful home destination tile.
private struct HomeTile: View {
    let title: String
    let subtitle: String
    let icon: String
    let colour: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.white)
                Spacer(minLength: 12)
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
            .padding(16)
            .background(
                LinearGradient(colors: [colour, colour.opacity(0.72)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(.white.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: colour.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}
