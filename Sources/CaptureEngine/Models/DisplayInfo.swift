import CoreGraphics

/// ディスプレイ情報（ScreenCaptureKitに依存しない自前の型）
public struct DisplayInfo: Sendable, Identifiable, Equatable {
    public let id: CGDirectDisplayID
    public let width: Int
    public let height: Int
    public let frame: CGRect

    public init(id: CGDirectDisplayID, width: Int, height: Int, frame: CGRect) {
        self.id = id
        self.width = width
        self.height = height
        self.frame = frame
    }
}
