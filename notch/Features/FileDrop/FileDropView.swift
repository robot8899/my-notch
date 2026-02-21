import SwiftUI

struct FileDropContentView: View {
    var store: FileDropStore

    var body: some View {
        VStack(spacing: 0) {
            if store.items.isEmpty {
                EmptyStateView(icon: "tray", message: "拖拽文件到刘海区域即可暂存")
            } else {
                HStack {
                    Spacer()
                    Button("清空") {
                        store.clearAll()
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 6)

                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(store.items) { item in
                            FileDropRowView(item: item, store: store)
                        }
                    }
                }
            }
        }
    }
}

struct FileDropRowView: View {
    let item: FileDropItem
    var store: FileDropStore
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            // File icon
            Image(nsImage: store.fileIcon(for: item))
                .resizable()
                .frame(width: 28, height: 28)

            // File info
            VStack(alignment: .leading, spacing: 2) {
                Text(item.originalName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 6) {
                    Text(item.fileSizeString)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.4))

                    Text("·")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.3))

                    Text(item.remainingTimeString)
                        .font(.system(size: 10))
                        .foregroundStyle(item.isExpiringSoon ? .orange.opacity(0.8) : .white.opacity(0.4))
                }
            }

            Spacer()

            // AirDrop button
            Button {
                store.airdrop(item)
            } label: {
                Image(systemName: "airplayaudio")
                    .font(.system(size: 12))
                    .foregroundStyle(.blue.opacity(0.8))
                    .frame(width: 26, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.blue.opacity(0.15))
                    )
            }
            .buttonStyle(.plain)

            // Delete button (visible on hover)
            if isHovering {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        store.removeItem(item)
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(.red.opacity(0.7))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? .white.opacity(0.08) : .clear)
        )
        .onHover { isHovering = $0 }
        .onDrag {
            NSItemProvider(object: item.storedURL as NSURL)
        }
    }
}
