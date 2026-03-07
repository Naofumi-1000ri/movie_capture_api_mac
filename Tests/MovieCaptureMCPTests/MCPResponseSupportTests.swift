import Foundation
import MCP
import Testing

@testable import CaptureEngine
@testable import MovieCaptureMCP

@Suite("MCP Response Support Tests")
struct MCPResponseSupportTests {
    @Test("imageResult は text と image content を返す")
    func imageResultIncludesStructuredPreview() throws {
        let payload = MCPCaptureStillResponse(
            status: "ok",
            target: MCPTargetPayload(
                display: DisplayInfo(
                    id: 1,
                    width: 1920,
                    height: 1080,
                    frame: .init(x: 0, y: 0, width: 1920, height: 1080)
                ),
                isMainDisplay: true,
                matchedBy: "display_id"
            ),
            mimeType: "image/png",
            width: 640,
            height: 360,
            byteCount: 4,
            maxDimension: 1200,
            analysis: MCPStillImageAnalysisPayload(
                isLikelyBlank: false,
                previewMatchStatus: "strong_metadata",
                recognizedText: ["Preview"],
                matchedQueryTerms: ["Preview"],
                matchedQueryTermsInRecognizedText: ["Preview"],
                matchedQueryTermsInTargetMetadata: ["Preview"],
                dominantColors: [
                    MCPDominantColorPayload(hex: "#102030", ratio: 0.6)
                ]
            ),
            message: "preview"
        )

        let result = MCPRichResponse.imageResult(
            payload,
            imageData: Data([0x89, 0x50, 0x4E, 0x47]),
            mimeType: "image/png",
            metadata: ["width": "640"]
        )

        #expect(result.isError != true)
        #expect(result.content.count == 2)

        guard case .text(let text) = result.content[0] else {
            Issue.record("Expected text content")
            return
        }
        #expect(text.contains("\"status\":\"ok\""))
        #expect(text.contains("\"mime_type\":\"image\\/png\""))
        #expect(text.contains("\"is_likely_blank\":false"))
        #expect(text.contains("\"preview_match_status\":\"strong_metadata\""))

        guard case .image(let data, let mimeType, let metadata) = result.content[1] else {
            Issue.record("Expected image content")
            return
        }
        #expect(data == Data([0x89, 0x50, 0x4E, 0x47]).base64EncodedString())
        #expect(mimeType == "image/png")
        #expect(metadata?["width"] == "640")
    }
}
