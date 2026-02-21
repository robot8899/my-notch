import SwiftUI

struct MarqueeText: View {
    let text: String
    @State private var offset: CGFloat = 0
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let needsScroll = textWidth > geo.size.width
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize()
                .background(GeometryReader { textGeo in
                    Color.clear.onAppear {
                        textWidth = textGeo.size.width
                        containerWidth = geo.size.width
                    }
                })
                .offset(x: needsScroll ? offset : 0)
                .onAppear {
                    guard needsScroll else { return }
                    startScrolling()
                }
                .onChange(of: text) {
                    offset = 0
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        if textWidth > containerWidth {
                            startScrolling()
                        }
                    }
                }
        }
        .clipped()
        .frame(height: 14)
    }

    private func startScrolling() {
        let distance = textWidth - containerWidth + 20
        withAnimation(.linear(duration: Double(distance) / 30).delay(1).repeatForever(autoreverses: true)) {
            offset = -distance
        }
    }
}
