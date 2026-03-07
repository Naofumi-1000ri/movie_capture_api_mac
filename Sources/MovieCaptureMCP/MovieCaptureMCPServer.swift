import CaptureEngine
import Foundation
import Logging
import MCP

// MARK: - Entry point

@main
struct MCPMain {
    static func main() async {
        do {
            let server = await Server(
                name: "moviecapture",
                version: "0.1.0"
            )
            .withMethodHandler(ListTools.self) { _ in
                ListTools.Result(tools: MCPToolDefinitions.allTools)
            }
            .withMethodHandler(CallTool.self) { params in
                await MCPHandlers.handleToolCall(params)
            }

            var stderrLogger = Logger(label: "mcp.server")
            stderrLogger.handler = StderrLogHandler()
            stderrLogger.logLevel = .warning

            let transport = StdioTransport(logger: stderrLogger)
            try await server.start(transport: transport)
            await server.waitUntilCompleted()
        } catch {
            fputs("MCP: error: \(error)\n", stderr)
        }
    }
}

// MARK: - Handlers

actor RecordingSessionStore {
    private var activeSession: MCPRecordingSessionMetadata?
    private var completedSession: MCPCompletedRecordingMetadata?

    func storeActive(_ metadata: MCPRecordingSessionMetadata) {
        activeSession = metadata
        completedSession = nil
    }

    func clearActive() {
        activeSession = nil
    }

    func snapshotActive() -> MCPRecordingSessionMetadata? {
        activeSession
    }

    func snapshotCompleted() -> MCPCompletedRecordingMetadata? {
        completedSession
    }

    func complete(
        outputPath: String,
        finishedAt: Date,
        stopReason: String
    ) -> MCPCompletedRecordingMetadata? {
        let completed = activeSession.map {
            MCPCompletedRecordingMetadata(
                target: $0.target,
                outputPath: outputPath,
                startedAt: $0.startedAt,
                finishedAt: finishedAt,
                stopReason: stopReason
            )
        }
        activeSession = nil
        completedSession = completed
        return completed
    }
}

struct MCPPreviewCaptureMetadata: Equatable, Sendable {
    let target: MCPTargetPayload
    let query: ResolveTargetQuery
    let analysis: MCPStillImageAnalysisPayload
    let capturedAt: Date
}

actor PreviewCaptureStore {
    private var lastPreview: MCPPreviewCaptureMetadata?

    func store(_ preview: MCPPreviewCaptureMetadata) {
        lastPreview = preview
    }

    func latest(for target: MCPTargetPayload) -> MCPPreviewCaptureMetadata? {
        guard let lastPreview, targetsMatch(lastPreview.target, target) else {
            return nil
        }
        return lastPreview
    }

    private func targetsMatch(_ lhs: MCPTargetPayload, _ rhs: MCPTargetPayload) -> Bool {
        if let lhsWindowId = lhs.windowId, let rhsWindowId = rhs.windowId {
            return lhsWindowId == rhsWindowId
                && ((lhs.recordingArguments.contentOnly ?? false) == (rhs.recordingArguments.contentOnly ?? false))
        }

        if let lhsDisplayId = lhs.displayId, let rhsDisplayId = rhs.displayId {
            return lhsDisplayId == rhsDisplayId
        }

        return false
    }
}

