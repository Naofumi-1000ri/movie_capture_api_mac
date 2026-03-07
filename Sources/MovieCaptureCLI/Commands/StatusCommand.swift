import ArgumentParser
import Foundation

struct StatusCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "録画の状態を確認",
        discussion: """
        現在の録画状態を表示します。
        別ターミナルで実行中の moviecapture record の状態を確認できます。

        例:
          moviecapture status         # テキスト形式で状態表示
          moviecapture status --json  # JSON 形式で状態表示
        """
    )

    @Flag(name: .long, help: "JSON 形式で出力")
    var json: Bool = false

    mutating func run() async throws {
        // PID ファイルの確認
        guard let pid = ProcessState.readPID() else {
            if json {
                printJSON(status: "idle")
            } else {
                print("録画していません")
            }
            return
        }

        // プロセス生存確認
        guard ProcessState.isProcessAlive(pid) else {
            // プロセスが死んでいる場合はクリーンアップ
            ProcessState.cleanup()
            if json {
                printJSON(status: "idle")
            } else {
                print("録画していません（古い状態ファイルをクリーンアップしました）")
            }
            return
        }

        // 状態ファイルの読み取り
        if let state = ProcessState.readState() {
            let elapsed = Int(state.elapsedSeconds)
            if json {
                printJSON(
                    status: state.status,
                    pid: Int(state.pid),
                    source: state.source,
                    elapsed: state.elapsedSeconds,
                    outputPath: state.outputPath
                )
            } else {
                print("録画中（経過: \(elapsed)秒）")
                print("  ソース: \(state.source)")
                print("  PID: \(state.pid)")
                if let outputPath = state.outputPath {
                    print("  出力先: \(outputPath)")
                }
            }
        } else {
            if json {
                printJSON(status: "recording", pid: Int(pid))
            } else {
                print("録画中（PID: \(pid)）")
            }
        }
    }

    private func printJSON(
        status: String,
        pid: Int? = nil,
        source: String? = nil,
        elapsed: Double? = nil,
        outputPath: String? = nil
    ) {
        var dict: [String: Any] = ["status": status]
        if let pid = pid { dict["pid"] = pid }
        if let source = source { dict["source"] = source }
        if let elapsed = elapsed { dict["elapsed"] = (elapsed * 100).rounded() / 100 }
        if let outputPath = outputPath { dict["outputPath"] = outputPath }
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
           let str = String(data: data, encoding: .utf8) {
            print(str)
        }
    }
}
