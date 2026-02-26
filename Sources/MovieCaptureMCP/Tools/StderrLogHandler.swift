import Foundation
import Logging

/// stderrにログを出力するLogHandler
struct StderrLogHandler: LogHandler {
    var logLevel: Logger.Level = .debug
    var metadata: Logger.Metadata = [:]

    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        FileHandle.standardError.write("[\(level)] \(message)\n".data(using: .utf8)!)
    }
}
