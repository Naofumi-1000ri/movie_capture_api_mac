import CaptureEngine
import CoreGraphics
import Foundation
import MCP

struct MCPRectPayload: Codable, Equatable, Sendable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    init(_ rect: CGRect) {
        x = rect.origin.x
        y = rect.origin.y
        width = rect.size.width
        height = rect.size.height
    }
}

struct MCPRecordingArgumentsPayload: Codable, Equatable, Sendable {
    let displayId: Int?
    let windowId: Int?
    let contentOnly: Bool?

    enum CodingKeys: String, CodingKey {
        case displayId = "display_id"
        case windowId = "window_id"
        case contentOnly = "content_only"
    }
}

struct MCPTargetPayload: Codable, Equatable, Sendable {
    let kind: String
    let captureMode: String
    let displayId: Int?
    let windowId: Int?
    let title: String?
    let ownerName: String?
    let width: Int?
    let height: Int?
    let frame: MCPRectPayload
    let contentRect: MCPRectPayload?
    let isOnScreen: Bool?
    let isMainDisplay: Bool?
    let matchedBy: String
    let recordingArguments: MCPRecordingArgumentsPayload

    enum CodingKeys: String, CodingKey {
        case kind
        case captureMode = "capture_mode"
        case displayId = "display_id"
        case windowId = "window_id"
        case title
        case ownerName = "owner_name"
        case width
        case height
        case frame
        case contentRect = "content_rect"
        case isOnScreen = "is_on_screen"
        case isMainDisplay = "is_main_display"
        case matchedBy = "matched_by"
        case recordingArguments = "recording_arguments"
    }

    init(display: DisplayInfo, isMainDisplay: Bool, matchedBy: String) {
        kind = "display"
        captureMode = "display"
        displayId = Int(display.id)
        windowId = nil
        title = nil
        ownerName = nil
        width = display.width
        height = display.height
        frame = MCPRectPayload(display.frame)
        contentRect = nil
        isOnScreen = nil
        self.isMainDisplay = isMainDisplay
        self.matchedBy = matchedBy
        recordingArguments = MCPRecordingArgumentsPayload(
            displayId: Int(display.id),
            windowId: nil,
            contentOnly: nil
        )
    }

    init(window: WindowInfo, contentOnly: Bool, matchedBy: String) {
        kind = "window"
        captureMode = contentOnly ? "window_content_only" : "window"
        displayId = nil
        windowId = Int(window.id)
        title = window.title
        ownerName = window.ownerName
        width = Int(window.frame.width)
        height = Int(window.frame.height)
        frame = MCPRectPayload(window.frame)
        contentRect = MCPRectPayload(window.contentRect)
        isOnScreen = window.isOnScreen
        isMainDisplay = nil
        self.matchedBy = matchedBy
        recordingArguments = MCPRecordingArgumentsPayload(
            displayId: nil,
            windowId: Int(window.id),
            contentOnly: contentOnly ? true : nil
        )
    }
}

struct MCPListSourcesFiltersPayload: Codable, Equatable, Sendable {
    let type: String?
    let app: String?
    let onScreenOnly: Bool

    enum CodingKeys: String, CodingKey {
        case type
        case app
        case onScreenOnly = "on_screen_only"
    }
}

struct MCPListSourcesCountsPayload: Codable, Equatable, Sendable {
    let displays: Int
    let windows: Int
}

struct MCPListSourcesResponse: Codable, Equatable, Sendable {
    let status: String
    let filters: MCPListSourcesFiltersPayload
    let displays: [MCPTargetPayload]
    let windows: [MCPTargetPayload]
    let counts: MCPListSourcesCountsPayload
}

struct MCPResolveTargetQueryPayload: Codable, Equatable, Sendable {
    let displayId: Int?
    let windowId: Int?
    let app: String?
    let window: String?
    let onScreenOnly: Bool
    let contentOnly: Bool

