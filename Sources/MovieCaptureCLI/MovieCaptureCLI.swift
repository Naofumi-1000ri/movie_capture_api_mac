import ArgumentParser

@main
struct MovieCaptureCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "moviecapture",
        abstract: "Mac画面録画ツール",
        discussion: """
        ディスプレイやウィンドウを録画するコマンドラインツールです。
        --json フラグを付けると全コマンドで機械可読な JSON を出力します。
        timed recording 中でも Ctrl+C や moviecapture stop で安全に停止できます。

        基本的な使い方:
          moviecapture list                          # 利用可能なソース一覧
          moviecapture record --app Chrome --duration 5  # Chrome を5秒録画
          moviecapture config show --json           # 設定を JSON で確認
          moviecapture status                        # 録画状態を確認
          moviecapture stop                          # 録画を停止
        """,
        version: "0.2.0",
        subcommands: [
            ListCommand.self,
            RecordCommand.self,
            ConfigCommand.self,
            StatusCommand.self,
            StopCommand.self,
        ]
    )
}
