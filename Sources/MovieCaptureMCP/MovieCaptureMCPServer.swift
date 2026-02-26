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

enum MCPHandlers {
    static let screenCaptureManager = ScreenCaptureManager()
    static let recordingManager = RecordingManager(screenCaptureProvider: screenCaptureManager)

    static func handleToolCall(_ params: CallTool.Parameters) async -> CallTool.Result {
        let toolName = params.name
        let args = params.arguments ?? [:]

        do {
            switch toolName {
            case "list_sources":
                return try await handleListSources(args)
            case "start_recording":
                return try await handleStartRecording(args)
            case "stop_recording":
                return try await handleStopRecording()
            case "get_status":
                return handleGetStatus()
            default:
                return CallTool.Result(
                    content: [.text("Unknown tool: \(toolName)")],
                    isError: true
                )
            }
        } catch {
            return CallTool.Result(
                content: [.text("Error: \(error.localizedDescription)")],
                isError: true
            )
        }
    }

    static func handleListSources(_ args: [String: Value]) async throws -> CallTool.Result {
        let sources = try await screenCaptureManager.availableSources()

        let filterType = args["type"]?.stringValue
        let filterApp = args["app"]?.stringValue
        let onScreenOnly = args["on_screen_only"]?.boolValue ?? true

        var lines: [String] = []

        if filterType == nil || filterType == "displays" {
            lines.append("## Displays")
            for d in sources.displays {
                lines.append("- ID: \(d.id), \(d.width)x\(d.height)")
            }
        }

        if filterType == nil || filterType == "windows" {
            lines.append("")
            lines.append("## Windows")
            var windows = onScreenOnly ? sources.onScreenWindows : sources.windows
            if let app = filterApp {
                windows = sources.windows(ownedBy: app)
                if onScreenOnly { windows = windows.filter(\.isOnScreen) }
            }
            for w in windows {
                let title = w.title ?? "(untitled)"
                let owner = w.ownerName ?? "(unknown)"
                let screen = w.isOnScreen ? "on" : "off"
                lines.append("- ID: \(w.id), [\(owner)] \(title), \(Int(w.frame.width))x\(Int(w.frame.height)), \(screen)screen")
            }
        }

        return CallTool.Result(content: [.text(lines.joined(separator: "\n"))])
    }

    static func handleStartRecording(_ args: [String: Value]) async throws -> CallTool.Result {
        // CGSセッション初期化（ウィンドウキャプチャに必要）
        await AppInitializer.ensureInitialized()

        let sources = try await screenCaptureManager.availableSources()
        let contentOnly = args["content_only"]?.boolValue ?? false

        let source: CaptureSource
        if let windowId = args["window_id"]?.intValue {
            guard let win = sources.windows.first(where: { $0.id == UInt32(windowId) }) else {
                throw CaptureError.windowNotFound("ID: \(windowId)")
            }
            source = contentOnly ? .windowContentOnly(win) : .window(win)
        } else if let appName = args["app"]?.stringValue {
            let matches = sources.windows(ownedBy: appName).filter(\.isOnScreen)
            guard let win = matches.first else {
                throw CaptureError.windowNotFound(appName)
            }
            source = contentOnly ? .windowContentOnly(win) : .window(win)
        } else if let windowTitle = args["window"]?.stringValue {
            let matches = sources.windows(titled: windowTitle).filter(\.isOnScreen)
            guard let win = matches.first else {
                throw CaptureError.windowNotFound(windowTitle)
            }
            source = contentOnly ? .windowContentOnly(win) : .window(win)
        } else {
            guard let display = sources.displays.first else {
                throw CaptureError.noDisplayFound
            }
            source = .display(display)
        }

        var config = RecordingConfiguration()
        if let fps = args["fps"]?.intValue { config.frameRate = fps }
        if let codec = args["codec"]?.stringValue, let vc = VideoCodec(rawValue: codec) {
            config.videoCodec = vc
        }
        if let format = args["format"]?.stringValue, let ff = FileFormat(rawValue: format) {
            config.fileFormat = ff
        }
        if let output = args["output"]?.stringValue {
            let url = URL(fileURLWithPath: output)
            config.outputDirectory = url.deletingLastPathComponent().path
            config.fileName = url.deletingPathExtension().lastPathComponent
        }

        try await recordingManager.startRecording(source: source, configuration: config)

        if let duration = args["duration"]?.intValue {
            Task {
                try await Task.sleep(for: .seconds(duration))
                _ = try await recordingManager.stopRecording()
            }
            return CallTool.Result(content: [.text("録画を開始しました（\(duration)秒後に自動停止）")])
        }

        return CallTool.Result(content: [.text("録画を開始しました。stop_recording で停止してください。")])
    }

    static func handleStopRecording() async throws -> CallTool.Result {
        let url = try await recordingManager.stopRecording()
        return CallTool.Result(content: [.text("録画を停止しました: \(url.path)")])
    }

    static func handleGetStatus() -> CallTool.Result {
        let state = recordingManager.state
        let statusText: String
        switch state {
        case .idle:
            statusText = "状態: 待機中"
        case .preparing:
            statusText = "状態: 準備中"
        case .recording(let startTime):
            let elapsed = Date().timeIntervalSince(startTime)
            statusText = "状態: 録画中（経過: \(Int(elapsed))秒）"
        case .paused(let elapsed):
            statusText = "状態: 一時停止（経過: \(Int(elapsed))秒）"
        case .stopping:
            statusText = "状態: 停止処理中"
        case .completed(let url):
            statusText = "状態: 完了（\(url.path)）"
        case .failed(let reason):
            statusText = "状態: エラー（\(reason)）"
        }
        return CallTool.Result(content: [.text(statusText)])
    }
}
