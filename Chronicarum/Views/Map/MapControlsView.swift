import SwiftUI

/// Right-rail floating controls: zoom in/out, reset, locate me, conquest toggle.
struct MapControlsView: View {
    @EnvironmentObject private var mapVM: MapViewModel

    var body: some View {
        VStack(spacing: 8) {
            // Zoom In
            MapControlButton(icon: "plus") {
                withAnimation { mapVM.zoomIn() }
            }

            // Zoom Out
            MapControlButton(icon: "minus") {
                withAnimation { mapVM.zoomOut() }
            }

            // Reset to Mediterranean
            MapControlButton(icon: "arrow.counterclockwise") {
                mapVM.resetToDefaultView()
            }

            Divider().frame(width: 32)

            // Locate Me
            MapControlButton(icon: mapVM.isLocating ? "location.fill" : "location",
                             tint: mapVM.isLocating ? .blue : .primary) {
                mapVM.requestUserLocation()
            }

            Divider().frame(width: 32)

            // Conquest Toggle
            MapControlButton(icon: "shield.lefthalf.filled",
                             tint: mapVM.timelineState.isVisible ? Color(hex: "#C9A84C") : .primary) {
                withAnimation { mapVM.toggleConquest() }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 4)
    }
}

struct MapControlButton: View {
    let icon: String
    var tint: Color = .primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(tint)
                .frame(width: 32, height: 32)
        }
    }
}