enum StartRecordingAdvisories {
    static func build(
        query: ResolveTargetQuery,
        preview: MCPPreviewCaptureMetadata?
    ) -> (preview: MCPPreviewReferencePayload?, advisories: [MCPAdvisoryPayload]) {
        let previewPayload = preview.map {
            MCPPreviewReferencePayload(
                capturedAt: $0.capturedAt,
                matchStatus: $0.analysis.previewMatchStatus,
                isLikelyBlank: $0.analysis.isLikelyBlank,
                matchedQueryTerms: $0.analysis.matchedQueryTerms
            )
        }

        var advisories: [MCPAdvisoryPayload] = []
        let hasTextualSelector = query.app != nil || query.window != nil

        if preview == nil && hasTextualSelector {
            advisories.append(
                MCPAdvisoryPayload(
                    code: "preview_not_confirmed",
                    severity: "warning",
                    message: "capture_still による対象確認がありません。text selector を使う場合は録画前に preview を確認すると安全です。"
                )
            )
            return (previewPayload, advisories)
        }

        guard let preview else {
            return (previewPayload, advisories)
        }

        switch preview.analysis.previewMatchStatus {
        case "not_applicable" where hasTextualSelector:
            advisories.append(
                MCPAdvisoryPayload(
                    code: "preview_not_confirmed",
                    severity: "warning",
                    message: "直前の preview では query 条件との一致確認ができていません。同じ selector で capture_still を呼ぶと安全です。"
                )
            )
        case "blank":
            advisories.append(
                MCPAdvisoryPayload(
                    code: "preview_blank",
                    severity: "warning",
                    message: "直前の preview は blank 判定でした。対象が隠れているか、意図と違う可能性があります。"
                )
            )
        case "partial", "partial_metadata":
            advisories.append(
                MCPAdvisoryPayload(
                    code: "preview_match_partial",
                    severity: "warning",
                    message: "直前の preview は query と部分一致でした。録画前に image content を確認してください。"
                )
            )
        case "none":
            advisories.append(
                MCPAdvisoryPayload(
                    code: "preview_match_none",
                    severity: "warning",
                    message: "直前の preview では query との一致が確認できませんでした。録画対象を再確認してください。"
                )
            )
        default:
            break
        }

        return (previewPayload, advisories)
    }
}

enum MCPHandlers {
    static let screenCaptureManager = ScreenCaptureManager()
    static let recordingManager = RecordingManager(screenCaptureProvider: screenCaptureManager)
    private static let sessionStore = RecordingSessionStore()
    private static let previewStore = PreviewCaptureStore()

    static func handleToolCall(_ params: CallTool.Parameters) async -> CallTool.Result {
        let toolName = params.name
        let args = params.arguments ?? [:]

        do {
            switch toolName {
            case "list_sources":
                return try await handleListSources(args)
            case "resolve_target":
                return try await handleResolveTarget(args)
            case "capture_still":
                return try await handleCaptureStill(args)
            case "start_recording":
                return try await handleStartRecording(args)
            case "stop_recording":
                return try await handleStopRecording()
            case "get_status":
                return await handleGetStatus()
            default:
                return MCPJSONResponse.errorResult(code: "unknown_tool", message: "Unknown tool: \(toolName)")
            }
        } catch {
            return MCPJSONResponse.error(from: error)
        }
    }

    static func handleListSources(_ args: [String: Value]) async throws -> CallTool.Result {
        let sources = try await screenCaptureManager.availableSources()

        var filterType = args["type"]?.stringValue
        let filterApp = args["app"]?.stringValue
        let onScreenOnly = args["on_screen_only"]?.boolValue ?? true

        // アプリ名フィルタ指定時はウィンドウのみ表示（ディスプレイとの ID 混同を防止）
        if filterApp != nil && filterType == nil {
            filterType = "windows"
        }

        if let filterType, filterType != "displays", filterType != "windows" {
            return MCPJSONResponse.errorResult(code: "invalid_configuration", message: "type は displays または windows を指定してください。")
        }

        let displays =
            filterType == nil || filterType == "displays"
            ? sources.displays.enumerated().map { index, display in
                MCPTargetPayload(
                    display: display,
                    isMainDisplay: index == 0,
                    matchedBy: "list_sources"
                )
            }
            : []

        let windows: [MCPTargetPayload]
        if filterType == nil || filterType == "windows" {
            var filteredWindows = onScreenOnly ? sources.onScreenWindows : sources.windows
            if let app = filterApp {
                filteredWindows = sources.windows(ownedBy: app)
                if onScreenOnly {
                    filteredWindows = filteredWindows.filter(\.isOnScreen)
                }
            }
            windows = filteredWindows.map {
                MCPTargetPayload(window: $0, contentOnly: false, matchedBy: "list_sources")
            }
        } else {
            windows = []
        }

        return MCPJSONResponse.result(
            MCPListSourcesResponse(
                status: "ok",
                filters: MCPListSourcesFiltersPayload(
                    type: filterType,
                    app: filterApp,
                    onScreenOnly: onScreenOnly
                ),
                displays: displays,
                windows: windows,
                counts: MCPListSourcesCountsPayload(displays: displays.count, windows: windows.count)
            )
        )
    }

