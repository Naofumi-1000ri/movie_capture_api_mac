import CoreGraphics

/// ウィンドウ情報（ScreenCaptureKitに依存しない自前の型）
public struct WindowInfo: Sendable, Identifiable, Equatable {
    public let id: CGWindowID
    public let title: String?
    public let ownerName: String?
    public let frame: CGRect
    public let isOnScreen: Bool

    /// タイトルバーを除いたコンテンツ領域の矩形
    /// macOSの標準タイトルバー高さ（28pt）で計算
    public var contentRect: CGRect {
        contentRect(titleBarHeight: WindowInfo.defaultTitleBarHeight)
    }

    /// 指定したタイトルバー高さでコンテンツ領域を計算
    public func contentRect(titleBarHeight: CGFloat) -> CGRect {
        let clampedHeight = min(titleBarHeight, frame.height)
        return CGRect(
            x: 0,
            y: 0,
            width: frame.width,
            height: frame.height - clampedHeight
        )
    }

    public static let defaultTitleBarHeight: CGFloat = 28

    public init(
        id: CGWindowID,
        title: String?,
        ownerName: String?,
        frame: CGRect,
        isOnScreen: Bool
    ) {
        self.id = id
        self.title = title
        self.ownerName = ownerName
        self.frame = frame
        self.isOnScreen = isOnScreen
    }
}
