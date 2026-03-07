import AVFoundation
import Foundation
import ScreenCaptureKit

/// 録画セッションを管理するメインクラス
public final class RecordingManager: @unchecked Sendable {
    private let screenCaptureProvider: ScreenCaptureProviding
    private let lock = NSLock()

    private var _state: RecordingState = .idle
    public var state: RecordingState {
        lock.withLock { _state }
    }

    private var stream: SCStream?
    private var recordingOutput: SCRecordingOutput?
    private var recordingDelegate: RecordingOutputDelegate?
    private var configuration: RecordingConfiguration?
    private var outputURL: URL?

    public init(screenCaptureProvider: ScreenCaptureProviding = ScreenCaptureManager()) {
        self.screenCaptureProvider = screenCaptureProvider
    }

    // MARK: - State management (internal, testable)

    func setState(_ newState: RecordingState) {
        lock.withLock { _state = newState }
    }

    /// 録画開始前の検証を実行
    func validateBeforeRecording(
        source: CaptureSource,
        configuration: RecordingConfiguration
    ) throws {
        guard !state.isActive else {
            throw CaptureError.alreadyRecording
        }

        let errors = configuration.validate()
        guard errors.isEmpty else {
            throw CaptureError.invalidConfiguration(errors)
        }

        let dir = configuration.resolvedOutputDirectory.path
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: dir, isDirectory: &isDir)
        guard exists && isDir.boolValue else {
            throw CaptureError.outputDirectoryNotWritable(dir)
        }
        guard FileManager.default.isWritableFile(atPath: dir) else {
            throw CaptureError.outputDirectoryNotWritable(dir)
        }
    }

    /// ソースに応じたSCContentFilterを構築
    func buildContentFilter(
        for source: CaptureSource,
        content: SCShareableContent
    ) throws -> SCContentFilter {
        try CaptureSourceSetup.buildContentFilter(for: source, content: content)
    }

    /// ソースと設定からSCStreamConfigurationを構築
    func buildStreamConfiguration(
        for source: CaptureSource,
        configuration: RecordingConfiguration
    ) -> SCStreamConfiguration {
        let streamConfig = SCStreamConfiguration()
        streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(configuration.frameRate))
        streamConfig.showsCursor = true
        streamConfig.capturesAudio = configuration.captureSystemAudio
        CaptureSourceSetup.configureGeometry(
            for: source,
            in: streamConfig,
            titleBarHeight: CGFloat(configuration.titleBarHeight ?? WindowInfo.defaultTitleBarHeight)
        )

        return streamConfig
    }
}

// MARK: - RecordingProviding

extension RecordingManager: RecordingProviding {
    public func startRecording(
        source: CaptureSource,
        configuration: RecordingConfiguration
    ) async throws {
        try validateBeforeRecording(source: source, configuration: configuration)

        setState(.preparing)
        self.configuration = configuration

        // ウィンドウキャプチャにはCGSセッションが必要（CLIで必須）
        await AppInitializer.ensureInitialized()

        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: false
        )

        let filter = try buildContentFilter(for: source, content: content)
        let streamConfig = buildStreamConfiguration(for: source, configuration: configuration)

        let outputURL = configuration.outputFileURL()
        self.outputURL = outputURL

        let recordingConfig = SCRecordingOutputConfiguration()
        recordingConfig.outputURL = outputURL
        switch configuration.videoCodec {
        case .h264:
            recordingConfig.videoCodecType = .h264
        case .h265:
            recordingConfig.videoCodecType = .hevc
        }
        switch configuration.fileFormat {
        case .mov:
            recordingConfig.outputFileType = .mov
        case .mp4:
            recordingConfig.outputFileType = .mp4
        }

        let delegate = RecordingOutputDelegate()
        self.recordingDelegate = delegate
        let recordingOutput = SCRecordingOutput(configuration: recordingConfig, delegate: delegate)
        self.recordingOutput = recordingOutput

        let stream = SCStream(filter: filter, configuration: streamConfig, delegate: nil)
        self.stream = stream

        try stream.addRecordingOutput(recordingOutput)
        try await stream.startCapture()

        setState(.recording(startTime: Date()))
    }

    public func stopRecording() async throws -> URL {
        guard state.isActive else {
            throw CaptureError.notRecording
        }

        setState(.stopping)

        guard let stream = self.stream else {
            throw CaptureError.notRecording
        }

        try await stream.stopCapture()

        guard let outputURL = self.outputURL else {
            throw CaptureError.recordingFailed("Recording output URL not available")
        }

        self.stream = nil
        self.recordingOutput = nil
        self.recordingDelegate = nil
        self.outputURL = nil
        setState(.completed(fileURL: outputURL))

        return outputURL
    }

    public func pauseRecording() async throws {
        guard case .recording(let startTime) = state else {
            throw CaptureError.notRecording
        }

        guard let stream = self.stream else {
            throw CaptureError.notRecording
        }

        try await stream.stopCapture()
        let elapsed = Date().timeIntervalSince(startTime)
        setState(.paused(elapsed: elapsed))
    }

    public func resumeRecording() async throws {
        guard case .paused = state else {
            throw CaptureError.notRecording
        }

        guard let stream = self.stream else {
            throw CaptureError.notRecording
        }

        try await stream.startCapture()
        setState(.recording(startTime: Date()))
    }
}

// MARK: - SCRecordingOutputDelegate

final class RecordingOutputDelegate: NSObject, SCRecordingOutputDelegate, @unchecked Sendable {
    var onStart: (() -> Void)?
    var onFinish: (() -> Void)?
    var onError: ((Error) -> Void)?

    func recordingOutputDidStartRecording(_ recordingOutput: SCRecordingOutput) {
        onStart?()
    }

    func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
        onFinish?()
    }

    func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: Error) {
        onError?(error)
    }
}
