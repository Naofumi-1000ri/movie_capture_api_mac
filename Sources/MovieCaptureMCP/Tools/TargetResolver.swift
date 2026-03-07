import CaptureEngine
import Foundation

struct ResolveTargetQuery: Equatable, Sendable {
    let displayId: Int?
    let windowId: Int?
    let app: String?
    let window: String?
    let onScreenOnly: Bool
    let contentOnly: Bool

    init(
        displayId: Int? = nil,
        windowId: Int? = nil,
        app: String? = nil,
        window: String? = nil,
        onScreenOnly: Bool = true,
        contentOnly: Bool = false
    ) {
        self.displayId = displayId
        self.windowId = windowId
        self.app = Self.normalize(app)
        self.window = Self.normalize(window)
        self.onScreenOnly = onScreenOnly
        self.contentOnly = contentOnly
    }

    var payload: MCPResolveTargetQueryPayload {
        MCPResolveTargetQueryPayload(
            displayId: displayId,
            windowId: windowId,
            app: app,
            window: window,
            onScreenOnly: onScreenOnly,
            contentOnly: contentOnly
        )
    }

    func validate(allowDefaultDisplay: Bool = true) -> [String] {
        var errors: [String] = []

        if let displayId, displayId < 0 {
            errors.append("display_id は 0 以上の整数を指定してください")
        }
        if let windowId, windowId < 0 {
            errors.append("window_id は 0 以上の整数を指定してください")
        }

        if displayId != nil && (windowId != nil || app != nil || window != nil) {
            errors.append("display_id は window_id / app / window と同時指定できません")
        }
        if windowId != nil && (app != nil || window != nil) {
            errors.append("window_id は app / window と同時指定できません")
        }
        if contentOnly {
            if displayId != nil {
                errors.append("content_only は display_id と組み合わせられません")
            } else if windowId == nil && app == nil && window == nil {
                errors.append("content_only は window_id / app / window のいずれかと組み合わせてください")
            }
        }
        if !allowDefaultDisplay && displayId == nil && windowId == nil && app == nil && window == nil {
            errors.append("display_id / window_id / app / window のいずれかを指定してください")
        }

        return errors
    }

