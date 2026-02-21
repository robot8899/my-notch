import SwiftUI

struct SettingsModalView: View {
    private static let modalWidth: CGFloat = 320
    private static let modalHeight: CGFloat = 280

    @Bindable var settings: AppSettings
    var onClose: () -> Void

    @State private var showRetentionOptions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("设置")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("剪切板保存天数")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.65))

                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showRetentionOptions.toggle()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(settings.clipboardRetentionDays.title)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.88))
                            Spacer()
                            Image(systemName: showRetentionOptions ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 7).fill(.white.opacity(0.1)))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if showRetentionOptions {
                        VStack(spacing: 4) {
                            ForEach(ClipboardRetentionDays.allCases) { option in
                                Button {
                                    settings.clipboardRetentionDays = option
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        showRetentionOptions = false
                                    }
                                } label: {
                                    HStack {
                                        Text(option.title)
                                            .font(.system(size: 12))
                                            .foregroundStyle(.white.opacity(0.8))
                                        Spacer()
                                        if settings.clipboardRetentionDays == option {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(.white.opacity(0.8))
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(settings.clipboardRetentionDays == option ? .white.opacity(0.12) : .clear)
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .padding(14)
        .frame(width: Self.modalWidth, height: Self.modalHeight, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.black.opacity(0.95))
        )
    }
}
