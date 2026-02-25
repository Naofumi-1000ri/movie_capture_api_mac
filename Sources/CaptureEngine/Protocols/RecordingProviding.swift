import Foundation

/// 録画操作を抽象化するプロトコル
/// テスト時にモックに差し替え可能
public protocol RecordingProviding: Sendable {
    /// 録画を開始
    func startRecording(
        source: CaptureSource,
        configuration: RecordingConfiguration
    ) async throws

    /// 録画を停止して出力ファイルURLを返す
    func stopRecording() async throws -> URL

    /// 録画を一時停止
    func pauseRecording() async throws

    /// 録画を再開
    func resumeRecording() async throws
}
