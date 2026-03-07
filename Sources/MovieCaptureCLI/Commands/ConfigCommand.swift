import ArgumentParser
import CaptureEngine
import Foundation

struct ConfigCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "設定ファイルの管理",
        discussion: """
        録画設定ファイル (~/.moviecapture.yaml) の表示・作成を行います。
        --json を付けると機械可読な JSON を返します。
        create は既存ファイルを上書きしません。上書きする場合は --force を付けてください。

        例:
          moviecapture config show --json     # 現在の設定を JSON で表示
          moviecapture config create          # デフォルト設定ファイルを作成
          moviecapture config create --force  # 既存設定を上書き
          moviecapture config path --json     # 設定ファイルのパスを JSON で表示
        """
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

    @Flag(name: .long, help: "JSON 形式で出力")
    var json: Bool = false

    @Flag(name: .long, help: "既存の設定ファイルを上書き")
    var force: Bool = false

    mutating func run() async throws {
        let configURL = resolveConfigURL()

        switch action {
        case .show:
            try showConfig(configURL)
        case .create:
            try createDefaultConfig(configURL)
        case .path:
            try printConfigPath(configURL)
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
            if json {
                try printJSON(ConfigShowResponse(
                    status: "ok",
                    path: url.path,
                    exists: true,
                    config: config,
                    message: nil
                ))
            } else {
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
            }
        } else {
            let message = "設定ファイルが見つかりません。'moviecapture config create' で作成できます。"
            if json {
                try printJSON(ConfigShowResponse(
                    status: "missing",
                    path: url.path,
                    exists: false,
                    config: nil,
                    message: message
                ))
            } else {
                print("設定ファイルが見つかりません: \(url.path)")
                print("'moviecapture config create' で作成できます。")
            }
        }
    }

    private func createDefaultConfig(_ url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path), !force {
            let message = "設定ファイルは既に存在します。上書きする場合は --force を指定してください。"
            if json {
                try printJSON(ConfigActionResponse(
                    status: "error",
                    path: url.path,
                    message: message
                ))
            } else {
                print("設定ファイルは既に存在します: \(url.path)")
                print("--force を付けると上書きできます。")
            }
            throw ExitCode.failure
        }

        let config = RecordingConfiguration()
        try config.save(to: url)
        if json {
            try printJSON(ConfigActionResponse(
                status: "created",
                path: url.path,
                message: "デフォルト設定ファイルを作成しました。"
            ))
        } else {
            print("デフォルト設定ファイルを作成しました: \(url.path)")
        }
    }

    private func printConfigPath(_ url: URL) throws {
        if json {
            try printJSON(ConfigActionResponse(status: "ok", path: url.path, message: nil))
        } else {
            print(url.path)
        }
    }

    private func printJSON<T: Encodable>(_ value: T) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(value)
        print(String(decoding: data, as: UTF8.self))
    }
}

private struct ConfigShowResponse: Encodable {
    let status: String
    let path: String
    let exists: Bool
    let config: RecordingConfiguration?
    let message: String?
}

private struct ConfigActionResponse: Encodable {
    let status: String
    let path: String
    let message: String?
}