    enum CodingKeys: String, CodingKey {
        case displayId = "display_id"
        case windowId = "window_id"
        case app
        case window
        case onScreenOnly = "on_screen_only"
        case contentOnly = "content_only"
    }
}

struct MCPResolveTargetResponse: Codable, Equatable, Sendable {
    let status: String
    let query: MCPResolveTargetQueryPayload
    let matchStrategy: String
    let target: MCPTargetPayload?
    let candidates: [MCPTargetPayload]
    let defaultedToMainDisplay: Bool
    let message: String

    enum CodingKeys: String, CodingKey {
        case status
        case query
        case matchStrategy = "match_strategy"
        case target
        case candidates
        case defaultedToMainDisplay = "defaulted_to_main_display"
        case message
    }
}

struct MCPStartRecordingResponse: Codable, Equatable, Sendable {
    let status: String
    let target: MCPTargetPayload
    let outputPath: String
    let autoStopAfterSeconds: Int?
    let startedAt: Date
    let preview: MCPPreviewReferencePayload?
    let advisories: [MCPAdvisoryPayload]
    let message: String

    enum CodingKeys: String, CodingKey {
        case status
        case target
        case outputPath = "output_path"
        case autoStopAfterSeconds = "auto_stop_after_seconds"
        case startedAt = "started_at"
        case preview
        case advisories
        case message
    }
}

struct MCPPreviewReferencePayload: Codable, Equatable, Sendable {
    let capturedAt: Date
    let matchStatus: String
    let isLikelyBlank: Bool
    let matchedQueryTerms: [String]

    enum CodingKeys: String, CodingKey {
        case capturedAt = "captured_at"
        case matchStatus = "match_status"
        case isLikelyBlank = "is_likely_blank"
        case matchedQueryTerms = "matched_query_terms"
    }
}

struct MCPAdvisoryPayload: Codable, Equatable, Sendable {
    let code: String
    let severity: String
    let message: String
}

struct MCPCaptureStillResponse: Codable, Equatable, Sendable {
    let status: String
    let target: MCPTargetPayload
    let mimeType: String
    let width: Int
    let height: Int
    let byteCount: Int
    let maxDimension: Int
    let analysis: MCPStillImageAnalysisPayload
    let message: String

    enum CodingKeys: String, CodingKey {
        case status
        case target
        case mimeType = "mime_type"
        case width
        case height
        case byteCount = "byte_count"
        case maxDimension = "max_dimension"
        case analysis
        case message
    }
}

struct MCPStillImageAnalysisPayload: Codable, Equatable, Sendable {
    let isLikelyBlank: Bool
    let previewMatchStatus: String
    let recognizedText: [String]
    let matchedQueryTerms: [String]
    let matchedQueryTermsInRecognizedText: [String]
    let matchedQueryTermsInTargetMetadata: [String]
    let dominantColors: [MCPDominantColorPayload]

    enum CodingKeys: String, CodingKey {
        case isLikelyBlank = "is_likely_blank"
        case previewMatchStatus = "preview_match_status"
        case recognizedText = "recognized_text"
        case matchedQueryTerms = "matched_query_terms"
        case matchedQueryTermsInRecognizedText = "matched_query_terms_in_recognized_text"
        case matchedQueryTermsInTargetMetadata = "matched_query_terms_in_target_metadata"
        case dominantColors = "dominant_colors"
    }
}

struct MCPDominantColorPayload: Codable, Equatable, Sendable {
    let hex: String
    let ratio: Double
}

struct MCPStopRecordingResponse: Codable, Equatable, Sendable {
    let status: String
    let outputPath: String
    let target: MCPTargetPayload?
    let stopReason: String
    let finishedAt: Date
    let message: String

    enum CodingKeys: String, CodingKey {
        case status
        case outputPath = "output_path"
        case target
        case stopReason = "stop_reason"
        case finishedAt = "finished_at"
        case message
    }
}

