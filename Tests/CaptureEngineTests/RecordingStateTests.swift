import Foundation
import Testing

@testable import CaptureEngine

@Suite("RecordingState Tests")
struct RecordingStateTests {

    @Test("idle は非アクティブ")
    func idleIsNotActive() {
        let state = RecordingState.idle
        #expect(!state.isActive)
        #expect(!state.isRecording)
        #expect(!state.isPaused)
    }

    @Test("recording はアクティブかつ録画中")
    func recordingIsActive() {
        let state = RecordingState.recording(startTime: Date())
        #expect(state.isActive)
        #expect(state.isRecording)
        #expect(!state.isPaused)
    }

    @Test("paused はアクティブだが録画中でない")
    func pausedIsActiveButNotRecording() {
        let state = RecordingState.paused(elapsed: 10.0)
        #expect(state.isActive)
        #expect(!state.isRecording)
        #expect(state.isPaused)
    }

    @Test("preparing はアクティブ")
    func preparingIsActive() {
        let state = RecordingState.preparing
        #expect(state.isActive)
    }

    @Test("stopping はアクティブ")
    func stoppingIsActive() {
        let state = RecordingState.stopping
        #expect(state.isActive)
    }

    @Test("completed は非アクティブ")
    func completedIsNotActive() {
        let state = RecordingState.completed(fileURL: URL(fileURLWithPath: "/tmp/test.mov"))
        #expect(!state.isActive)
    }

    @Test("failed は非アクティブ")
    func failedIsNotActive() {
        let state = RecordingState.failed("error")
        #expect(!state.isActive)
    }
}