    static func handleResolveTarget(_ args: [String: Value]) async throws -> CallTool.Result {
        let sources = try await screenCaptureManager.availableSources()
        let query = makeResolveTargetQuery(from: args)
        let resolution = try TargetResolver.resolve(query: query, in: sources)
        return MCPJSONResponse.result(makeResolveTargetResponse(resolution: resolution, query: query))
    }

    static func handleCaptureStill(_ args: [String: Value]) async throws -> CallTool.Result {
        await AppInitializer.ensureInitialized()

        let maxDimension = args["max_dimension"]?.intValue ?? 1200
        if maxDimension <= 0 {
            return MCPJSONResponse.errorResult(
                code: "invalid_configuration",
                message: "max_dimension は 1 以上の整数を指定してください。"
            )
        }

        let query = makeResolveTargetQuery(from: args)
        let sources = try await screenCaptureManager.availableSources()
        let resolution = try TargetResolver.resolve(query: query, in: sources)

        switch resolution {
        case .ambiguous(let candidates, _, let message):
            return MCPJSONResponse.errorResult(
                code: "ambiguous_target",
                message: message,
                query: query.payload,
                candidates: candidates
            )
        case .notFound(_, let message):
            return MCPJSONResponse.errorResult(
                code: "target_not_found",
                message: message,
                query: query.payload
            )
        case .resolved(let resolvedTarget, _, _):
            let image = try await screenCaptureManager.captureStillImage(
                source: resolvedTarget.source,
                maxDimension: maxDimension
            )
            let capturedAt = Date()
            let analysis = (try? StillImageAnalyzer.analyze(
                pngData: image.pngData,
                query: query,
                target: resolvedTarget.payload
            ))
                ?? MCPStillImageAnalysisPayload(
                    isLikelyBlank: false,
                    previewMatchStatus: "unknown",
                    recognizedText: [],
                    matchedQueryTerms: [],
                    matchedQueryTermsInRecognizedText: [],
                    matchedQueryTermsInTargetMetadata: [],
                    dominantColors: []
                )
            await previewStore.store(
                MCPPreviewCaptureMetadata(
                    target: resolvedTarget.payload,
                    query: query,
                    analysis: analysis,
                    capturedAt: capturedAt
                )
            )

            return MCPRichResponse.imageResult(
                MCPCaptureStillResponse(
                    status: "ok",
                    target: resolvedTarget.payload,
                    mimeType: "image/png",
                    width: image.width,
                    height: image.height,
                    byteCount: image.pngData.count,
                    maxDimension: maxDimension,
                    analysis: analysis,
                    message: "静止画プレビューを取得しました。image content を確認してください。"
                ),
                imageData: image.pngData,
                mimeType: "image/png",
                metadata: [
                    "width": "\(image.width)",
                    "height": "\(image.height)",
                    "target_kind": resolvedTarget.payload.kind,
                ]
            )
        }
    }

    static func handleStartRecording(_ args: [String: Value]) async throws -> CallTool.Result {
        await AppInitializer.ensureInitialized()

        let duration = args["duration"]?.intValue
        if let duration, duration <= 0 {
            return MCPJSONResponse.errorResult(code: "invalid_configuration", message: "duration は 1 以上の整数を指定してください。")
        }

        let query = makeResolveTargetQuery(from: args)
        let sources = try await screenCaptureManager.availableSources()
        let resolution = try TargetResolver.resolve(query: query, in: sources)

        switch resolution {
        case .ambiguous(let candidates, _, let message):
            return MCPJSONResponse.errorResult(
                code: "ambiguous_target",
                message: message,
                query: query.payload,
                candidates: candidates
            )
        case .notFound(_, let message):
            return MCPJSONResponse.errorResult(
                code: "target_not_found",
                message: message,
                query: query.payload
            )
        case .resolved(let resolvedTarget, _, _):
            var config = try buildRecordingConfiguration(from: args)
            config.assignGeneratedFileNameIfNeeded()
            let outputURL = config.outputFileURL()
            let startedAt = Date()
            let previewMetadata = await previewStore.latest(for: resolvedTarget.payload)
            let advisoryBundle = StartRecordingAdvisories.build(
                query: query,
                preview: previewMetadata
            )

            await sessionStore.storeActive(MCPRecordingSessionMetadata(
                target: resolvedTarget.payload,
                outputPath: outputURL.path,
                startedAt: startedAt,
                autoStopAfterSeconds: duration
            ))

            do {
                try await recordingManager.startRecording(source: resolvedTarget.source, configuration: config)
            } catch {
                await sessionStore.clearActive()
                throw error
            }

            if let duration {
                Task {
                    do {
                        try await Task.sleep(for: .seconds(duration))
                        _ = try await stopCurrentRecording(stopReason: "duration_elapsed")
                    } catch {
                        // manual stop 済みなどは無視
                    }
                }
            }

            return MCPJSONResponse.result(
                MCPStartRecordingResponse(
                    status: "recording",
                    target: resolvedTarget.payload,
                    outputPath: outputURL.path,
                    autoStopAfterSeconds: duration,
                    startedAt: startedAt,
                    preview: advisoryBundle.preview,
                    advisories: advisoryBundle.advisories,
                    message: duration == nil
                        ? "録画を開始しました。stop_recording で停止してください。"
                        : "録画を開始しました。duration 秒後に自動停止します。"
                )
            )
        }
    }

