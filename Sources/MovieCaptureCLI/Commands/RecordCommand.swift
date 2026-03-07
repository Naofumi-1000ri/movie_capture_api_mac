import ArgumentParser
import CaptureEngine
import Dispatch
import Foundation

struct RecordCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "record",
        abstract: "画面を録画",
        discussion: """
        指定したソース（ディスプレイ、ウィンドウ、アプリ）を録画します。
        ソースを指定しない場合はメインディスプレイを録画します。

        録画の停止方法:
          - --duration で秒数を指定（自動停止）
          - Ctrl+C で手動停止
          - 別ターミナルから moviecapture stop で停止
          - --duration 指定中でも Ctrl+C / moviecapture stop で早期停止可能

        例:
          moviecapture record --duration 10             # メインディスプレイを10秒録画
          moviecapture record --app Chrome --duration 5  # Chrome を5秒録画
          moviecapture record --window-id 12345          # ウィンドウIDで指定して録画
          moviecapture record --app Safari --json        # JSON 形式で結果を出力
        """
    )

    @Option(name: .long, help: "ディスプレイIDを指定して録画")
    var display: UInt32?

    @Option(name: .long, help: "ウィンドウIDを指定して録画")
    var windowId: UInt32?

    @Option(name: .long, help: "ウィンドウタイトルで検索して録画")
    var window: String?

    @Option(name: .long, help: "アプリ名で検索して録画（最前面のウィンドウを使用）")
    var app: String?

    @Flag(name: .long, help: "ウィンドウのコンテンツ領域のみキャプチャ（タイトルバー除外）")
    var contentOnly: Bool = false

    @Option(name: .shortAndLong, help: "出力ファイルパス")
    var output: String?

    @Option(name: .long, help: "録画時間（秒）。指定しない場合はCtrl+Cまたは moviecapture stop で停止")
    var duration: Int?

    @Option(name: .long, help: "フレームレート (1-120)")
    var fps: Int?

    @Option(name: .long, help: "コーデック (h264, h265)")
    var codec: String?

    @Option(name: .long, help: "フォーマット (mov, mp4)")
    var format: String?

    @Option(name: .long, help: "設定ファイルパス")
    var config: String?

    @Flag(name: .long, help: "JSON 形式で結果を出力")
    var json: Bool = false

    mutating func run() async throws {
        try validateArguments()

        // 設定の読み込み
        var configuration = try loadConfiguration()

        // CLIオプションで上書き
        if let fps = fps { configuration.frameRate = fps }
        if let codec {
            guard let vc = VideoCodec(rawValue: codec) else {
                throw ValidationError("無効な codec です: \(codec)。h264 または h265 を指定してください。")
            }
            configuration.videoCodec = vc
        }
        if let format {
            guard let ff = FileFormat(rawValue: format) else {
                throw ValidationError("無効な format です: \(format)。mov または mp4 を指定してください。")
            }
            configuration.fileFormat = ff
        }
        if let output = output {
            let url = URL(fileURLWithPath: output)
            configuration.outputDirectory = url.deletingLastPathComponent().path
            configuration.fileName = url.deletingPathExtension().lastPathComponent
            if !url.pathExtension.isEmpty {
                guard let ext = FileFormat(rawValue: url.pathExtension) else {
                    throw ValidationError("出力ファイル拡張子は mov または mp4 を指定してください: \(url.pathExtension)")
                }
                configuration.fileFormat = ext
            }
        }
        configuration.assignGeneratedFileNameIfNeeded()
        let outputURL = configuration.outputFileURL()

        // バリデーション
        let errors = configuration.validate()
        guard errors.isEmpty else {
            throw CaptureError.invalidConfiguration(errors)
        }

        // ソースの決定
        let captureManager = ScreenCaptureManager()
        let sources = try await captureManager.availableSources()
        let source = try resolveSource(from: sources)
        let sourceName = describeSource(source)

        // PID・状態ファイルの書き込み
        let startTime = Date()
        try ProcessState.writePID()
        try ProcessState.writeState(ProcessState.StateInfo(
            pid: ProcessInfo.processInfo.processIdentifier,
            status: "recording",
            source: sourceName,
            startTime: startTime,
            outputPath: outputURL.path
        ))

        // 録画
        let recorder = RecordingManager(screenCaptureProvider: captureManager)
        let stopMonitor = StopEventMonitor()
        defer { stopMonitor.cancel() }
        if !json {
            print("録画を開始します... -> \(outputURL.path)")
        }

        do {
            try await recorder.startRecording(source: source, configuration: configuration)
            if let duration {
                stopMonitor.scheduleAutoStop(after: duration)
            }

            if !json {
                if let duration {
                    print("録画中... (\(duration)秒後に自動停止。Ctrl+C / moviecapture stop で早期停止可能)")
                } else {
                    print("録画中... (Ctrl+C または moviecapture stop で停止)")
                }
            }

            let stopReason = await stopMonitor.wait()
            try? ProcessState.writeState(ProcessState.StateInfo(
                pid: ProcessInfo.processInfo.processIdentifier,
                status: "stopping",
                source: sourceName,
                startTime: startTime,
                outputPath: outputURL.path
            ))
            if !json, case .interrupt = stopReason {
                print("停止シグナルを受信しました。録画を終了します...")
            }

            let url = try await recorder.stopRecording()
            let elapsed = Date().timeIntervalSince(startTime)

            // クリーンアップ
            ProcessState.cleanup()

            if json {
                try printJSON(
                    status: "completed",
                    file: url.path,
                    duration: elapsed,
                    source: sourceName,
                    stopReason: stopReason.jsonValue
                )
            } else {
                print("録画完了: \(url.path)")
            }
        } catch {
            ProcessState.cleanup()
            if json {
                let elapsed = Date().timeIntervalSince(startTime)
                try printJSON(
                    status: "error",
                    file: nil,
                    duration: elapsed,
                    source: sourceName,
                    stopReason: nil,
                    error: error.localizedDescription
                )
            }
            throw error
        }
    }

    // MARK: - JSON 出力

    private func printJSON(
        status: String,
        file: String?,
        duration: Double,
        source: String,
        stopReason: String?,
        error: String? = nil
    ) throws {
        var dict: [String: Any] = [
            "status": status,
            "duration": (duration * 100).rounded() / 100,
            "source": source,
        ]
        if let file = file { dict["file"] = file }
        if let stopReason = stopReason { dict["stopReason"] = stopReason }
        if let error = error { dict["error"] = error }
        let data = try JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys])
        print(String(data: data, encoding: .utf8)!)
    }

    // MARK: - ソース名の記述

    private func describeSource(_ source: CaptureSource) -> String {
        switch source {
        case .display(let info):
            return "Display \(info.id)"
        case .window(let info), .windowContentOnly(let info):
            return info.ownerName ?? info.title ?? "Window \(info.id)"
        case .area(let display, _):
            return "Display \(display.id) (area)"
        }
    }

    // MARK: - 既存メソッド

    private func loadConfiguration() throws -> RecordingConfiguration {
        if let configPath = config {
            let url = URL(fileURLWithPath: configPath)
            return try RecordingConfiguration.load(from: url)
        }
        // デフォルト設定ファイルを探す
        let defaultPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".moviecapture.yaml")
        if FileManager.default.fileExists(atPath: defaultPath.path) {
            return try RecordingConfiguration.load(from: defaultPath)
        }
        return RecordingConfiguration()
    }

    func validateArguments() throws {
        let sourceSelectorCount = [
            display != nil,
            windowId != nil,
            window != nil,
            app != nil,
        ].filter { $0 }.count

        if sourceSelectorCount > 1 {
            throw ValidationError("録画対象は --display / --window-id / --window / --app のいずれか1つだけ指定してください。")
        }

        if contentOnly, windowId == nil, window == nil, app == nil {
            throw ValidationError("--content-only は --window-id / --window / --app のいずれかと組み合わせてください。")
        }

        if let duration, duration <= 0 {
            throw ValidationError("--duration は 1 以上の整数を指定してください。")
        }
    }

    private func resolveSource(from sources: AvailableSources) throws -> CaptureSource {
        // ウィンドウID指定
        if let wid = windowId {
            guard let win = sources.windows.first(where: { $0.id == wid }) else {
                throw CaptureError.windowNotFound("ID: \(wid)")
            }
            return contentOnly ? .windowContentOnly(win) : .window(win)
        }

        // ウィンドウタイトル検索
        if let title = window {
            let matches = sources.windows(titled: title).filter(\.isOnScreen)
            guard let win = matches.first else {
                throw CaptureError.windowNotFound(title)
            }
            return contentOnly ? .windowContentOnly(win) : .window(win)
        }

        // アプリ名検索
        if let appName = app {
            let matches = sources.windows(ownedBy: appName).filter(\.isOnScreen)
            guard let win = matches.first else {
                throw CaptureError.windowNotFound(appName)
            }
            return contentOnly ? .windowContentOnly(win) : .window(win)
        }

        // ディスプレイ指定
        if let did = display {
            guard let disp = sources.displays.first(where: { $0.id == did }) else {
                throw CaptureError.noDisplayFound
            }
            return .display(disp)
        }

        // デフォルト: メインディスプレイ
        guard let mainDisplay = sources.displays.first else {
            throw CaptureError.noDisplayFound
        }
        return .display(mainDisplay)
    }
}