struct MCPStatusResponse: Codable, Equatable, Sendable {
    let status: String
    let elapsedSeconds: Double?
    let outputPath: String?
    let target: MCPTargetPayload?
    let autoStopAfterSeconds: Int?
    let startedAt: Date?
    let finishedAt: Date?
    let stopReason: String?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case status
        case elapsedSeconds = "elapsed_seconds"
        case outputPath = "output_path"
        case target
        case autoStopAfterSeconds = "auto_stop_after_seconds"
        case startedAt = "started_at"
        case finishedAt = "finished_at"
        case stopReason = "stop_reason"
        case message
    }
}

struct MCPErrorDetail: Codable, Equatable, Sendable {
    let code: String
    let message: String
}

struct MCPErrorResponse: Codable, Equatable, Sendable {
    let status: String
    let error: MCPErrorDetail
    let query: MCPResolveTargetQueryPayload?
    let candidates: [MCPTargetPayload]?

    init(
        error: MCPErrorDetail,
        query: MCPResolveTargetQueryPayload? = nil,
        candidates: [MCPTargetPayload]? = nil
    ) {
        status = "error"
        self.error = error
        self.query = query
        self.candidates = candidates
    }
}

struct MCPRecordingSessionMetadata: Equatable, Sendable {
    let target: MCPTargetPayload
    let outputPath: String
    let startedAt: Date
    let autoStopAfterSeconds: Int?
}

struct MCPCompletedRecordingMetadata: Equatable, Sendable {
    let target: MCPTargetPayload
    let outputPath: String
    let startedAt: Date
    let finishedAt: Date
    let stopReason: String
}

enum MCPJSONResponse {
    static func result<T: Encodable>(_ payload: T, isError: Bool = false) -> CallTool.Result {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(payload)
            return CallTool.Result(
                content: [.text(String(decoding: data, as: UTF8.self))],
                isError: isError ? true : nil
            )
        } catch {
            let fallback = """
            {"status":"error","error":{"code":"encoding_failed","message":"\(error.localizedDescription)"}}
            """
            return CallTool.Result(content: [.text(fallback)], isError: true)
        }
    }

    static func errorResult(
        code: String,
        message: String,
        query: MCPResolveTargetQueryPayload? = nil,
        candidates: [MCPTargetPayload]? = nil
    ) -> CallTool.Result {
        result(
            MCPErrorResponse(
                error: MCPErrorDetail(code: code, message: message),
                query: query,
                candidates: candidates
            ),
            isError: true
        )
    }

    static func error(from error: any Swift.Error) -> CallTool.Result {
        if let captureError = error as? CaptureError {
            return errorResult(code: code(for: captureError), message: captureError.localizedDescription)
        }
        return errorResult(code: "internal_error", message: error.localizedDescription)
    }

    private static func code(for error: CaptureError) -> String {
        switch error {
        case .screenCaptureNotAuthorized:
            return "screen_capture_not_authorized"
        case .microphoneNotAuthorized:
            return "microphone_not_authorized"
        case .noDisplayFound:
            return "display_not_found"
        case .windowNotFound:
            return "window_not_found"
        case .alreadyRecording:
            return "already_recording"
        case .notRecording:
            return "not_recording"
        case .invalidConfiguration:
            return "invalid_configuration"
        case .outputDirectoryNotWritable:
            return "output_directory_not_writable"
        case .recordingFailed:
            return "recording_failed"
        }
    }
}

enum MCPRichResponse {
    static func imageResult<T: Encodable>(
        _ payload: T,
        imageData: Data,
        mimeType: String,
        metadata: [String: String]? = nil
    ) -> CallTool.Result {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(payload)
            return CallTool.Result(
                content: [
                    .text(String(decoding: data, as: UTF8.self)),
                    .image(
                        data: imageData.base64EncodedString(),
                        mimeType: mimeType,
                        metadata: metadata
                    ),
                ]
            )
        } catch {
            return MCPJSONResponse.errorResult(
                code: "encoding_failed",
                message: error.localizedDescription
            )
        }
    }
}