    static func handleStopRecording() async throws -> CallTool.Result {
        let response = try await stopCurrentRecording(stopReason: "manual")
        return MCPJSONResponse.result(response)
    }

    static func handleGetStatus() async -> CallTool.Result {
        let state = recordingManager.state
        let activeSession = await sessionStore.snapshotActive()
        let completedSession = await sessionStore.snapshotCompleted()

        let response: MCPStatusResponse
        switch state {
        case .idle:
            response = MCPStatusResponse(
                status: "idle",
                elapsedSeconds: nil,
                outputPath: nil,
                target: nil,
                autoStopAfterSeconds: nil,
                startedAt: nil,
                finishedAt: nil,
                stopReason: nil,
                message: "待機中です。"
            )
        case .preparing:
            response = MCPStatusResponse(
                status: "preparing",
                elapsedSeconds: activeSession.map { Date().timeIntervalSince($0.startedAt) },
                outputPath: activeSession?.outputPath,
                target: activeSession?.target,
                autoStopAfterSeconds: activeSession?.autoStopAfterSeconds,
                startedAt: activeSession?.startedAt,
                finishedAt: nil,
                stopReason: nil,
                message: "録画準備中です。"
            )
        case .recording(let startTime):
            response = MCPStatusResponse(
                status: "recording",
                elapsedSeconds: Date().timeIntervalSince(startTime),
                outputPath: activeSession?.outputPath,
                target: activeSession?.target,
                autoStopAfterSeconds: activeSession?.autoStopAfterSeconds,
                startedAt: activeSession?.startedAt,
                finishedAt: nil,
                stopReason: nil,
                message: "録画中です。"
            )
        case .paused(let elapsed):
            response = MCPStatusResponse(
                status: "paused",
                elapsedSeconds: elapsed,
                outputPath: activeSession?.outputPath,
                target: activeSession?.target,
                autoStopAfterSeconds: activeSession?.autoStopAfterSeconds,
                startedAt: activeSession?.startedAt,
                finishedAt: nil,
                stopReason: nil,
                message: "録画は一時停止中です。"
            )
        case .stopping:
            response = MCPStatusResponse(
                status: "stopping",
                elapsedSeconds: activeSession.map { Date().timeIntervalSince($0.startedAt) },
                outputPath: activeSession?.outputPath,
                target: activeSession?.target,
                autoStopAfterSeconds: activeSession?.autoStopAfterSeconds,
                startedAt: activeSession?.startedAt,
                finishedAt: nil,
                stopReason: nil,
                message: "停止処理中です。"
            )
        case .completed(let url):
            response = MCPStatusResponse(
                status: "completed",
                elapsedSeconds: completedSession.map { $0.finishedAt.timeIntervalSince($0.startedAt) },
                outputPath: url.path,
                target: completedSession?.target,
                autoStopAfterSeconds: nil,
                startedAt: completedSession?.startedAt,
                finishedAt: completedSession?.finishedAt,
                stopReason: completedSession?.stopReason,
                message: "録画は完了しています。"
            )
        case .failed(let reason):
            response = MCPStatusResponse(
                status: "failed",
                elapsedSeconds: nil,
                outputPath: activeSession?.outputPath ?? completedSession?.outputPath,
                target: activeSession?.target ?? completedSession?.target,
                autoStopAfterSeconds: activeSession?.autoStopAfterSeconds,
                startedAt: activeSession?.startedAt ?? completedSession?.startedAt,
                finishedAt: completedSession?.finishedAt,
                stopReason: completedSession?.stopReason,
                message: reason
            )
        }
        return MCPJSONResponse.result(response)
    }

