import CoreGraphics
import Foundation
import Testing

@testable import CaptureEngine

@Suite("RecordingManager Tests")
struct RecordingManagerTests {
    let mockProvider = MockScreenCaptureProvider()

    // MARK: - State management

    @Test("初期状態はidle")
    func initialStateIsIdle() {
        let manager = RecordingManager(screenCaptureProvider: mockProvider)
        #expect(manager.state == .idle)
    }

    @Test("setStateで状態が変更される")
    func setState() {
        let manager = RecordingManager(screenCaptureProvider: mockProvider)
        manager.setState(.preparing)
        #expect(manager.state == .preparing)
    }

    // MARK: - validateBeforeRecording

    @Test("正常な設定でバリデーション通過")
    func validateValidConfig() throws {
        let manager = RecordingManager(screenCaptureProvider: mockProvider)
        let source = CaptureSource.display(
            DisplayInfo(id: 1, width: 1920, height: 1080, frame: .zero)
        )
        let config = RecordingConfiguration(outputDirectory: "/tmp")

        try manager.validateBeforeRecording(source: source, configuration: config)
    }

    @Test("既に録画中の場合はalreadyRecordingエラー")
    func validateWhileRecording() {
        let manager = RecordingManager(screenCaptureProvider: mockProvider)
        manager.setState(.recording(startTime: Date()))

        let source = CaptureSource.display(
            DisplayInfo(id: 1, width: 1920, height: 1080, frame: .zero)
        )
        let config = RecordingConfiguration(outputDirectory: "/tmp")

        #expect(throws: CaptureError.alreadyRecording) {
            try manager.validateBeforeRecording(source: source, configuration: config)
        }
    }

    @Test("paused中もalreadyRecordingエラー")
    func validateWhilePaused() {
        let manager = RecordingManager(screenCaptureProvider: mockProvider)
        manager.setState(.paused(elapsed: 5.0))

        let source = CaptureSource.display(
            DisplayInfo(id: 1, width: 1920, height: 1080, frame: .zero)
        )
        let config = RecordingConfiguration(outputDirectory: "/tmp")

        #expect(throws: CaptureError.alreadyRecording) {
            try manager.validateBeforeRecording(source: source, configuration: config)
        }
    }

    @Test("無効な設定でinvalidConfigurationエラー")
    func validateInvalidConfig() {
        let manager = RecordingManager(screenCaptureProvider: mockProvider)
        let source = CaptureSource.display(
            DisplayInfo(id: 1, width: 1920, height: 1080, frame: .zero)
        )
        let config = RecordingConfiguration(frameRate: 0, outputDirectory: "/tmp")

        #expect {
            try manager.validateBeforeRecording(source: source, configuration: config)
        } throws: { error in
            guard let captureError = error as? CaptureError,
                  case .invalidConfiguration = captureError else {
                return false
            }
            return true
        }
    }

    @Test("存在しない出力ディレクトリでoutputDirectoryNotWritableエラー")
    func validateNonExistentOutputDir() {
        let manager = RecordingManager(screenCaptureProvider: mockProvider)
        let source = CaptureSource.display(
            DisplayInfo(id: 1, width: 1920, height: 1080, frame: .zero)
        )
        let config = RecordingConfiguration(outputDirectory: "/nonexistent/path")

        #expect {
            try manager.validateBeforeRecording(source: source, configuration: config)
        } throws: { error in
            guard let captureError = error as? CaptureError,
                  case .outputDirectoryNotWritable = captureError else {
                return false
            }
            return true
        }
    }

    // MARK: - stopRecording state check

    @Test("idle状態でstopRecordingするとnotRecordingエラー")
    func stopWhenIdle() async {
        let manager = RecordingManager(screenCaptureProvider: mockProvider)

        do {
            _ = try await manager.stopRecording()
            Issue.record("Expected error")
        } catch {
            #expect(error as? CaptureError == CaptureError.notRecording)
        }
    }

    // MARK: - buildStreamConfiguration

    @Test("windowContentOnlyのsourceRectが正しく設定される")
    func streamConfigForContentOnly() {
        let manager = RecordingManager(screenCaptureProvider: mockProvider)
        let window = WindowInfo(
            id: 1, title: "Test", ownerName: "App",
            frame: CGRect(x: 0, y: 0, width: 1200, height: 800),
            isOnScreen: true
        )
        let source = CaptureSource.windowContentOnly(window)
        let config = RecordingConfiguration(titleBarHeight: 28)

        let streamConfig = manager.buildStreamConfiguration(for: source, configuration: config)

        #expect(streamConfig.sourceRect.origin.y == 28)
        #expect(streamConfig.sourceRect.size.height == 772)
        #expect(streamConfig.sourceRect.size.width == 1200)
    }

    @Test("windowはsourceRect設定不要（desktopIndependentWindowがウィンドウサイズで返す）")
    func streamConfigForWindow() {
        let manager = RecordingManager(screenCaptureProvider: mockProvider)
        let window = WindowInfo(
            id: 1, title: "Test", ownerName: "App",
            frame: CGRect(x: 100, y: 200, width: 800, height: 600),
            isOnScreen: true
        )
        let source = CaptureSource.window(window)
        let config = RecordingConfiguration()

        let streamConfig = manager.buildStreamConfiguration(for: source, configuration: config)

        // desktopIndependentWindowではクロップ不要
        #expect(streamConfig.sourceRect == .zero)
    }

    @Test("windowContentOnlyはウィンドウローカル座標でタイトルバーをクロップ")
    func streamConfigForContentOnlyWithOffset() {
        let manager = RecordingManager(screenCaptureProvider: mockProvider)
        let window = WindowInfo(
            id: 1, title: "Test", ownerName: "App",
            frame: CGRect(x: 100, y: 200, width: 800, height: 600),
            isOnScreen: true
        )
        let source = CaptureSource.windowContentOnly(window)
        let config = RecordingConfiguration(titleBarHeight: 28)

        let streamConfig = manager.buildStreamConfiguration(for: source, configuration: config)

        // desktopIndependentWindowではローカル座標(0,0始まり)
        #expect(streamConfig.sourceRect.origin.x == 0)
        #expect(streamConfig.sourceRect.origin.y == 28)
        #expect(streamConfig.sourceRect.size.width == 800)
        #expect(streamConfig.sourceRect.size.height == 572) // 600 - 28
    }

    @Test("areaのsourceRectが正しく設定される")
    func streamConfigForArea() {
        let manager = RecordingManager(screenCaptureProvider: mockProvider)
        let display = DisplayInfo(id: 1, width: 2560, height: 1440, frame: .zero)
        let rect = CGRect(x: 100, y: 100, width: 800, height: 600)
        let source = CaptureSource.area(display: display, rect: rect)
        let config = RecordingConfiguration()

        let streamConfig = manager.buildStreamConfiguration(for: source, configuration: config)

        #expect(streamConfig.sourceRect == rect)
    }

    @Test("displayソースではsourceRectが設定されない")
    func streamConfigForDisplay() {
        let manager = RecordingManager(screenCaptureProvider: mockProvider)
        let display = DisplayInfo(id: 1, width: 2560, height: 1440, frame: .zero)
        let source = CaptureSource.display(display)
        let config = RecordingConfiguration(frameRate: 60)

        let streamConfig = manager.buildStreamConfiguration(for: source, configuration: config)

        #expect(streamConfig.sourceRect == .zero)
    }
}
