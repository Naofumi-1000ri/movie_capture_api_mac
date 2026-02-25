import Foundation
import Yams

/// 動画コーデック
public enum VideoCodec: String, Codable, Sendable, CaseIterable {
    case h264
    case h265
}

/// 出力ファイルフォーマット
public enum FileFormat: String, Codable, Sendable, CaseIterable {
    case mov
    case mp4
}

/// 録画品質プリセット
public enum Quality: String, Codable, Sendable, CaseIterable {
    case low
    case medium
    case high
    case lossless
}

/// 録画設定
public struct RecordingConfiguration: Codable, Sendable, Equatable {
    public var frameRate: Int
    public var videoCodec: VideoCodec
    public var fileFormat: FileFormat
    public var quality: Quality
    public var captureSystemAudio: Bool
    public var captureMicrophone: Bool
    public var outputDirectory: String
    public var fileName: String?
    public var titleBarHeight: Double?

    public init(
        frameRate: Int = 30,
        videoCodec: VideoCodec = .h265,
        fileFormat: FileFormat = .mov,
        quality: Quality = .high,
        captureSystemAudio: Bool = true,
        captureMicrophone: Bool = false,
        outputDirectory: String = "~/Movies",
        fileName: String? = nil,
        titleBarHeight: Double? = nil
    ) {
        self.frameRate = frameRate
        self.videoCodec = videoCodec
        self.fileFormat = fileFormat
        self.quality = quality
        self.captureSystemAudio = captureSystemAudio
        self.captureMicrophone = captureMicrophone
        self.outputDirectory = outputDirectory
        self.fileName = fileName
        self.titleBarHeight = titleBarHeight
    }

    /// 解決済みの出力ディレクトリURL
    public var resolvedOutputDirectory: URL {
        let expanded = NSString(string: outputDirectory).expandingTildeInPath
        return URL(fileURLWithPath: expanded, isDirectory: true)
    }

    /// 出力ファイルURLを生成
    public func outputFileURL(baseName: String? = nil) -> URL {
        let name = fileName ?? baseName ?? defaultFileName()
        return resolvedOutputDirectory
            .appendingPathComponent(name)
            .appendingPathExtension(fileFormat.rawValue)
    }

    private func defaultFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return "MovieCapture_\(formatter.string(from: Date()))"
    }

    // MARK: - YAML serialization

    /// YAMLファイルから設定を読み込む
    public static func load(from url: URL) throws -> RecordingConfiguration {
        let data = try Data(contentsOf: url)
        let decoder = YAMLDecoder()
        return try decoder.decode(RecordingConfiguration.self, from: data)
    }

    /// YAMLファイルに設定を書き出す
    public func save(to url: URL) throws {
        let encoder = YAMLEncoder()
        let yamlString = try encoder.encode(self)
        try yamlString.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Validation

    /// 設定値のバリデーション
    public func validate() -> [String] {
        var errors: [String] = []
        if frameRate < 1 || frameRate > 120 {
            errors.append("frameRate must be between 1 and 120, got \(frameRate)")
        }
        if let tbh = titleBarHeight, tbh < 0 {
            errors.append("titleBarHeight must be non-negative, got \(tbh)")
        }
        return errors
    }
}
