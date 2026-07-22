import SwiftUI
import CoreLocation

/// The question the app opens with: *what kind of day is this?*
///
/// Everything the planner can do was previously reachable only by knowing where to look —
/// pick themes in Explore, find a toolbar icon, choose days, choose a mode. That is a
/// filter panel wearing a map. This asks one question in plain words and derives the
/// filters from the answer.
///
/// Kept to one screen with no scrolling on a normal phone, because the whole value is that
/// it is faster than the map. Three controls: what sort of day, how long, and how you're
/// getting around — and the last two only ever show a sensible default already chosen.
struct StartView: View {
    @EnvironmentObject private var mapVM: MapViewModel
    @EnvironmentObject private var siteVM: SiteViewModel
    /// Dismisses to the map, for anyone who would rather browse than be asked.
    let onSkip: () -> Void

    @State private var intent: DayIntent?
    @State private var days = 1
    @State private var mode: TravelMode = .driving
    @State private var tier: SignificanceTier = .worthALook
    @State private var showPlan = false

    private var origin: CLLocationCoordinate2D {
        mapVM.userLocation ?? mapVM.visibleRegion.center
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(DayIntent.all) { option in
                        Button {
                            select(option)
                        } label: {
                            IntentRow(intent: option, isSelected: intent?.id == option.id)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("What kind of day?")
                }

                if let intent {
                    Section {
                        Stepper(days == 1 ? "Just today" : "\(days) days",
                                value: $days, in: 1...14)

                        Picker("Getting around", selection: $mode) {
                            ForEach(TravelMode.allCases) { option in
                                Label(option.label, systemImage: option.icon).tag(option)
                            }
                        }

                        Picker("How good?", selection: $tier) {
                            ForEach(SignificanceTier.allCases) { option in
                                Text(option.label).tag(option)
                            }
                        }
                    } header: {
                        Text("And…")
                    } footer: {
                        Text(tier.blurb + (intent.caveat.map { "\n\n" + $0 } ?? ""))
                    }

                    Section {
                        Button {
                            showPlan = true
                        } label: {
                            Text("Plan it")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(hex: "#C9A84C"))
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .navigationTitle("Chronicarum")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Just the map") { onSkip() }
                        .font(.subheadline)
                }
            }
            .sheet(isPresented: $showPlan) {
                if let intent {
                    TripPlanView(origin: origin,
                                 themes: intent.themes,
                                 placeName: siteVM.nearestPlaceName(to: origin),
                                 initialDays: days,
                                 initialMode: mode,
                                 tier: tier,
                                 types: intent.types,
                                 intentCaveat: intent.caveat,
                                 stepTarget: intent.stepTarget)
                }
            }
        }
    }

    /// Choosing a kind of day pre-answers the other two questions, which is the point —
    /// nobody picks "twenty thousand steps" and then wants to be asked whether they have a
    /// car. They stay editable because the guess is sometimes wrong.
    private func select(_ option: DayIntent) {
        withAnimation {
            intent = option
            mode = option.mode
            tier = option.tier
        }
    }
}

private struct IntentRow: View {
    let intent: DayIntent
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: intent.icon)
                .font(.system(size: 20))
                .foregroundColor(isSelected ? Color(hex: "#C9A84C") : .secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(intent.title)
                    .font(.body.weight(isSelected ? .semibold : .regular))
                Text(intent.blurb)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: "#C9A84C"))
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
