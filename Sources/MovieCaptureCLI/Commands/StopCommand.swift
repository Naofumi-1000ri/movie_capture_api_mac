import ArgumentParser
import Foundation

struct StopCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "stop",
        abstract: "実行中の録画を停止",
        discussion: """
        別ターミナルで実行中の moviecapture record を停止します。
        SIGINT シグナルを送信して安全に録画を終了させます。

        例:
          moviecapture stop         # 録画を停止
          moviecapture stop --json  # JSON 形式で結果を出力
        """
    )

    @Flag(name: .long, help: "JSON 形式で出力")
    var json: Bool = false

    mutating func run() async throws {
        guard let pid = ProcessState.readPID() else {
            if json {
                printJSON(status: "error", message: "録画プロセスが見つかりません")
            } else {
                print("録画プロセスが見つかりません")
            }
            throw ExitCode.failure
        }

        guard ProcessState.isProcessAlive(pid) else {
            ProcessState.cleanup()
            if json {
                printJSON(status: "error", message: "録画プロセスは既に終了しています")
            } else {
                print("録画プロセスは既に終了しています（クリーンアップしました）")
            }
            throw ExitCode.failure
        }

        // SIGINT を送信
        kill(pid, SIGINT)

        if json {
            printJSON(status: "stopped", message: "録画停止シグナルを送信しました（PID: \(pid)）")
        } else {
            print("録画停止シグナルを送信しました（PID: \(pid)）")
        }
    }

    private func printJSON(status: String, message: String) {
        let dict: [String: Any] = ["status": status, "message": message]
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
           let str = String(data: data, encoding: .utf8) {
            print(str)
        }
    }
}
