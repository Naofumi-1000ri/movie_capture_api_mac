import Foundation

/// PID ファイルと状態ファイルを管理するユーティリティ
enum ProcessState {
    static let pidFilePath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".moviecapture.pid").path
    static let stateFilePath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".moviecapture.state.json").path

    // MARK: - PID ファイル

    /// 現在のプロセス ID を PID ファイルに書き込む
    static func writePID() throws {
        let pid = ProcessInfo.processInfo.processIdentifier
        try "\(pid)".write(toFile: pidFilePath, atomically: true, encoding: .utf8)
    }

    /// PID ファイルを読み取る。ファイルが無い場合は nil
    static func readPID() -> pid_t? {
        guard let content = try? String(contentsOfFile: pidFilePath, encoding: .utf8),
              let pid = Int32(content.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        return pid
    }

    /// PID ファイルを削除する
    static func removePID() {
        try? FileManager.default.removeItem(atPath: pidFilePath)
    }

    /// 指定 PID のプロセスが生存しているか確認
    static func isProcessAlive(_ pid: pid_t) -> Bool {
        kill(pid, 0) == 0
    }

    // MARK: - 状態ファイル

    /// 状態情報
    struct StateInfo: Codable {
        let pid: Int32
        let status: String
        let source: String
        let startTime: Date
        let outputPath: String?

        var elapsedSeconds: Double {
            Date().timeIntervalSince(startTime)
        }
    }

    /// 状態ファイルを書き込む
    static func writeState(_ state: StateInfo) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: URL(fileURLWithPath: stateFilePath), options: .atomic)
    }

    /// 状態ファイルを読み取る。ファイルが無い場合は nil
    static func readState() -> StateInfo? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: stateFilePath)) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(StateInfo.self, from: data)
    }

    /// 状態ファイルを削除する
    static func removeState() {
        try? FileManager.default.removeItem(atPath: stateFilePath)
    }

    /// PID・状態ファイルをすべてクリーンアップ
    static func cleanup() {
        removePID()
        removeState()
    }
}
