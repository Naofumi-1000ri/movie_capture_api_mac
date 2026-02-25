import AppKit

/// CLIでもCoreGraphicsセッションを初期化するためのヘルパー
/// desktopIndependentWindowやフルスクリーンウィンドウの録画に必要
public enum AppInitializer {
    nonisolated(unsafe) private static var initialized = false

    @MainActor
    public static func ensureInitialized() {
        guard !initialized else { return }
        initialized = true
        _ = NSApplication.shared
    }
}
