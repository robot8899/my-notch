import SwiftUI

struct AudioBarsView: View {
    let barCount = 4
    let maxHeight: CGFloat = 14
    let barWidth: CGFloat = 2.5
    let spacing: CGFloat = 1.5

    @State private var heights: [CGFloat] = []
    @State private var animationTimer: Timer?

    var body: some View {
        HStack(alignment: .bottom, spacing: spacing) {
            ForEach(0..<barCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(.white.opacity(0.75))
                    .frame(width: barWidth, height: heights.indices.contains(i) ? heights[i] : 3)
            }
        }
        .frame(height: maxHeight, alignment: .bottom)
        .onAppear { startAnimating() }
        .onDisappear {
            animationTimer?.invalidate()
            animationTimer = nil
        }
    }

    private func startAnimating() {
        heights = (0..<barCount).map { _ in CGFloat.random(in: 3...maxHeight) }

        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                heights = (0..<barCount).map { _ in CGFloat.random(in: 3...maxHeight) }
            }
        }
    }
}
