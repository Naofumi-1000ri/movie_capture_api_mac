import CaptureEngine
import CoreGraphics
import Foundation

/// ScreenCaptureProviding のモック実装
final class MockScreenCaptureProvider: ScreenCaptureProviding, @unchecked Sendable {
    var stubbedSources: AvailableSources
    var stubbedStillImage = CapturedStillImage(
        pngData: Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jm7QAAAAASUVORK5CYII=")!,
        width: 1,
        height: 1
    )
    var availableSourcesCallCount = 0
    var captureStillImageCallCount = 0
    var shouldThrowError: CaptureError?

    init(sources: AvailableSources? = nil) {
        self.stubbedSources = sources ?? MockScreenCaptureProvider.defaultSources()
    }

    func availableSources() async throws -> AvailableSources {
        availableSourcesCallCount += 1
        if let error = shouldThrowError {
            throw error
        }
        return stubbedSources
    }

    func captureStillImage(source: CaptureSource, maxDimension: Int?) async throws -> CapturedStillImage {
        captureStillImageCallCount += 1
        if let error = shouldThrowError {
            throw error
        }
        return stubbedStillImage
    }

    // MARK: - Test helpers

    static func defaultSources() -> AvailableSources {
        AvailableSources(
            displays: [
                DisplayInfo(
                    id: 1,
                    width: 2560,
                    height: 1440,
                    frame: CGRect(x: 0, y: 0, width: 2560, height: 1440)
                ),
            ],
            windows: [
                WindowInfo(
                    id: 100,
                    title: "Google Chrome - GitHub",
                    ownerName: "Google Chrome",
                    frame: CGRect(x: 100, y: 100, width: 1200, height: 800),
                    isOnScreen: true
                ),
                WindowInfo(
                    id: 101,
                    title: "Terminal",
                    ownerName: "Terminal",
                    frame: CGRect(x: 200, y: 200, width: 800, height: 600),
                    isOnScreen: true
                ),
                WindowInfo(
                    id: 102,
                    title: "Hidden Window",
                    ownerName: "SomeApp",
                    frame: CGRect(x: 0, y: 0, width: 400, height: 300),
                    isOnScreen: false
                ),
            ]
        )
    }
}
