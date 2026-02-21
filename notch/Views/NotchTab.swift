import SwiftUI

enum NotchTab: String, CaseIterable {
    case todo = "待办"
    case clipboard = "剪切板"
    case fileDrop = "暂存"
    case music = "音乐"
    case status = "状态"

    var icon: String {
        switch self {
        case .todo: return "checkmark.square"
        case .status: return "gauge"
        case .music: return "music.note"
        case .clipboard: return "doc.on.clipboard"
        case .fileDrop: return "tray.and.arrow.down"
        }
    }
}
