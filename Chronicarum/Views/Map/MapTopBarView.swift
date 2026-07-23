import SwiftUI

struct MapTopBarView: View {
    @Binding var showFilters: Bool
    @Binding var showHelp: Bool
    @EnvironmentObject private var mapVM: MapViewModel

    var body: some View {
        HStack(spacing: 18) {
            // App wordmark
            Text("CHRONICARUM")
                .font(.system(size: 15, weight: .bold, design: .serif))
                .foregroundColor(Color(hex: "#C9A84C"))
                .tracking(3)

            Spacer()

            // Re-open the walkthrough
            Button {
                showHelp = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
            }
            .accessibilityLabel("How to use Chronicarum")

            // Filter toggle
            Button {
                showFilters = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }
}
