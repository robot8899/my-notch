import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let message: String
    var iconSize: CGFloat = 28

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: iconSize))
                .foregroundStyle(.white.opacity(0.25))
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
