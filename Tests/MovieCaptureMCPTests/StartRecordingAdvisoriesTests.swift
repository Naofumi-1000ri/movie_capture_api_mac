import Foundation
import Testing

@testable import CaptureEngine
@testable import MovieCaptureMCP

@Suite("Start Recording Advisories Tests")
struct StartRecordingAdvisoriesTests {
    @Test("text selector に preview がなければ warning を返す")
    func missingPreviewWarning() {
        let result = StartRecordingAdvisories.build(
            query: ResolveTargetQuery(app: "Chrome", window: "Proposal"),
            preview: nil
        )

        #expect(result.preview == nil)
        #expect(result.advisories.count == 1)
        #expect(result.advisories[0].code == "preview_not_confirmed")
    }

    @Test("strong preview があれば warning は返さない")
    func strongPreviewProducesNoWarning() {
        let preview = MCPPreviewCaptureMetadata(
            target: MCPTargetPayload(
                window: WindowInfo(
                    id: 12,
                    title: "Docs - Proposal",
                    ownerName: "Google Chrome",
                    frame: .init(x: 0, y: 0, width: 800, height: 600),
                    isOnScreen: true
                ),
                contentOnly: false,
                matchedBy: "app_and_window"
            ),
            query: ResolveTargetQuery(app: "Chrome", window: "Proposal"),
            analysis: MCPStillImageAnalysisPayload(
                isLikelyBlank: false,
                previewMatchStatus: "strong_metadata",
                recognizedText: [],
                matchedQueryTerms: ["Chrome", "Proposal"],
                matchedQueryTermsInRecognizedText: [],
                matchedQueryTermsInTargetMetadata: ["Chrome", "Proposal"],
                dominantColors: []
            ),
            capturedAt: Date(timeIntervalSince1970: 123)
        )

        let result = StartRecordingAdvisories.build(
            query: ResolveTargetQuery(app: "Chrome", window: "Proposal"),
            preview: preview
        )

        #expect(result.advisories.isEmpty)
        #expect(result.preview?.matchStatus == "strong_metadata")
        #expect(result.preview?.matchedQueryTerms == ["Chrome", "Proposal"])
    }

    @Test("not_applicable preview で text selector を使うと warning を返す")
    func selectorMismatchWarning() {
        let preview = MCPPreviewCaptureMetadata(
            target: MCPTargetPayload(
                window: WindowInfo(
                    id: 12,
                    title: "Docs - Proposal",
                    ownerName: "Google Chrome",
                    frame: .init(x: 0, y: 0, width: 800, height: 600),
                    isOnScreen: true
                ),
                contentOnly: false,
                matchedBy: "window_id"
            ),
            query: ResolveTargetQuery(windowId: 12),
            analysis: MCPStillImageAnalysisPayload(
                isLikelyBlank: false,
                previewMatchStatus: "not_applicable",
                recognizedText: [],
                matchedQueryTerms: [],
                matchedQueryTermsInRecognizedText: [],
                matchedQueryTermsInTargetMetadata: [],
                dominantColors: []
            ),
            capturedAt: Date(timeIntervalSince1970: 123)
        )

        let result = StartRecordingAdvisories.build(
            query: ResolveTargetQuery(app: "Chrome", window: "Proposal"),
            preview: preview
        )

        #expect(result.advisories.count == 1)
        #expect(result.advisories[0].code == "preview_not_confirmed")
    }
}
