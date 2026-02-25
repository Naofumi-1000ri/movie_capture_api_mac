import CoreGraphics
import Testing

@testable import CaptureEngine

@Suite("WindowInfo Tests")
struct WindowInfoTests {

    @Test("contentRectでデフォルトタイトルバー高さ28ptが除かれる")
    func contentRectDefault() {
        let window = WindowInfo(
            id: 1,
            title: "Test",
            ownerName: "App",
            frame: CGRect(x: 0, y: 0, width: 1200, height: 800),
            isOnScreen: true
        )
        let content = window.contentRect
        #expect(content.width == 1200)
        #expect(content.height == CGFloat(800 - 28))
        #expect(content.origin.x == 0)
        #expect(content.origin.y == 0)
    }

    @Test("カスタムタイトルバー高さでcontentRectが正しく計算される")
    func contentRectCustomTitleBarHeight() {
        let window = WindowInfo(
            id: 1,
            title: "Test",
            ownerName: "App",
            frame: CGRect(x: 0, y: 0, width: 1000, height: 600),
            isOnScreen: true
        )
        let content = window.contentRect(titleBarHeight: 50)
        #expect(content.width == 1000)
        #expect(content.height == 550)
    }

    @Test("タイトルバー高さがウィンドウ高さを超える場合はクランプされる")
    func contentRectClampsToWindowHeight() {
        let window = WindowInfo(
            id: 1,
            title: "Test",
            ownerName: "App",
            frame: CGRect(x: 0, y: 0, width: 400, height: 20),
            isOnScreen: true
        )
        let content = window.contentRect(titleBarHeight: 100)
        #expect(content.height == 0)
    }

    @Test("タイトルバー高さ0でcontentRectがframe全体と一致する")
    func contentRectZeroTitleBar() {
        let window = WindowInfo(
            id: 1,
            title: "Test",
            ownerName: "App",
            frame: CGRect(x: 50, y: 50, width: 800, height: 600),
            isOnScreen: true
        )
        let content = window.contentRect(titleBarHeight: 0)
        #expect(content.width == 800)
        #expect(content.height == 600)
    }
}
