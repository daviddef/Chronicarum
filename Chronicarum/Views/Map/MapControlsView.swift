import SwiftUI

/// Right-rail floating controls: surprise, map style, zoom, reset, locate, conquest.
struct MapControlsView: View {
    @EnvironmentObject private var mapVM: MapViewModel
    /// Set when "surprise me" picks a site, so the map can open its detail sheet.
    @Binding var surprisedSite: Site?

    var body: some View {
        VStack(spacing: 8) {
            // Surprise me — jump to a random world treasure
            MapControlButton(icon: "die.face.5", tint: Color(hex: "#C9A84C")) {
                withAnimation { surprisedSite = mapVM.surpriseMe() }
            }
            .accessibilityLabel("Surprise me — show a random site")

            // Map style: standard → hybrid → satellite
            MapControlButton(icon: mapVM.styleMode.icon,
                             tint: mapVM.styleMode == .standard ? .primary : Color(hex: "#C9A84C")) {
                withAnimation { mapVM.cycleMapStyle() }
            }
            .accessibilityLabel("Map style: \(mapVM.styleMode.label)")

            Divider().frame(width: 32)

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
