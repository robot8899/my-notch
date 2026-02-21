import SwiftUI

struct WeatherIconView: View {
    var weatherService: WeatherService

    var body: some View {
        VStack(spacing: 1) {
            Image(systemName: weatherService.sfSymbolName)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.85))
                .symbolRenderingMode(.hierarchical)

            if let temp = weatherService.temperature {
                Text("\(temp)°")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            } else {
                Text("--°")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .frame(width: 28, height: 24)
    }
}
