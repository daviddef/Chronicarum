import SwiftUI

/// Map pin for a heritage site. Scales up when selected.
struct SiteMarkerView: View {
    let site: Site
    let isSelected: Bool

    private var markerColor: Color {
        Color(hex: site.era.color)
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(markerColor)
                    .frame(width: isSelected ? 38 : 28, height: isSelected ? 38 : 28)
                    .shadow(color: markerColor.opacity(0.5), radius: isSelected ? 8 : 4)

                Text(site.markerGlyph)
                    .font(.system(size: isSelected ? 18 : 13))
            }

            // Tier dots
            if site.tier >= 4 {
                HStack(spacing: 2) {
                    ForEach(0..<site.tier, id: \.self) { _ in
                        Circle()
                            .fill(Color.white)
                            .frame(width: 3, height: 3)
                    }
                }
                .padding(.top, 2)
            }

            // Callout label when selected
            if isSelected {
                Text(site.name)
                    .font(.caption2.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(markerColor)
                    .cornerRadius(6)
                    .fixedSize()
                    .padding(.top, 4)
            }
        }
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Cluster bubble

/// Shown in place of individual markers when several sites merge at the current zoom.
/// Tapping it zooms in to break the group apart.
struct ClusterMarkerView: View {
    let cluster: SiteCluster

    private var color: Color { Color(hex: cluster.representative.era.color) }

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 34, height: 34)
                .overlay(Circle().stroke(.white, lineWidth: 2))
                .shadow(color: color.opacity(0.5), radius: 4)

            Text("\(cluster.count)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Color hex extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >>  8) & 0xFF) / 255
        let b = Double( int        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
