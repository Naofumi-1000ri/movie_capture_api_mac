import ArgumentParser

@main
struct MovieCaptureCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "moviecapture",
        abstract: "Mac画面録画ツール",
        version: "0.1.0",
        subcommands: [
            ListCommand.self,
            RecordCommand.self,
            ConfigCommand.self,
        ]
    )
}
