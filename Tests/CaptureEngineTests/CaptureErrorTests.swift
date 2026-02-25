import Testing

@testable import CaptureEngine

@Suite("CaptureError Tests")
struct CaptureErrorTests {

    @Test("各エラーにローカライズされた説明がある")
    func allErrorsHaveDescriptions() {
        let errors: [CaptureError] = [
            .screenCaptureNotAuthorized,
            .microphoneNotAuthorized,
            .noDisplayFound,
            .windowNotFound("Chrome"),
            .alreadyRecording,
            .notRecording,
            .invalidConfiguration(["error1", "error2"]),
            .outputDirectoryNotWritable("/invalid/path"),
            .recordingFailed("test reason"),
        ]

        for error in errors {
            #expect(error.errorDescription != nil, "Missing description for \(error)")
            #expect(!error.errorDescription!.isEmpty, "Empty description for \(error)")
        }
    }

    @Test("windowNotFoundにウィンドウ名が含まれる")
    func windowNotFoundContainsName() {
        let error = CaptureError.windowNotFound("My Window")
        #expect(error.errorDescription!.contains("My Window"))
    }

    @Test("invalidConfigurationにエラーメッセージが含まれる")
    func invalidConfigurationContainsErrors() {
        let error = CaptureError.invalidConfiguration(["bad fps", "bad codec"])
        #expect(error.errorDescription!.contains("bad fps"))
        #expect(error.errorDescription!.contains("bad codec"))
    }

    @Test("Equatableが正しく動作する")
    func equatable() {
        #expect(CaptureError.screenCaptureNotAuthorized == CaptureError.screenCaptureNotAuthorized)
        #expect(CaptureError.windowNotFound("A") == CaptureError.windowNotFound("A"))
        #expect(CaptureError.windowNotFound("A") != CaptureError.windowNotFound("B"))
        #expect(CaptureError.alreadyRecording != CaptureError.notRecording)
    }
}
