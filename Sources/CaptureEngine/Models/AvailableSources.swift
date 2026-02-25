/// 利用可能なキャプチャソースの一覧
public struct AvailableSources: Sendable, Equatable {
    public let displays: [DisplayInfo]
    public let windows: [WindowInfo]

    public init(displays: [DisplayInfo], windows: [WindowInfo]) {
        self.displays = displays
        self.windows = windows
    }

    /// アプリ名でウィンドウをフィルタ
    public func windows(ownedBy appName: String) -> [WindowInfo] {
        windows.filter { $0.ownerName?.localizedCaseInsensitiveContains(appName) == true }
    }

    /// タイトルでウィンドウを検索
    public func windows(titled title: String) -> [WindowInfo] {
        windows.filter { $0.title?.localizedCaseInsensitiveContains(title) == true }
    }

    /// オンスクリーンのウィンドウのみ
    public var onScreenWindows: [WindowInfo] {
        windows.filter(\.isOnScreen)
    }
}
