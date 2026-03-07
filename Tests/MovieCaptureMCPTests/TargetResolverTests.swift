import CoreGraphics
import Testing

@testable import CaptureEngine
@testable import MovieCaptureMCP

@Suite("MCP Target Resolver Tests")
struct TargetResolverTests {
    private let sources = AvailableSources(
        displays: [
            DisplayInfo(id: 1, width: 2560, height: 1440, frame: CGRect(x: 0, y: 0, width: 2560, height: 1440)),
            DisplayInfo(id: 2, width: 1920, height: 1080, frame: CGRect(x: 2560, y: 0, width: 1920, height: 1080)),
        ],
        windows: [
            WindowInfo(
                id: 11,
                title: "Inbox - Gmail",
                ownerName: "Google Chrome",
                frame: CGRect(x: 10, y: 10, width: 1200, height: 800),
                isOnScreen: true
            ),
            WindowInfo(
                id: 12,
                title: "Docs - Proposal",
                ownerName: "Google Chrome",
                frame: CGRect(x: 40, y: 40, width: 1280, height: 900),
                isOnScreen: true
            ),
            WindowInfo(
                id: 21,
                title: "Terminal - Deploy",
                ownerName: "Terminal",
                frame: CGRect(x: 60, y: 60, width: 900, height: 600),
                isOnScreen: false
            ),
        ]
    )

    @Test("対象未指定ならメインディスプレイに解決する")
    func resolveDefaultDisplay() throws {
        let resolution = try TargetResolver.resolve(
            query: ResolveTargetQuery(),
            in: sources
        )

        switch resolution {
        case .resolved(let target, let strategy, let defaulted):
            #expect(strategy == .defaultDisplay)
            #expect(defaulted == true)
            #expect(target.payload.displayId == 1)
            #expect(target.payload.recordingArguments.displayId == 1)
        default:
            Issue.record("Expected default display resolution")
        }
    }

    @Test("app一致が複数あれば ambiguous を返す")
    func ambiguousAppMatch() throws {
        let resolution = try TargetResolver.resolve(
            query: ResolveTargetQuery(app: "Chrome"),
            in: sources
        )

        switch resolution {
        case .ambiguous(let candidates, let strategy, let message):
            #expect(strategy == .app)
            #expect(candidates.count == 2)
            #expect(message.contains("window_id"))
        default:
            Issue.record("Expected ambiguous app resolution")
        }
    }

    @Test("app と window を組み合わせると一意解決できる")
    func combinedAppAndWindowFiltersResolveUniquely() throws {
        let resolution = try TargetResolver.resolve(
            query: ResolveTargetQuery(app: "Chrome", window: "Proposal", contentOnly: true),
            in: sources
        )

        switch resolution {
        case .resolved(let target, let strategy, let defaulted):
            #expect(strategy == .appAndWindow)
            #expect(defaulted == false)
            #expect(target.payload.windowId == 12)
            #expect(target.payload.captureMode == "window_content_only")
            #expect(target.payload.recordingArguments.contentOnly == true)
        default:
            Issue.record("Expected unique resolution for app+window")
        }
    }

    @Test("on_screen_only=false ならオフスクリーンの window_id も解決できる")
    func resolveOffscreenWindowWhenAllowed() throws {
        let resolution = try TargetResolver.resolve(
            query: ResolveTargetQuery(windowId: 21, onScreenOnly: false),
            in: sources
        )

        switch resolution {
        case .resolved(let target, let strategy, _):
            #expect(strategy == .windowId)
            #expect(target.payload.windowId == 21)
            #expect(target.payload.isOnScreen == false)
        default:
            Issue.record("Expected off-screen window resolution")
        }
    }

    @Test("content_only と display_id の併用は invalid_configuration")
    func contentOnlyCannotBeCombinedWithDisplay() {
        #expect(throws: CaptureError.invalidConfiguration([
            "content_only は display_id と組み合わせられません",
        ])) {
            _ = try TargetResolver.resolve(
                query: ResolveTargetQuery(displayId: 1, contentOnly: true),
                in: sources
            )
        }
    }
}
