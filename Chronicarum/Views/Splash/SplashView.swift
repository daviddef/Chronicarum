import SwiftUI

/// The animated launch splash.
///
/// Its background is the same dark tone as the static launch screen
/// (`LaunchBackground`), so the cold-start image dissolves straight into this with no
/// seam. The wordmark eases up and in, a hairline rule draws under it, then the whole
/// thing hands off to the app. Kept brief — a splash people wait through twice stops being
/// a nice touch.
struct SplashView: View {
    /// Called once the intro has played, so the root can reveal the app.
    let onFinished: () -> Void

    @State private var wordmarkIn = false
    @State private var ruleWidth: CGFloat = 0
    @State private var taglineIn = false

    private let gold = Color(hex: "#C9A84C")
    private let ink = Color(red: 0x17 / 255, green: 0x15 / 255, blue: 0x12 / 255)

    var body: some View {
        ZStack {
            ink.ignoresSafeArea()

            // A faint compass-rose motif behind the wordmark — present but never loud.
            Image(systemName: "safari")
                .font(.system(size: 240, weight: .ultraLight))
                .foregroundStyle(gold.opacity(0.06))
                .scaleEffect(wordmarkIn ? 1 : 0.85)

            VStack(spacing: 16) {
                Text("CHRONICARUM")
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .tracking(6)
                    .foregroundStyle(gold)
                    .opacity(wordmarkIn ? 1 : 0)
                    .offset(y: wordmarkIn ? 0 : 12)

                Rectangle()
                    .fill(gold.opacity(0.7))
                    .frame(width: ruleWidth, height: 1)

                Text("The best of history, mapped")
                    .font(.system(size: 12, weight: .regular, design: .serif))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.55))
                    .opacity(taglineIn ? 1 : 0)
            }
        }
        .task {
            withAnimation(.easeOut(duration: 0.7)) { wordmarkIn = true }
            withAnimation(.easeInOut(duration: 0.6).delay(0.35)) { ruleWidth = 180 }
            withAnimation(.easeOut(duration: 0.5).delay(0.6)) { taglineIn = true }
            // Total on screen ≈ 1.6s, then hand off.
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            onFinished()
        }
    }
}
