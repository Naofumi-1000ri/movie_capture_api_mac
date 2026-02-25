import CoreGraphics
import Testing

@testable import CaptureEngine

@Suite("AvailableSources Tests")
struct AvailableSourcesTests {
    let sources = AvailableSources(
        displays: [
            DisplayInfo(id: 1, width: 2560, height: 1440, frame: CGRect(x: 0, y: 0, width: 2560, height: 1440)),
        ],
        windows: [
            WindowInfo(id: 100, title: "Google Chrome - GitHub", ownerName: "Google Chrome",
                       frame: CGRect(x: 0, y: 0, width: 1200, height: 800), isOnScreen: true),
            WindowInfo(id: 101, title: "Terminal", ownerName: "Terminal",
                       frame: CGRect(x: 0, y: 0, width: 800, height: 600), isOnScreen: true),
            WindowInfo(id: 102, title: "Hidden Window", ownerName: "Google Chrome",
                       frame: CGRect(x: 0, y: 0, width: 400, height: 300), isOnScreen: false),
        ]
    )

    @Test("アプリ名でウィンドウをフィルタ")
    func windowsOwnedBy() {
        let chromeWindows = sources.windows(ownedBy: "Chrome")
        #expect(chromeWindows.count == 2)
        for w in chromeWindows {
            #expect(w.ownerName == "Google Chrome")
        }
    }

    @Test("アプリ名フィルタは大文字小文字を無視")
    func windowsOwnedByCaseInsensitive() {
        let windows = sources.windows(ownedBy: "chrome")
        #expect(windows.count == 2)
    }

    @Test("タイトルでウィンドウを検索")
    func windowsTitled() {
        let windows = sources.windows(titled: "GitHub")
        #expect(windows.count == 1)
        #expect(windows.first?.id == 100)
    }

    @Test("タイトル検索は大文字小文字を無視")
    func windowsTitledCaseInsensitive() {
        let windows = sources.windows(titled: "github")
        #expect(windows.count == 1)
    }

    @Test("オンスクリーンのウィンドウのみ")
    func onScreenWindows() {
        let onScreen = sources.onScreenWindows
        #expect(onScreen.count == 2)
        for w in onScreen {
            #expect(w.isOnScreen)
        }
    }

    @Test("マッチしないフィルタは空を返す")
    func noMatch() {
        #expect(sources.windows(ownedBy: "Firefox").isEmpty)
        #expect(sources.windows(titled: "NotExist").isEmpty)
    }
}
