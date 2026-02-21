import SwiftUI

struct TodoView: View {
    @Bindable var store: TodoStore
    @State private var newTitle = ""
    @State private var isCompletedExpanded = false
    @FocusState private var isInputFocused: Bool

    private var pendingItems: [TodoItem] { store.items.filter { !$0.isCompleted } }
    private var completedItems: [TodoItem] { store.items.filter { $0.isCompleted } }

    private func toggleItem(_ item: TodoItem) {
        let willBeCompleted = !item.isCompleted
        // Avoid animating cross-section data moves to prevent stale row state reuse.
        store.toggle(item)
        if willBeCompleted && !isCompletedExpanded {
            withAnimation(.easeInOut(duration: 0.2)) {
                isCompletedExpanded = true
            }
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            // List
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 4) {
                    ForEach(pendingItems) { item in
                        TodoRowView(item: item) {
                            toggleItem(item)
                        } onDelete: {
                            store.delete(item)
                        }
                        .id("pending-\(item.id.uuidString)")
                    }

                    if !completedItems.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isCompletedExpanded.toggle()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: isCompletedExpanded ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.35))
                                Text("已完成")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.35))
                                Text("\(completedItems.count)")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.25))
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 10)
                        .padding(.top, 6)

                        if isCompletedExpanded {
                            ForEach(completedItems) { item in
                                TodoRowView(item: item) {
                                    toggleItem(item)
                                } onDelete: {
                                    store.delete(item)
                                }
                                .id("completed-\(item.id.uuidString)")
                            }
                        }
                    }
                }
            }

            // Input field
            HStack(spacing: 8) {
                TextField("", text: $newTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                    .focused($isInputFocused)
                    .overlay(alignment: .leading) {
                        if newTitle.isEmpty {
                            Text("添加待办事项...")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.4))
                                .allowsHitTesting(false)
                        }
                    }
                    .onSubmit {
                        store.add(title: newTitle)
                        newTitle = ""
                    }

                Button {
                    store.add(title: newTitle)
                    newTitle = ""
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.1)))
            .onTapGesture {
                // Make the panel key window so TextField can receive keyboard input
                NSApp.keyWindow?.makeKey()
                if let panel = NSApp.windows.first(where: { $0 is NotchPanel }) {
                    panel.makeKey()
                }
                isInputFocused = true
            }
        }
    }
}

struct TodoRowView: View {
    let item: TodoItem
    var onToggle: () -> Void
    var onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onToggle) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(item.isCompleted ? .green : .white.opacity(0.5))
            }
            .buttonStyle(.plain)

            Text(item.title)
                .font(.system(size: 13))
                .foregroundStyle(item.isCompleted ? .white.opacity(0.4) : .white.opacity(0.9))
                .strikethrough(item.isCompleted, color: .white.opacity(0.3))
                .lineLimit(1)

            Spacer()

            if isHovering {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovering ? .white.opacity(0.08) : .clear)
        )
        .onHover { isHovering = $0 }
    }
}
