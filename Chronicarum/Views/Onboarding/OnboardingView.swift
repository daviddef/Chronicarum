import SwiftUI

/// First-run walkthrough of what the app does and how its controls work.
///
/// A paged carousel rather than coach-marks pinned to real buttons: coach-marks have to be
/// positioned per device and per orientation and break the moment the layout moves, while
/// a page that *shows* the same icon as the real control teaches it just as well and never
/// misaligns. Each page mirrors an actual button — the dice, the lasso, the interest
/// chips — so the icon a reader sees here is the one they'll look for on the map.
///
/// Shown once, tracked in `AppStorage`; re-openable any time from the "?" in the top bar.
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0

    private let gold = Color(hex: "#C9A84C")

    private struct Page: Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        let body: String
        let tint: Color
    }

    private var pages: [Page] {
        [
            Page(symbol: "map.fill",
                 title: "260,000 real places",
                 body: "Castles, churches, Roman ruins, museums and monuments across the "
                     + "UK, France, the US, Italy, Australia and beyond — everything you "
                     + "can actually go and see.",
                 tint: gold),
            Page(symbol: "die.face.5",
                 title: "The controls, at a glance",
                 body: "On the map, the right-hand rail lets you roll the dice for a "
                     + "surprise, switch to satellite, step back through empires with the "
                     + "shield, and jump to where you are.",
                 tint: gold),
            Page(symbol: "lasso",
                 title: "Draw a region",
                 body: "Tap the lasso, then draw a loop around any area. Everything inside "
                     + "it comes up together, with the distance across and a suggested "
                     + "route through the lot.",
                 tint: .blue),
            Page(symbol: "safari.fill",
                 title: "Find what you like",
                 body: "In Explore, pick interests like Castles or Roman & classical, then "
                     + "sort by Best — the places worth the detour from where you are, "
                     + "not just the nearest.",
                 tint: .teal),
            Page(symbol: "calendar.badge.plus",
                 title: "Plan a whole trip",
                 body: "\"Seven days, castles and Roman history\" becomes a day-by-day "
                     + "itinerary — routed, sized to fit, and exportable as a PDF you can "
                     + "print or share.",
                 tint: .orange),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                    VStack(spacing: 24) {
                        ZStack {
                            Circle()
                                .fill(item.tint.opacity(0.15))
                                .frame(width: 128, height: 128)
                            Image(systemName: item.symbol)
                                .font(.system(size: 52, weight: .medium))
                                .foregroundStyle(item.tint)
                        }
                        VStack(spacing: 12) {
                            Text(item.title)
                                .font(.title2.bold())
                                .multilineTextAlignment(.center)
                            Text(item.body)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
                        }
                    }
                    .padding(.horizontal, 32)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            // Advance through the pages, then finish. Skip is always available.
            Button {
                if page < pages.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    dismiss()
                }
            } label: {
                Text(page < pages.count - 1 ? "Next" : "Start exploring")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(gold, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.black)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .padding(.top, 24)
        .overlay(alignment: .topTrailing) {
            Button("Skip") { dismiss() }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(20)
        }
        .interactiveDismissDisabled(false)
    }
}
