import ScreenCaptureKit

/// ScreenCaptureKit を使用したキャプチャソース管理
public final class ScreenCaptureManager: ScreenCaptureProviding {
    public init() {}

    public func availableSources() async throws -> AvailableSources {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: false
        )

        let displays = content.displays.map { display in
            DisplayInfo(
                id: display.displayID,
                width: display.width,
                height: display.height,
                frame: display.frame
            )
        }

        let windows = content.windows.map { window in
            WindowInfo(
                id: window.windowID,
                title: window.title,
                ownerName: window.owningApplication?.applicationName,
                frame: window.frame,
                isOnScreen: window.isOnScreen
            )
        }

        return AvailableSources(displays: displays, windows: windows)
    }
}
