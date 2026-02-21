import Foundation
import Observation

enum ClipboardRetentionDays: String, CaseIterable, Codable, Identifiable {
    case d3 = "3"
    case d7 = "7"
    case d15 = "15"
    case d30 = "30"
    case infinite = "infinite"

    var id: String { rawValue }

    var days: Int? {
        switch self {
        case .d3: return 3
        case .d7: return 7
        case .d15: return 15
        case .d30: return 30
        case .infinite: return nil
        }
    }

    var title: String {
        switch self {
        case .d3: return "3天"
        case .d7: return "7天"
        case .d15: return "15天"
        case .d30: return "30天"
        case .infinite: return "无限"
        }
    }
}

@Observable
final class AppSettings {
    private static let clipboardRetentionKey = "notch.settings.clipboardRetentionDays"

    var clipboardRetentionDays: ClipboardRetentionDays {
        didSet {
            guard oldValue != clipboardRetentionDays else { return }
            userDefaults.set(clipboardRetentionDays.rawValue, forKey: Self.clipboardRetentionKey)
            onClipboardRetentionChanged?()
        }
    }

    var onClipboardRetentionChanged: (() -> Void)?

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let rawValue = userDefaults.string(forKey: Self.clipboardRetentionKey),
           let stored = ClipboardRetentionDays(rawValue: rawValue) {
            clipboardRetentionDays = stored
        } else {
            clipboardRetentionDays = .d7
        }
    }
}
