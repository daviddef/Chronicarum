import SwiftUI
import CoreLocation

/// The "what kind of day?" cards, presented from the home screen's "Plan a day".
///
/// Once the whole opening screen; now one destination among several, so it is just the
/// grid and the plan it opens. Always dark — the coloured tiles are the app's own palette
/// and were designed against ink, not the system's light grouped background.
struct PlanIntentView: View {
    @EnvironmentObject private var mapVM: MapViewModel
    @EnvironmentObject private var siteVM: SiteViewModel
    @EnvironmentObject private var focus: AppFocus
    @Environment(\.dismiss) private var dismiss

    @State private var chosen: DayIntent?

    private let ink = Color(red: 0x17 / 255, green: 0x15 / 255, blue: 0x12 / 255)
    private let columns = [GridItem(.flexible(), spacing: 14),
                           GridItem(.flexible(), spacing: 14)]

    /// Plan around the searched place if there is one, else where you are, else the map.
    private var origin: CLLocationCoordinate2D {
        focus.coordinate ?? mapVM.userLocation ?? mapVM.visibleRegion.center
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let name = focus.name {
                    Label("Around \(name)", systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                        .foregroundStyle(Color(hex: "#C9A84C"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                }

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(DayIntent.all) { option in
                        Button { chosen = option } label: {
                            IntentCard(intent: option)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
            .background(ink.ignoresSafeArea())
            .navigationTitle("What kind of day?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(item: $chosen) { intent in
            TripPlanView(origin: origin,
                         themes: intent.themes,
                         placeName: focus.name ?? siteVM.nearestPlaceName(to: origin),
                         initialDays: 1,
                         initialMode: intent.mode,
                         tier: intent.tier,
                         types: intent.types,
                         intentCaveat: intent.caveat,
                         stepTarget: intent.stepTarget)
        }
    }
}

/// One bright card. Colour does the work the icons and titles cannot: the cards should be
/// scannable in a glance, and grey rows never were.
struct IntentCard: View {
    let intent: DayIntent

    private var colour: Color { Color(hex: intent.colour) }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: intent.icon)
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(.white)
                .frame(height: 40)

            Text(intent.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(intent.blurb)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14)
        .padding(.vertical, 18)
        .frame(minHeight: 150)
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
