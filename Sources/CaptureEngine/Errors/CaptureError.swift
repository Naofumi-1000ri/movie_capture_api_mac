import Foundation

/// CaptureEngine固有のエラー型
public enum CaptureError: Error, Sendable, Equatable, LocalizedError {
    case screenCaptureNotAuthorized
    case microphoneNotAuthorized
    case noDisplayFound
    case windowNotFound(String)
    case alreadyRecording
    case notRecording
    case invalidConfiguration([String])
    case outputDirectoryNotWritable(String)
    case recordingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .screenCaptureNotAuthorized:
            return "画面収録の権限がありません。システム設定 > プライバシーとセキュリティ > 画面収録 で許可してください。"
        case .microphoneNotAuthorized:
            return "マイクの権限がありません。システム設定 > プライバシーとセキュリティ > マイク で許可してください。"
        case .noDisplayFound:
            return "ディスプレイが見つかりません。"
        case .windowNotFound(let name):
            return "ウィンドウが見つかりません: \(name)"
        case .alreadyRecording:
            return "既に録画中です。"
        case .notRecording:
            return "録画中ではありません。"
        case .invalidConfiguration(let errors):
            return "設定が無効です: \(errors.joined(separator: ", "))"
        case .outputDirectoryNotWritable(let path):
            return "出力ディレクトリに書き込めません: \(path)"
        case .recordingFailed(let reason):
            return "録画に失敗しました: \(reason)"
        }
    }
}
