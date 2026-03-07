import CoreGraphics
import ScreenCaptureKit

enum CaptureSourceSetup {
    static func buildContentFilter(
        for source: CaptureSource,
        content: SCShareableContent
    ) throws -> SCContentFilter {
        switch source {
        case .display(let displayInfo):
            guard let scDisplay = content.displays.first(where: { $0.displayID == displayInfo.id }) else {
                throw CaptureError.noDisplayFound
            }
            return SCContentFilter(display: scDisplay, excludingWindows: [])

        case .window(let windowInfo), .windowContentOnly(let windowInfo):
            guard let scWindow = content.windows.first(where: { $0.windowID == windowInfo.id }) else {
                throw CaptureError.windowNotFound(windowInfo.title ?? "ID:\(windowInfo.id)")
            }
            return SCContentFilter(desktopIndependentWindow: scWindow)

        case .area(let displayInfo, _):
            guard let scDisplay = content.displays.first(where: { $0.displayID == displayInfo.id }) else {
                throw CaptureError.noDisplayFound
            }
            return SCContentFilter(display: scDisplay, excludingWindows: [])
        }
    }

    static func configureGeometry(
        for source: CaptureSource,
        in streamConfiguration: SCStreamConfiguration,
        titleBarHeight: CGFloat = WindowInfo.defaultTitleBarHeight,
        maxDimension: Int? = nil
    ) {
        switch source {
        case .window(let windowInfo):
            applyTargetSize(
                width: Int(windowInfo.frame.width * 2),
                height: Int(windowInfo.frame.height * 2),
                maxDimension: maxDimension,
                to: streamConfiguration
            )

        case .windowContentOnly(let windowInfo):
            let contentRect = windowInfo.contentRect(titleBarHeight: titleBarHeight)
            streamConfiguration.sourceRect = CGRect(
                x: 0,
                y: titleBarHeight,
                width: contentRect.width,
                height: contentRect.height
            )
            applyTargetSize(
                width: Int(contentRect.width * 2),
                height: Int(contentRect.height * 2),
                maxDimension: maxDimension,
                to: streamConfiguration
            )

        case .area(_, let rect):
            streamConfiguration.sourceRect = rect
            applyTargetSize(
                width: Int(rect.width * 2),
                height: Int(rect.height * 2),
                maxDimension: maxDimension,
                to: streamConfiguration
            )

        case .display(let displayInfo):
            applyTargetSize(
                width: displayInfo.width,
                height: displayInfo.height,
                maxDimension: maxDimension,
                to: streamConfiguration
            )
        }
    }

    private static func applyTargetSize(
        width: Int,
        height: Int,
        maxDimension: Int?,
        to streamConfiguration: SCStreamConfiguration
    ) {
        guard width > 0, height > 0 else {
            return
        }

        if let maxDimension, maxDimension > 0 {
            let longestSide = max(width, height)
            let scale = min(1.0, Double(maxDimension) / Double(longestSide))
            streamConfiguration.width = max(1, Int((Double(width) * scale).rounded()))
            streamConfiguration.height = max(1, Int((Double(height) * scale).rounded()))
            return
        }

        streamConfiguration.width = width
        streamConfiguration.height = height
    }
}
