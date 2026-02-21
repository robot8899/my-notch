# my-notch

一个基于 `SwiftUI + AppKit` 的 macOS 刘海区增强工具。  
应用常驻菜单栏后台（`LSUIElement`），将待办、剪贴板、音乐、天气和文件暂存整合在刘海交互区中。

## 功能

- `待办`：支持本地待办，并可同步系统提醒事项（Reminders）。
- `剪切板`：监听文本 / URL / 图片，支持按保留天数自动清理。
- `暂存文件`：将文件拖拽到刘海区域即可暂存，支持清空和 AirDrop。
- `音乐`：展示当前播放信息与封面。
- `状态`：天气快捷入口、设置入口、退出应用。

## 交互说明

- 鼠标悬停刘海区域会展开面板。
- 在展开面板中可左右滑动切换标签页。
- 从 Finder 拖拽文件到刘海区域，会进入“释放以暂存”状态并加入暂存列表。

## 开发环境

- macOS `15.2+`（工程部署目标）
- Xcode（建议使用最新稳定版）
- Swift `5`

## 运行方式

1. 打开 `notch.xcodeproj`
2. 选择 scheme：`notch`
3. 直接 `Run`（`Cmd + R`）

## 权限

首次运行可能会请求以下权限：

- 定位权限：用于获取天气（当前城市）。
- 提醒事项权限：用于同步待办与系统 Reminders。

## 数据存储

- `UserDefaults`：保存待办、剪贴板元数据、天气城市、设置项等。
- `Application Support/notchDrop/ClipboardImages`：剪贴板图片文件。
- `Application Support/notchDrop/FileDrop`：文件暂存内容（默认 24 小时过期清理）。

## 目录结构（简要）

- `notch/Features`：业务模块（Todo / Clipboard / Weather / Music / FileDrop / Settings）
- `notch/Views`：刘海容器与主要界面组件
- `notch/Window`：刘海窗口与屏幕刘海检测逻辑
- `notch/AppDelegate.swift`：应用生命周期与模块装配入口

## License

本项目使用 `Apache License 2.0`，详见 `LICENSE`。
