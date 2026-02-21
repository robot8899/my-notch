import SwiftUI

struct StatusView: View {
    var weatherService: WeatherService
    var onOpenSettings: () -> Void

    private enum StatusPage {
        case dashboard
        case weather
    }

    @State private var page: StatusPage = .dashboard

    var body: some View {
        Group {
            switch page {
            case .dashboard:
                dashboardView
            case .weather:
                weatherView
            }
        }
    }

    private var dashboardView: some View {
        HStack(spacing: 10) {
            quickActionButton(systemName: weatherService.sfSymbolName, title: "天气") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    page = .weather
                }
            }

            quickActionButton(systemName: "gearshape", title: "设置") {
                onOpenSettings()
            }

            quickActionButton(systemName: "power", title: "退出") {
                NSApp.terminate(nil)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.leading, 2)
        .padding(.top, 2)
    }

    private var weatherView: some View {
        WeatherView(service: weatherService) {
            withAnimation(.easeInOut(duration: 0.2)) {
                page = .dashboard
            }
        }
    }

    private func quickActionButton(systemName: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .symbolRenderingMode(.hierarchical)
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .frame(width: 66, height: 56)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.white.opacity(0.08))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
