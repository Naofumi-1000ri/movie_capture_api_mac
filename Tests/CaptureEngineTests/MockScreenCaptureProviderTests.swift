import Testing

@testable import CaptureEngine

@Suite("MockScreenCaptureProvider Tests")
struct MockScreenCaptureProviderTests {

    @Test("デフォルトソースが正しく構成されている")
    func defaultSources() async throws {
        let mock = MockScreenCaptureProvider()
        let sources = try await mock.availableSources()

        #expect(sources.displays.count == 1)
        #expect(sources.windows.count == 3)
        #expect(sources.onScreenWindows.count == 2)
    }

    @Test("呼び出し回数がカウントされる")
    func callCounting() async throws {
        let mock = MockScreenCaptureProvider()
        #expect(mock.availableSourcesCallCount == 0)
        #expect(mock.captureStillImageCallCount == 0)

        _ = try await mock.availableSources()
        #expect(mock.availableSourcesCallCount == 1)

        _ = try await mock.availableSources()
        #expect(mock.availableSourcesCallCount == 2)

        _ = try await mock.captureStillImage(source: .display(mock.stubbedSources.displays[0]), maxDimension: 1200)
        #expect(mock.captureStillImageCallCount == 1)
    }

    @Test("エラーをスタブできる")
    func stubbedError() async {
        let mock = MockScreenCaptureProvider()
        mock.shouldThrowError = .screenCaptureNotAuthorized

        do {
            _ = try await mock.availableSources()
            Issue.record("Expected error")
        } catch {
            #expect(error as? CaptureError == .screenCaptureNotAuthorized)
        }
    }
}
