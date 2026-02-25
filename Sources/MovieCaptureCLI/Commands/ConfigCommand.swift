import ArgumentParser
import CaptureEngine
import Foundation

struct ConfigCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "設定ファイルの管理"
    )

    enum Action: String, ExpressibleByArgument, CaseIterable {
        case show
        case create
        case path
    }

    @Argument(help: "アクション (show, create, path)")
    var action: Action = .show

    @Option(name: .shortAndLong, help: "設定ファイルパス")
    var file: String?

    mutating func run() async throws {
        let configURL = resolveConfigURL()

        switch action {
        case .show:
            try showConfig(configURL)
        case .create:
            try createDefaultConfig(configURL)
        case .path:
            print(configURL.path)
        }
    }

    private func resolveConfigURL() -> URL {
        if let file = file {
            return URL(fileURLWithPath: file)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".moviecapture.yaml")
    }

    private func showConfig(_ url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            let config = try RecordingConfiguration.load(from: url)
            print("設定ファイル: \(url.path)")
            print("---")
            print("frameRate: \(config.frameRate)")
            print("videoCodec: \(config.videoCodec.rawValue)")
            print("fileFormat: \(config.fileFormat.rawValue)")
            print("quality: \(config.quality.rawValue)")
            print("captureSystemAudio: \(config.captureSystemAudio)")
            print("captureMicrophone: \(config.captureMicrophone)")
            print("outputDirectory: \(config.outputDirectory)")
            if let tbh = config.titleBarHeight {
                print("titleBarHeight: \(tbh)")
            }
        } else {
            print("設定ファイルが見つかりません: \(url.path)")
            print("'moviecapture config create' で作成できます。")
        }
    }

    private func createDefaultConfig(_ url: URL) throws {
        let config = RecordingConfiguration()
        try config.save(to: url)
        print("デフォルト設定ファイルを作成しました: \(url.path)")
    }
}
