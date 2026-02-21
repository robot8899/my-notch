import SwiftUI

struct CalendarIconView: View {
    private static let monthFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "MMM"
        return fmt
    }()

    private var monthString: String {
        Self.monthFormatter.string(from: Date()).uppercased()
    }

    private var dayNumber: String {
        "\(Calendar.current.component(.day, from: Date()))"
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(monthString)
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(.red.opacity(0.8))
            Text(dayNumber)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .offset(y: -1)
        }
        .frame(width: 28, height: 24)
    }
}