    private static func normalize(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

enum ResolveMatchStrategy: String, Equatable, Sendable {
    case defaultDisplay = "default_display"
    case displayId = "display_id"
    case windowId = "window_id"
    case app = "app"
    case windowTitle = "window"
    case appAndWindow = "app_and_window"
}

struct ResolvedCaptureTarget: Equatable, Sendable {
    let source: CaptureSource
    let payload: MCPTargetPayload
}

enum TargetResolution: Equatable, Sendable {
    case resolved(ResolvedCaptureTarget, strategy: ResolveMatchStrategy, defaultedToMainDisplay: Bool)
    case ambiguous([MCPTargetPayload], strategy: ResolveMatchStrategy, message: String)
    case notFound(strategy: ResolveMatchStrategy, message: String)

    var responseStatus: String {
        switch self {
        case .resolved:
            return "resolved"
        case .ambiguous:
            return "ambiguous"
        case .notFound:
            return "not_found"
        }
    }

    var responseMessage: String {
        switch self {
        case .resolved(_, _, let defaultedToMainDisplay):
            return defaultedToMainDisplay
                ? "対象未指定のためメインディスプレイを選択しました。"
                : "録画対象を一意に解決しました。"
        case .ambiguous(_, _, let message), .notFound(_, let message):
            return message
        }
    }

    var queryCandidates: [MCPTargetPayload] {
        switch self {
        case .resolved(let target, _, _):
            return [target.payload]
        case .ambiguous(let candidates, _, _):
            return candidates
        case .notFound:
            return []
        }
    }
}

enum TargetResolver {
    static func resolve(
        query: ResolveTargetQuery,
        in sources: AvailableSources,
        allowDefaultDisplay: Bool = true
    ) throws -> TargetResolution {
        let errors = query.validate(allowDefaultDisplay: allowDefaultDisplay)
        guard errors.isEmpty else {
            throw CaptureError.invalidConfiguration(errors)
        }

        if let displayId = query.displayId {
            return resolveDisplay(id: displayId, in: sources)
        }

        if let windowId = query.windowId {
            return resolveWindow(id: windowId, query: query, in: sources)
        }

        if query.app != nil || query.window != nil {
            return resolveWindowFilters(query: query, in: sources)
        }

        guard allowDefaultDisplay else {
            return .notFound(strategy: .defaultDisplay, message: "録画対象が指定されていません。")
        }
        guard let display = sources.displays.first else {
            throw CaptureError.noDisplayFound
        }
        let target = ResolvedCaptureTarget(
            source: .display(display),
            payload: MCPTargetPayload(display: display, isMainDisplay: true, matchedBy: ResolveMatchStrategy.defaultDisplay.rawValue)
        )
        return .resolved(target, strategy: .defaultDisplay, defaultedToMainDisplay: true)
    }

    private static func resolveDisplay(id: Int, in sources: AvailableSources) -> TargetResolution {
        guard let display = sources.displays.first(where: { Int($0.id) == id }) else {
            return .notFound(strategy: .displayId, message: "display_id=\(id) に一致するディスプレイが見つかりません。")
        }

        let target = ResolvedCaptureTarget(
            source: .display(display),
            payload: MCPTargetPayload(
                display: display,
                isMainDisplay: sources.displays.first?.id == display.id,
                matchedBy: ResolveMatchStrategy.displayId.rawValue
            )
        )
        return .resolved(target, strategy: .displayId, defaultedToMainDisplay: false)
    }

    private static func resolveWindow(id: Int, query: ResolveTargetQuery, in sources: AvailableSources) -> TargetResolution {
        var windows = sources.windows.filter { Int($0.id) == id }
        if query.onScreenOnly {
            windows = windows.filter(\.isOnScreen)
        }

        guard let window = windows.first else {
            let visibilityMessage = query.onScreenOnly ? "（on_screen_only=true）" : ""
            return .notFound(
                strategy: .windowId,
                message: "window_id=\(id) に一致するウィンドウが見つかりません\(visibilityMessage)。"
            )
        }

        let target = ResolvedCaptureTarget(
            source: query.contentOnly ? .windowContentOnly(window) : .window(window),
            payload: MCPTargetPayload(
                window: window,
                contentOnly: query.contentOnly,
                matchedBy: ResolveMatchStrategy.windowId.rawValue
            )
        )
        return .resolved(target, strategy: .windowId, defaultedToMainDisplay: false)
    }

    private static func resolveWindowFilters(query: ResolveTargetQuery, in sources: AvailableSources) -> TargetResolution {
        var windows = query.onScreenOnly ? sources.onScreenWindows : sources.windows

        if let app = query.app {
            windows = windows.filter { $0.ownerName?.localizedCaseInsensitiveContains(app) == true }
        }
        if let window = query.window {
            windows = windows.filter { $0.title?.localizedCaseInsensitiveContains(window) == true }
        }

        windows.sort(by: compareWindows)

        let strategy = strategy(for: query)
        let candidates = windows.map {
            MCPTargetPayload(window: $0, contentOnly: query.contentOnly, matchedBy: strategy.rawValue)
        }

        switch candidates.count {
        case 0:
            return .notFound(strategy: strategy, message: notFoundMessage(for: query))
        case 1:
            let window = windows[0]
            let target = ResolvedCaptureTarget(
                source: query.contentOnly ? .windowContentOnly(window) : .window(window),
                payload: candidates[0]
            )
            return .resolved(target, strategy: strategy, defaultedToMainDisplay: false)
        default:
            return .ambiguous(candidates, strategy: strategy, message: ambiguousMessage(for: query, count: candidates.count))
        }
    }

    private static func strategy(for query: ResolveTargetQuery) -> ResolveMatchStrategy {
        if query.app != nil && query.window != nil {
            return .appAndWindow
        }
        if query.app != nil {
            return .app
        }
        return .windowTitle
    }

    private static func compareWindows(lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        let lhsOwner = lhs.ownerName?.localizedLowercase ?? ""
        let rhsOwner = rhs.ownerName?.localizedLowercase ?? ""
        if lhsOwner != rhsOwner { return lhsOwner < rhsOwner }

        let lhsTitle = lhs.title?.localizedLowercase ?? ""
        let rhsTitle = rhs.title?.localizedLowercase ?? ""
        if lhsTitle != rhsTitle { return lhsTitle < rhsTitle }

        return lhs.id < rhs.id
    }

    private static func ambiguousMessage(for query: ResolveTargetQuery, count: Int) -> String {
        switch strategy(for: query) {
        case .app:
            return "app=\"\(query.app!)\" に一致するウィンドウが \(count) 件あります。window_id を指定して絞り込んでください。"
        case .windowTitle:
            return "window=\"\(query.window!)\" に一致するウィンドウが \(count) 件あります。window_id を指定して絞り込んでください。"
        case .appAndWindow:
            return "app=\"\(query.app!)\" かつ window=\"\(query.window!)\" に一致するウィンドウが \(count) 件あります。window_id を指定して絞り込んでください。"
        case .defaultDisplay, .displayId, .windowId:
            return "録画対象が複数見つかりました。"
        }
    }

    private static func notFoundMessage(for query: ResolveTargetQuery) -> String {
        let visibility = query.onScreenOnly ? "（on_screen_only=true）" : ""
        switch strategy(for: query) {
        case .app:
            return "app=\"\(query.app!)\" に一致するウィンドウが見つかりません\(visibility)。"
        case .windowTitle:
            return "window=\"\(query.window!)\" に一致するウィンドウが見つかりません\(visibility)。"
        case .appAndWindow:
            return "app=\"\(query.app!)\" かつ window=\"\(query.window!)\" に一致するウィンドウが見つかりません\(visibility)。"
        case .defaultDisplay, .displayId, .windowId:
            return "録画対象が見つかりません。"
        }
    }
}
