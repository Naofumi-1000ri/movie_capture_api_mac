import Foundation
import ImageIO
import ScreenCaptureKit
import UniformTypeIdentifiers

/// ScreenCaptureKit を使用したキャプチャソース管理
public final class ScreenCaptureManager: ScreenCaptureProviding {
    public init() {}

    public func availableSources() async throws -> AvailableSources {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: false
        )

        let displays = content.displays.map { display in
            DisplayInfo(
                id: display.displayID,
                width: display.width,
                height: display.height,
                frame: display.frame
            )
        }

        let windows = content.windows.map { window in
            WindowInfo(
                id: window.windowID,
                title: window.title,
                ownerName: window.owningApplication?.applicationName,
                frame: window.frame,
                isOnScreen: window.isOnScreen
            )
        }

        return AvailableSources(displays: displays, windows: windows)
    }

    public func captureStillImage(source: CaptureSource, maxDimension: Int?) async throws -> CapturedStillImage {
        await AppInitializer.ensureInitialized()

        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: false
        )

        let filter = try CaptureSourceSetup.buildContentFilter(for: source, content: content)
        let configuration = SCStreamConfiguration()
        configuration.showsCursor = true
        CaptureSourceSetup.configureGeometry(for: source, in: configuration, maxDimension: maxDimension)

        let image = try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration) { image, error in
                if let image {
                    continuation.resume(returning: image)
                } else if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: CaptureError.recordingFailed("静止画を取得できませんでした"))
                }
            }
        }

        let pngData = try encodePNG(from: image)
        return CapturedStillImage(pngData: pngData, width: image.width, height: image.height)
    }

    private func encodePNG(from image: CGImage) throws -> Data {
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw CaptureError.recordingFailed("PNGエンコードの準備に失敗しました")
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw CaptureError.recordingFailed("PNGエンコードに失敗しました")
        }

        return mutableData as Data
    }
}