private enum StopReason {
    case interrupt
    case durationElapsed(Int)

    var jsonValue: String {
        switch self {
        case .interrupt:
            return "interrupt"
        case .durationElapsed:
            return "duration"
        }
    }
}

private final class StopEventMonitor: @unchecked Sendable {
    private let lock = NSLock()
    private let queue = DispatchQueue(label: "moviecapture.stop-event-monitor")

    private var continuation: CheckedContinuation<StopReason, Never>?
    private var pendingEvent: StopReason?
    private var closed = false
    private var signalSource: DispatchSourceSignal?
    private var timerSource: DispatchSourceTimer?

    init() {
        signal(SIGINT, SIG_IGN)

        let signalSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: queue)
        signalSource.setEventHandler { [weak self] in
            self?.finish(with: .interrupt)
        }
        self.signalSource = signalSource
        signalSource.resume()
    }

    func scheduleAutoStop(after duration: Int) {
        lock.withLock {
            guard !closed, timerSource == nil else { return }
            let timerSource = DispatchSource.makeTimerSource(queue: queue)
            timerSource.schedule(deadline: .now() + .seconds(duration))
            timerSource.setEventHandler { [weak self] in
                self?.finish(with: .durationElapsed(duration))
            }
            self.timerSource = timerSource
            timerSource.resume()
        }
    }

    func wait() async -> StopReason {
        await withCheckedContinuation { continuation in
            var eventToResume: StopReason?

            lock.withLock {
                if let pendingEvent {
                    eventToResume = pendingEvent
                    self.pendingEvent = nil
                    closed = true
                } else {
                    self.continuation = continuation
                }
            }

            if let eventToResume {
                continuation.resume(returning: eventToResume)
            }
        }
    }

    func cancel() {
        lock.withLock {
            guard !closed else { return }
            closed = true
            cleanupSourcesLocked()
        }
    }

    private func finish(with event: StopReason) {
        var continuationToResume: CheckedContinuation<StopReason, Never>?

        lock.withLock {
            guard !closed else { return }
            closed = true
            cleanupSourcesLocked()

            if let continuation {
                continuationToResume = continuation
                self.continuation = nil
            } else {
                pendingEvent = event
            }
        }

        continuationToResume?.resume(returning: event)
    }

    private func cleanupSourcesLocked() {
        signalSource?.cancel()
        signalSource = nil
        timerSource?.cancel()
        timerSource = nil
        signal(SIGINT, SIG_DFL)
    }
}
