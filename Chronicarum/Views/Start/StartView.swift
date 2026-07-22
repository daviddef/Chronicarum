import SwiftUI
import CoreLocation

/// The opening screen — and the splash, which are the same thing.
///
/// They used to be two: an animated splash that faded out, then a grey list sheet thrown
/// over the map. It read as three unrelated screens in two seconds, and presenting a sheet
/// from a sheet made the plan unreliable to reach. Now the wordmark animates in exactly as
/// the splash always did, settles upward, and the cards arrive underneath it. Nothing is
/// dismissed and nothing is presented; one shot, one background.
///
/// **Always dark.** The ink and gold are the app's own, and matching the system's light
/// appearance here produced the grey card list this replaced — a screen that looked like
/// Settings rather than like the splash it follows.
struct StartView: View {
    @EnvironmentObject private var mapVM: MapViewModel
    @EnvironmentObject private var siteVM: SiteViewModel
    /// Straight to the map, for anyone who would rather browse than be asked.
    let onSkip: () -> Void

    @State private var wordmarkIn = false
    @State private var ruleWidth: CGFloat = 0
    @State private var cardsIn = false
    @State private var chosen: DayIntent?

    private let gold = Color(hex: "#C9A84C")
    private let ink = Color(red: 0x17 / 255, green: 0x15 / 255, blue: 0x12 / 255)

    private let columns = [GridItem(.flexible(), spacing: 14),
                           GridItem(.flexible(), spacing: 14)]

    private var origin: CLLocationCoordinate2D {
        mapVM.userLocation ?? mapVM.visibleRegion.center
    }

    var body: some View {
        ZStack {
            ink.ignoresSafeArea()

            // The same compass motif the splash always had, still behind everything.
            Image(systemName: "safari")
                .font(.system(size: 240, weight: .ultraLight))
                .foregroundStyle(gold.opacity(0.05))
                .scaleEffect(wordmarkIn ? 1 : 0.85)
                .offset(y: cardsIn ? -220 : 0)

            VStack(spacing: 0) {
                // ── The splash, which stays ─────────────────────────────
                VStack(spacing: 14) {
                    Text("CHRONICARUM")
                        .font(.system(size: cardsIn ? 22 : 30, weight: .bold, design: .serif))
                        .tracking(cardsIn ? 4 : 6)
                        .foregroundStyle(gold)
                        .opacity(wordmarkIn ? 1 : 0)
                        .offset(y: wordmarkIn ? 0 : 12)

                    Rectangle()
                        .fill(gold.opacity(0.7))
                        .frame(width: ruleWidth, height: 1)

                    Text(cardsIn ? "What kind of day?" : "The best of history, mapped")
                        .font(.system(size: cardsIn ? 15 : 12,
                                      weight: cardsIn ? .medium : .regular, design: .serif))
                        .tracking(cardsIn ? 0.5 : 1.5)
                        .foregroundStyle(.white.opacity(cardsIn ? 0.9 : 0.55))
                        .opacity(ruleWidth > 0 ? 1 : 0)
                }
                .padding(.top, cardsIn ? 24 : 0)
                .frame(maxHeight: cardsIn ? nil : .infinity)

                if cardsIn {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(Array(DayIntent.all.enumerated()), id: \.element.id) { index, option in
                                Button { chosen = option } label: {
                                    IntentCard(intent: option)
                                }
                                .buttonStyle(.plain)
                                .transition(.opacity.combined(with: .offset(y: 18)))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 26)
                        .padding(.bottom, 12)

                        Button(action: onSkip) {
                            Text("Just show me the map")
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        .padding(.bottom, 28)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            withAnimation(.easeOut(duration: 0.7)) { wordmarkIn = true }
            withAnimation(.easeInOut(duration: 0.6).delay(0.35)) { ruleWidth = 180 }
            // The splash's own beat, then it becomes the menu rather than handing over.
            try? await Task.sleep(nanoseconds: 1_300_000_000)
            withAnimation(.spring(response: 0.65, dampingFraction: 0.85)) { cardsIn = true }
        }
        .fullScreenCover(item: $chosen) { intent in
            TripPlanView(origin: origin,
                         themes: intent.themes,
                         placeName: siteVM.nearestPlaceName(to: origin),
                         initialDays: 1,
                         initialMode: intent.mode,
                         tier: intent.tier,
                         types: intent.types,
                         intentCaveat: intent.caveat,
                         stepTarget: intent.stepTarget)
        }
    }
}

/// One bright card. Colour does the work the icons and titles cannot: six of these should
/// be scannable in a glance, and six grey rows never were.
private struct IntentCard: View {
    let intent: DayIntent

    private var colour: Color { Color(hex: intent.colour) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: intent.icon)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.white)

            Spacer(minLength: 0)

            Text(intent.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Text(intent.blurb)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
        .background(
            LinearGradient(colors: [colour, colour.opacity(0.72)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: colour.opacity(0.35), radius: 10, y: 5)
    }
}
