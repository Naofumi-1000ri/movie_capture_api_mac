import ArgumentParser
import CaptureEngine
import Foundation

struct RecordCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "record",
        abstract: "画面を録画"
    )

    @Option(name: .long, help: "ディスプレイIDを指定して録画")
    var display: UInt32?

    @Option(name: .long, help: "ウィンドウIDを指定して録画")
    var windowId: UInt32?

    @Option(name: .long, help: "ウィンドウタイトルで検索して録画")
    var window: String?

    @Option(name: .long, help: "アプリ名で検索して録画")
    var app: String?

    @Flag(name: .long, help: "ウィンドウのコンテンツ領域のみキャプチャ（タイトルバー除外）")
    var contentOnly: Bool = false

    @Option(name: .shortAndLong, help: "出力ファイルパス")
    var output: String?

    @Option(name: .long, help: "録画時間（秒）。指定しない場合はCtrl+Cで停止")
    var duration: Int?

    @Option(name: .long, help: "フレームレート (1-120)")
    var fps: Int?

    @Option(name: .long, help: "コーデック (h264, h265)")
    var codec: String?

    @Option(name: .long, help: "フォーマット (mov, mp4)")
    var format: String?

    @Option(name: .long, help: "設定ファイルパス")
    var config: String?

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

        // 録画
        let recorder = RecordingManager(screenCaptureProvider: captureManager)
        print("録画を開始します...")

        try await recorder.startRecording(source: source, configuration: configuration)

        if let duration = duration {
            print("録画中... (\(duration)秒)")
            try await Task.sleep(for: .seconds(duration))
        } else {
            print("録画中... (Ctrl+C で停止)")
            await waitForInterrupt()
        }

        let url = try await recorder.stopRecording()
        print("録画完了: \(url.path)")
    }

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
