import SwiftUI

struct ClipboardView: View {
    var monitor: ClipboardMonitor
    @State private var searchQuery = ""
    @State private var showSearchField = false

    private var normalizedQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var filteredItems: [ClipboardItem] {
        guard !normalizedQuery.isEmpty else { return monitor.items }
        return monitor.items.filter { item in
            switch item.type {
            case .image:
                let keywords = ["图片", "image", "photo", "照片"]
                return keywords.contains { $0.hasPrefix(normalizedQuery) || normalizedQuery.contains($0) }
            case .text, .url:
                return item.content.lowercased().contains(normalizedQuery)
            }
        }
    }

    private var isSearching: Bool {
        !normalizedQuery.isEmpty
    }

    var body: some View {
        VStack(spacing: 8) {
            if filteredItems.isEmpty {
                emptyView(message: isSearching ? "没有匹配内容" : "剪切板历史为空")
            } else {
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(filteredItems) { item in
                            ClipboardRowView(item: item) {
                                monitor.copyToClipboard(item)
                            }
                        }
                    }
                }
            }

            bottomBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func emptyView(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 32))
                .foregroundStyle(.white.opacity(0.3))
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxHeight: .infinity)
    }

    private var bottomBar: some View {
        HStack(spacing: 8) {
            if showSearchField {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))

                    TextField("", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.9))
                        .overlay(alignment: .leading) {
                            if searchQuery.isEmpty {
                                Text("搜索剪切板...")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.4))
                                    .allowsHitTesting(false)
                            }
                        }

                    Button {
                        searchQuery = ""
                        showSearchField = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.1)))
            } else {
                Text(isSearching ? "匹配 \(filteredItems.count) / \(monitor.items.count) 条" : "\(monitor.items.count) 条记录")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))

                Spacer()

                Button {
                    showSearchField = true
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct ClipboardRowView: View {
    let item: ClipboardItem
    var onCopy: () -> Void

    @State private var isHovering = false
    @State private var showCopied = false

    var body: some View {
        Button(action: {
            onCopy()
            showCopied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                showCopied = false
            }
        }) {
            HStack(spacing: 8) {
                icon

                if item.type == .image {
                    imageContent
                } else {
                    textContent
                }

                Spacer()

                statusLabel
            }
            .padding(.horizontal, 8)
            .padding(.vertical, item.type == .image ? 4 : 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovering ? .white.opacity(0.1) : .white.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }

    private var icon: some View {
        Image(systemName: iconName)
            .font(.system(size: 10))
            .foregroundStyle(.white.opacity(0.4))
    }

    private var iconName: String {
        switch item.type {
        case .url: "link"
        case .image: "photo"
        case .text: "doc.text"
        }
    }

    private var imageContent: some View {
        Group {
            if let data = item.imageData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 40)
                    .cornerRadius(4)
            }
            Text("图片")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private var textContent: some View {
        Text(item.content)
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.8))
            .lineLimit(1)
            .truncationMode(.tail)
    }

    private var statusLabel: some View {
        Group {
            if showCopied {
                Text("已复制")
                    .font(.system(size: 10))
                    .foregroundStyle(.green.opacity(0.8))
            } else {
                Text(timeAgo(item.timestamp))
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "刚刚" }
        if seconds < 3600 { return "\(seconds / 60)分钟前" }
        return "\(seconds / 3600)小时前"
    }
}
