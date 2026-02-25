import Foundation

/// 録画の状態
public enum RecordingState: Sendable, Equatable {
    case idle
    case preparing
    case recording(startTime: Date)
    case paused(elapsed: TimeInterval)
    case stopping
    case completed(fileURL: URL)
    case failed(String)

    public var isActive: Bool {
        switch self {
        case .recording, .paused, .preparing, .stopping:
            return true
        case .idle, .completed, .failed:
            return false
        }
    }

    public var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }

    public var isPaused: Bool {
        if case .paused = self { return true }
        return false
    }
}
