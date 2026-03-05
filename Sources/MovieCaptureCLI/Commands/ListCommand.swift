import ArgumentParser
import CaptureEngine
import Foundation

struct ListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "利用可能なキャプチャソースを一覧表示",
        discussion: """
        ディスプレイとウィンドウの情報を取得します。
        --json フラグを付けると機械可読な JSON 形式で出力します。

        例:
          moviecapture list                      # 全ソースを表示
          moviecapture list displays             # ディスプレイのみ
          moviecapture list windows --app Chrome  # Chrome のウィンドウのみ
          moviecapture list --json               # JSON 形式で出力
        """
    )

    enum SourceType: String, ExpressibleByArgument, CaseIterable {
        case displays
        case windows
        case all
    }

    @Argument(help: "表示するソース種別 (displays, windows, all)")
    var sourceType: SourceType = .all

    @Flag(name: .long, help: "オンスクリーンのウィンドウのみ表示")
    var onScreenOnly: Bool = false

    @Option(name: .long, help: "アプリ名でフィルタ")
    var app: String?

    @Flag(name: .long, help: "JSON 形式で出力")
    var json: Bool = false

    mutating func run() async throws {
        let manager = ScreenCaptureManager()
        let sources: AvailableSources
        do {
            sources = try await manager.availableSources()
        } catch {
            if PermissionCheck.handleScreenCaptureError(error) {
                throw ExitCode.failure
            }
            throw error
        }

        let showDisplays = sourceType == .displays || sourceType == .all
        let showWindows = sourceType == .windows || sourceType == .all

        var windows: [WindowInfo] = []
        if showWindows {
            if let appFilter = app {
                windows = sources.windows(ownedBy: appFilter)
                if onScreenOnly {
                    windows = windows.filter(\.isOnScreen)
                }
            } else {
                windows = onScreenOnly ? sources.onScreenWindows : sources.windows
            }
        }

        if json {
            try printJSON(
                displays: showDisplays ? sources.displays : nil,
                windows: showWindows ? windows : nil
            )
        } else {
            if showDisplays {
                printDisplays(sources.displays)
            }
            if showWindows {
                printWindows(windows)
            }
        }
    }

    // MARK: - JSON 出力

    private func printJSON(displays: [DisplayInfo]?, windows: [WindowInfo]?) throws {
        var dict: [String: Any] = [:]
        if let displays = displays {
            dict["displays"] = displays.map { display in
                [
                    "id": Int(display.id),
                    "width": display.width,
                    "height": display.height,
                ] as [String: Any]
            }
        }
        if let windows = windows {
            dict["windows"] = windows.map { window in
                var w: [String: Any] = [
                    "id": Int(window.id),
                    "width": Int(window.frame.width),
                    "height": Int(window.frame.height),
                    "onScreen": window.isOnScreen,
                ]
                if let title = window.title { w["title"] = title }
                if let app = window.ownerName { w["app"] = app }
                return w
            }
        }
        let data = try JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys])
        print(String(data: data, encoding: .utf8)!)
    }

    // MARK: - テキスト出力

    private func printDisplays(_ displays: [DisplayInfo]) {
        print("=== Displays ===")
        for display in displays {
            print("  ID: \(display.id)  \(display.width)x\(display.height)")
        }
        print()
    }

    private func printWindows(_ windows: [WindowInfo]) {
        print("=== Windows ===")
        for window in windows {
            let title = window.title ?? "(untitled)"
            let owner = window.ownerName ?? "(unknown)"
            let onScreen = window.isOnScreen ? "●" : "○"
            print("  \(onScreen) ID: \(window.id)  [\(owner)] \(title)  \(Int(window.frame.width))x\(Int(window.frame.height))")
        }
        print()
    }
}
