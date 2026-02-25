import Foundation
import Testing

@testable import CaptureEngine

@Suite("RecordingConfiguration Tests")
struct RecordingConfigurationTests {

    // MARK: - Defaults

    @Test("デフォルト設定が正しい")
    func defaultValues() {
        let config = RecordingConfiguration()
        #expect(config.frameRate == 30)
        #expect(config.videoCodec == .h265)
        #expect(config.fileFormat == .mov)
        #expect(config.quality == .high)
        #expect(config.captureSystemAudio == true)
        #expect(config.captureMicrophone == false)
        #expect(config.outputDirectory == "~/Movies")
        #expect(config.fileName == nil)
        #expect(config.titleBarHeight == nil)
    }

    // MARK: - Validation

    @Test("正常な設定はバリデーションを通過する")
    func validConfig() {
        let config = RecordingConfiguration()
        let errors = config.validate()
        #expect(errors.isEmpty)
    }

    @Test("frameRateが範囲外の場合エラー")
    func invalidFrameRate() {
        var config = RecordingConfiguration()

        config.frameRate = 0
        #expect(!config.validate().isEmpty)

        config.frameRate = 121
        #expect(!config.validate().isEmpty)

        config.frameRate = 1
        #expect(config.validate().isEmpty)

        config.frameRate = 120
        #expect(config.validate().isEmpty)
    }

    @Test("titleBarHeightが負の場合エラー")
    func negativeTitleBarHeight() {
        var config = RecordingConfiguration()
        config.titleBarHeight = -1
        #expect(!config.validate().isEmpty)

        config.titleBarHeight = 0
        #expect(config.validate().isEmpty)
    }

    // MARK: - Output path

    @Test("チルダがホームディレクトリに展開される")
    func resolvedOutputDirectory() {
        let config = RecordingConfiguration(outputDirectory: "~/Movies")
        let resolved = config.resolvedOutputDirectory.path
        #expect(!resolved.contains("~"))
        #expect(resolved.hasSuffix("/Movies"))
    }

    @Test("outputFileURLがフォーマットに応じた拡張子を持つ")
    func outputFileExtension() {
        var config = RecordingConfiguration(outputDirectory: "/tmp")

        config.fileFormat = .mov
        #expect(config.outputFileURL(baseName: "test").pathExtension == "mov")

        config.fileFormat = .mp4
        #expect(config.outputFileURL(baseName: "test").pathExtension == "mp4")
    }

    @Test("fileNameが指定されている場合はそれが使われる")
    func customFileName() {
        let config = RecordingConfiguration(
            outputDirectory: "/tmp",
            fileName: "my-recording"
        )
        let url = config.outputFileURL()
        #expect(url.deletingPathExtension().lastPathComponent == "my-recording")
    }

    @Test("fileNameが未指定の場合はbaseNameが使われる")
    func baseNameFallback() {
        let config = RecordingConfiguration(outputDirectory: "/tmp")
        let url = config.outputFileURL(baseName: "fallback")
        #expect(url.deletingPathExtension().lastPathComponent == "fallback")
    }

    // MARK: - YAML serialization

    @Test("YAMLラウンドトリップが正しい")
    func yamlRoundTrip() throws {
        let original = RecordingConfiguration(
            frameRate: 60,
            videoCodec: .h264,
            fileFormat: .mp4,
            quality: .medium,
            captureSystemAudio: false,
            captureMicrophone: true,
            outputDirectory: "/tmp/test",
            fileName: "demo",
            titleBarHeight: 32.0
        )

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_config_\(UUID().uuidString).yaml")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try original.save(to: tempURL)
        let loaded = try RecordingConfiguration.load(from: tempURL)

        #expect(loaded == original)
    }
}
