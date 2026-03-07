import Foundation

/// 静止画キャプチャ結果
public struct CapturedStillImage: Sendable, Equatable {
    public let pngData: Data
    public let width: Int
    public let height: Int

    public init(pngData: Data, width: Int, height: Int) {
        self.pngData = pngData
        self.width = width
        self.height = height
    }
}
