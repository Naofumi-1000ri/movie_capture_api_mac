/// ScreenCaptureKitへの依存を抽象化するプロトコル
/// テスト時にモックに差し替え可能
public protocol ScreenCaptureProviding: Sendable {
    /// 利用可能なキャプチャソースを取得
    func availableSources() async throws -> AvailableSources

    /// 指定ソースの静止画をPNGで取得
    func captureStillImage(source: CaptureSource, maxDimension: Int?) async throws -> CapturedStillImage
}
