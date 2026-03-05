import ArgumentParser
import CaptureEngine
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
        // 設定の読み込み
        var configuration = try loadConfiguration()

        // CLIオプションで上書き
        if let fps = fps { configuration.frameRate = fps }
        if let codec = codec, let vc = VideoCodec(rawValue: codec) { configuration.videoCodec = vc }
        if let format = format, let ff = FileFormat(rawValue: format) { configuration.fileFormat = ff }
        if let output = output {
            let url = URL(fileURLWithPath: output)
            configuration.outputDirectory = url.deletingLastPathComponent().path
            configuration.fileName = url.deletingPathExtension().lastPathComponent
            if let ext = FileFormat(rawValue: url.pathExtension) {
                configuration.fileFormat = ext
            }
        }

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
            outputPath: nil
        ))

        // 録画
        let recorder = RecordingManager(screenCaptureProvider: captureManager)
        if !json {
            print("録画を開始します...")
        }

        do {
            try await recorder.startRecording(source: source, configuration: configuration)

            if let duration = duration {
                if !json {
                    print("録画中... (\(duration)秒)")
                }
                try await Task.sleep(for: .seconds(duration))
            } else {
                if !json {
                    print("録画中... (Ctrl+C で停止)")
                }
                await waitForInterrupt()
            }

            let url = try await recorder.stopRecording()
            let elapsed = Date().timeIntervalSince(startTime)

            // クリーンアップ
            ProcessState.cleanup()

            if json {
                try printJSON(status: "completed", file: url.path, duration: elapsed, source: sourceName)
            } else {
                print("録画完了: \(url.path)")
            }
        } catch {
            ProcessState.cleanup()
            if json {
                let elapsed = Date().timeIntervalSince(startTime)
                try printJSON(status: "error", file: nil, duration: elapsed, source: sourceName, error: error.localizedDescription)
            }
            throw error
        }
    }

    // MARK: - JSON 出力

    private func printJSON(status: String, file: String?, duration: Double, source: String, error: String? = nil) throws {
        var dict: [String: Any] = [
            "status": status,
            "duration": (duration * 100).rounded() / 100,
            "source": source,
        ]
        if let file = file { dict["file"] = file }
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

    private func waitForInterrupt() async {
        await withCheckedContinuation { continuation in
            signal(SIGINT) { _ in
                // no-op: signal received
            }
            let source = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
            source.setEventHandler {
                source.cancel()
                continuation.resume()
            }
            source.resume()
        }
    }
}
