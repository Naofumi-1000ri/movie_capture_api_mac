import ArgumentParser
import CaptureEngine

struct ListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "利用可能なキャプチャソースを一覧表示"
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

        if sourceType == .displays || sourceType == .all {
            printDisplays(sources.displays)
        }

        if sourceType == .windows || sourceType == .all {
            var windows = onScreenOnly ? sources.onScreenWindows : sources.windows
            if let appFilter = app {
                windows = sources.windows(ownedBy: appFilter)
                if onScreenOnly {
                    windows = windows.filter(\.isOnScreen)
                }
            }
            printWindows(windows)
        }
    }

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
