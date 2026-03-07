import ArgumentParser
import Testing

@testable import MovieCaptureCLI

@Suite("CLI Validation Tests")
struct CLITests {

    @Test("複数のソース指定は拒否される")
    func conflictingSourceSelectors() {
        #expect(throws: ValidationError.self) {
            let command = try RecordCommand.parseAsRoot(["--display", "1", "--app", "Chrome"]) as! RecordCommand
            try command.validateArguments()
        }
    }

    @Test("--content-only はウィンドウ系指定が必要")
    func contentOnlyRequiresWindowSource() {
        #expect(throws: ValidationError.self) {
            let command = try RecordCommand.parseAsRoot(["--content-only"]) as! RecordCommand
            try command.validateArguments()
        }
    }

    @Test("--duration は正の整数のみ受け付ける")
    func durationMustBePositive() {
        #expect(throws: ValidationError.self) {
            let command = try RecordCommand.parseAsRoot(["--duration", "0"]) as! RecordCommand
            try command.validateArguments()
        }
    }

    @Test("単一ソース指定と正の duration は受理される")
    func acceptsValidArguments() throws {
        let command = try RecordCommand.parseAsRoot(["--window-id", "1234", "--content-only", "--duration", "5"]) as! RecordCommand
        try command.validateArguments()
    }
}
