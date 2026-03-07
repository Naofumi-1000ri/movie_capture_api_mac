import CoreGraphics
import Testing

@testable import CaptureEngine
@testable import MovieCaptureMCP

@Suite("Still Image Analyzer Tests")
struct StillImageAnalyzerTests {
    @Test("単色画像は blank と判定される")
    func blankImageDetection() {
        let image = makeImage(
            width: 40,
            height: 40,
            pixelAt: { _, _ in (0, 0, 0, 255) }
        )

        let analysis = StillImageAnalyzer.analyze(image: image, query: ResolveTargetQuery())
        #expect(analysis.isLikelyBlank == true)
        #expect(analysis.previewMatchStatus == "blank")
        #expect(analysis.dominantColors.first?.hex == "#101010")
    }

    @Test("多色画像は metadata 一致を含む preview 判定を返す")
    func dominantColorExtraction() {
        let image = makeImage(
            width: 80,
            height: 40,
            pixelAt: { x, _ in
                if x < 40 {
                    return (240, 120, 64, 255)
                }
                return (24, 88, 152, 255)
            }
        )

        let analysis = StillImageAnalyzer.analyze(
            image: image,
            query: ResolveTargetQuery(app: "Chrome", window: "Proposal"),
            target: MCPTargetPayload(
                window: WindowInfo(
                    id: 12,
                    title: "Docs - Proposal",
                    ownerName: "Google Chrome",
                    frame: CGRect(x: 0, y: 0, width: 800, height: 600),
                    isOnScreen: true
                ),
                contentOnly: false,
                matchedBy: "app_and_window"
            )
        )

        #expect(analysis.isLikelyBlank == false)
        #expect(analysis.previewMatchStatus == "strong_metadata")
        #expect(analysis.matchedQueryTerms == ["Chrome", "Proposal"])
        #expect(analysis.matchedQueryTermsInRecognizedText.isEmpty)
        #expect(analysis.matchedQueryTermsInTargetMetadata == ["Chrome", "Proposal"])
        #expect(analysis.dominantColors.count >= 2)
        #expect(analysis.dominantColors.contains { $0.hex == "#F07050" || $0.hex == "#105090" })
    }
}

private func makeImage(
    width: Int,
    height: Int,
    pixelAt: (Int, Int) -> (UInt8, UInt8, UInt8, UInt8)
) -> CGImage {
    var pixels = [UInt8](repeating: 0, count: width * height * 4)

    for y in 0..<height {
        for x in 0..<width {
            let (r, g, b, a) = pixelAt(x, y)
            let offset = (y * width + x) * 4
            pixels[offset] = r
            pixels[offset + 1] = g
            pixels[offset + 2] = b
            pixels[offset + 3] = a
        }
    }

    let context = CGContext(
        data: &pixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!

    return context.makeImage()!
}
