import SwiftUI

/// Bottom bar that appears when conquest mode is on.
/// Shows the current time period, empire chips, play controls, and name change ticker.
struct ConquestTimelineBar: View {
    @EnvironmentObject private var mapVM: MapViewModel

    private var state: TimelineState { mapVM.timelineState }
    private var period: TimelinePeriod? { state.currentPeriod }

    var body: some View {
        VStack(spacing: 0) {
            // Name changes strip
            if let period = period, !period.nameChanges.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(period.nameChanges) { change in
                            NameChangeChip(change: change)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .frame(height: 28)
                .background(Color(hex: "#C9A84C").opacity(0.15))
            }

            // Main bar
            VStack(spacing: 8) {
                // Year + subtitle
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(period?.label ?? "")
                            .font(.title2.bold())
                            .foregroundColor(Color(hex: "#C9A84C"))
                        Text(period?.subtitle ?? "")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()

                    // Play / Pause
                    Button {
                        mapVM.playTimeline()
                    } label: {
                        Image(systemName: state.isAnimating ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .foregroundColor(Color(hex: "#C9A84C"))
                    }
                }

                // Period scrubber
                Slider(
                    value: Binding(
                        get: { Double(state.periodIndex) },
                        set: { mapVM.timelineState.periodIndex = Int($0) }
                    ),
                    in: 0...Double(max(TimelineData.periods.count - 1, 1)),
                    step: 1
                )
                .tint(Color(hex: "#C9A84C"))

                // Tick labels
                HStack(spacing: 0) {
                    ForEach(Array(TimelineData.periods.enumerated()), id: \.offset) { idx, p in
                        Text(p.label)
                            .font(.system(size: 9, weight: idx == state.periodIndex ? .bold : .regular))
                            .foregroundColor(idx == state.periodIndex ? Color(hex: "#C9A84C") : .secondary)
                            .frame(maxWidth: .infinity)
                            .onTapGesture { mapVM.timelineState.periodIndex = idx }
                    }
                }

                // Empire chips
                if let period = period {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(period.empires) { empire in
                                EmpireChip(empire: empire)
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial)
        }
    }
}

struct EmpireChip: View {
    let empire: Empire

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color(hex: empire.color))
                .frame(width: 8, height: 8)
            Text(empire.name)
                .font(.caption2)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(hex: empire.color).opacity(0.12), in: Capsule())
    }
}

struct NameChangeChip: View {
    let change: NameChange

    var body: some View {
        HStack(spacing: 4) {
            Text(change.oldName)
                .strikethrough(true, color: .secondary)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Image(systemName: "arrow.right")
                .font(.system(size: 8))
                .foregroundColor(Color(hex: "#C9A84C"))
            Text(change.newName)
                .font(.system(size: 10, weight: .semibold))
            Text("(\(change.year > 0 ? "\(change.year) AD" : "\(abs(change.year)) BC"))")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }
}
