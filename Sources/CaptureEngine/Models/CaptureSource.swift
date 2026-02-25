import CoreGraphics

/// キャプチャ対象の種別
public enum CaptureSource: Sendable, Equatable {
    /// ディスプレイ全体
    case display(DisplayInfo)
    /// 特定のウィンドウ（タイトルバー含む）
    case window(WindowInfo)
    /// 特定のウィンドウのコンテンツ領域のみ（タイトルバー除外）
    case windowContentOnly(WindowInfo)
    /// ディスプレイ上の指定矩形領域
    case area(display: DisplayInfo, rect: CGRect)
}