    private static func makeResolveTargetQuery(from args: [String: Value]) -> ResolveTargetQuery {
        ResolveTargetQuery(
            displayId: args["display_id"]?.intValue,
            windowId: args["window_id"]?.intValue,
            app: args["app"]?.stringValue,
            window: args["window"]?.stringValue,
            onScreenOnly: args["on_screen_only"]?.boolValue ?? true,
            contentOnly: args["content_only"]?.boolValue ?? false
        )
    }

    private static func makeResolveTargetResponse(
        resolution: TargetResolution,
        query: ResolveTargetQuery
    ) -> MCPResolveTargetResponse {
        switch resolution {
        case .resolved(let target, let strategy, let defaultedToMainDisplay):
            return MCPResolveTargetResponse(
                status: resolution.responseStatus,
                query: query.payload,
                matchStrategy: strategy.rawValue,
                target: target.payload,
                candidates: resolution.queryCandidates,
                defaultedToMainDisplay: defaultedToMainDisplay,
                message: resolution.responseMessage
            )
        case .ambiguous(let candidates, let strategy, let message):
            return MCPResolveTargetResponse(
                status: resolution.responseStatus,
                query: query.payload,
                matchStrategy: strategy.rawValue,
                target: nil,
                candidates: candidates,
                defaultedToMainDisplay: false,
                message: message
            )
        case .notFound(let strategy, let message):
            return MCPResolveTargetResponse(
                status: resolution.responseStatus,
                query: query.payload,
                matchStrategy: strategy.rawValue,
                target: nil,
                candidates: [],
                defaultedToMainDisplay: false,
                message: message
            )
        }
    }

    private static func buildRecordingConfiguration(from args: [String: Value]) throws -> RecordingConfiguration {
        var config = RecordingConfiguration()
        if let fps = args["fps"]?.intValue { config.frameRate = fps }
        if let codec = args["codec"]?.stringValue {
            guard let vc = VideoCodec(rawValue: codec) else {
                throw CaptureError.invalidConfiguration(["codec must be h264 or h265, got \(codec)"])
            }
            config.videoCodec = vc
        }
        if let format = args["format"]?.stringValue {
            guard let ff = FileFormat(rawValue: format) else {
                throw CaptureError.invalidConfiguration(["format must be mov or mp4, got \(format)"])
            }
            config.fileFormat = ff
        }
        if let output = args["output"]?.stringValue {
            let url = URL(fileURLWithPath: output)
            config.outputDirectory = url.deletingLastPathComponent().path
            config.fileName = url.deletingPathExtension().lastPathComponent
            if !url.pathExtension.isEmpty {
                guard let ext = FileFormat(rawValue: url.pathExtension) else {
                    throw CaptureError.invalidConfiguration([
                        "output extension must be mov or mp4, got \(url.pathExtension)",
                    ])
                }
                config.fileFormat = ext
            }
        }

        let errors = config.validate()
        guard errors.isEmpty else {
            throw CaptureError.invalidConfiguration(errors)
        }

        return config
    }

    private static func stopCurrentRecording(stopReason: String) async throws -> MCPStopRecordingResponse {
        let url = try await recordingManager.stopRecording()
        let finishedAt = Date()
        let metadata = await sessionStore.complete(
            outputPath: url.path,
            finishedAt: finishedAt,
            stopReason: stopReason
        )
        return MCPStopRecordingResponse(
            status: "completed",
            outputPath: url.path,
            target: metadata?.target,
            stopReason: stopReason,
            finishedAt: finishedAt,
            message: "録画を停止して保存しました。"
        )
    }
}
