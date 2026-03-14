import Foundation
import OSLog

// MARK: - LogLine

/// A single parsed line from a Docker multiplexed log stream.
struct LogLine: Identifiable, Sendable {
    let id: UUID
    let source: Source
    let text: String
    /// RFC 3339 timestamp prefix, present only when `timestamps=true` was requested.
    let timestamp: String?

    enum Source: Sendable { case stdout, stderr }

    init(source: Source, text: String) {
        self.id = UUID()
        self.source = source
        // Docker timestamps are prefixed to the line text separated by a space.
        // e.g. "2024-01-15T10:30:00.123456789Z some log text"
        if let spaceIndex = text.firstIndex(of: " ") {
            let candidate = String(text[..<spaceIndex])
            // A timestamp will contain 'T' and 'Z' — use that as a quick heuristic.
            if candidate.contains("T") && (candidate.hasSuffix("Z") || candidate.contains("+")) {
                self.timestamp = candidate
                self.text = String(text[text.index(after: spaceIndex)...])
                return
            }
        }
        self.timestamp = nil
        self.text = text
    }
}

// MARK: - LogStreamService

/// Parses the Docker multiplexed stream format and delivers individual `LogLine` values.
///
/// Docker wraps log output in 8-byte frames:
/// - Byte 0: stream type (1 = stdout, 2 = stderr, 0 = stdin — ignored)
/// - Bytes 1–3: zero padding
/// - Bytes 4–7: payload length (big-endian UInt32)
/// - Bytes 8…: payload (UTF-8 text, may contain embedded newlines)
///
/// Some Docker configurations (e.g. TTY mode) write raw bytes with no frame headers.
/// `LogStreamService` detects this case and falls back to line-based parsing.
final class LogStreamService: Sendable {

    private let logger = Logger(subsystem: "com.snailengineering.swift.Portasaurus", category: "LogStream")

    // MARK: - Snapshot

    /// Parses a complete log snapshot (non-streaming) into an array of `LogLine`.
    func parse(snapshotData: Data) -> [LogLine] {
        if looksMultiplexed(snapshotData) {
            return parseMultiplexed(snapshotData)
        } else {
            return parseRaw(snapshotData, source: .stdout)
        }
    }

    // MARK: - Streaming

    /// Returns an `AsyncThrowingStream` that parses Docker log chunks from a live
    /// `PortainerClient` log stream and yields individual `LogLine` values.
    func stream(chunks: AsyncThrowingStream<Data, Error>) -> AsyncThrowingStream<LogLine, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                // Carry partial frames across chunk boundaries.
                var remainder = Data()
                var detectedMultiplexed: Bool? = nil

                do {
                    for try await chunk in chunks {
                        remainder.append(chunk)

                        // Detect the stream format from the first chunk.
                        if detectedMultiplexed == nil {
                            detectedMultiplexed = looksMultiplexed(remainder)
                        }

                        if detectedMultiplexed == true {
                            // Drain complete multiplexed frames from `remainder`.
                            remainder = drainMultiplexedFrames(from: remainder) { line in
                                continuation.yield(line)
                            }
                        } else {
                            // Raw / TTY mode — split on newlines.
                            remainder = drainLines(from: remainder, source: .stdout) { line in
                                continuation.yield(line)
                            }
                        }
                    }

                    // Flush any remaining bytes (incomplete final line without trailing newline).
                    if !remainder.isEmpty {
                        let text = String(decoding: remainder, as: UTF8.self).trimmingCharacters(in: .newlines)
                        if !text.isEmpty {
                            let source: LogLine.Source = (detectedMultiplexed == true) ? .stdout : .stdout
                            continuation.yield(LogLine(source: source, text: text))
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Multiplexed frame parsing

    /// Returns `true` if the data starts with a valid Docker multiplexed frame header.
    private func looksMultiplexed(_ data: Data) -> Bool {
        guard data.count >= 8 else { return false }
        let streamType = data[data.startIndex]
        // Stream types: 0 = stdin, 1 = stdout, 2 = stderr. Anything else → raw.
        guard streamType == 0 || streamType == 1 || streamType == 2 else { return false }
        // Padding bytes should be zero.
        return data[data.startIndex + 1] == 0 &&
               data[data.startIndex + 2] == 0 &&
               data[data.startIndex + 3] == 0
    }

    /// Drains complete multiplexed frames from `data`, calling `emit` for each line.
    /// Returns remaining bytes that don't form a complete frame yet.
    private func drainMultiplexedFrames(from data: Data, emit: (LogLine) -> Void) -> Data {
        var offset = data.startIndex

        while data.distance(from: offset, to: data.endIndex) >= 8 {
            let streamType = data[offset]
            // Bytes 4–7: payload length (big-endian).
            let payloadLength = Int(
                UInt32(data[offset + 4]) << 24 |
                UInt32(data[offset + 5]) << 16 |
                UInt32(data[offset + 6]) << 8  |
                UInt32(data[offset + 7])
            )

            let frameEnd = offset + 8 + payloadLength
            guard frameEnd <= data.endIndex else { break } // Incomplete frame — wait for more data.

            let payload = data[offset + 8 ..< frameEnd]

            let source: LogLine.Source = (streamType == 2) ? .stderr : .stdout
            let text = String(decoding: payload, as: UTF8.self)

            // A single frame may contain multiple newline-terminated lines.
            for rawLine in text.components(separatedBy: "\n") {
                let trimmed = rawLine.trimmingCharacters(in: .init(charactersIn: "\r"))
                if !trimmed.isEmpty {
                    emit(LogLine(source: source, text: trimmed))
                }
            }

            offset = frameEnd
        }

        return Data(data[offset...])
    }

    // MARK: - Raw (TTY) line parsing

    private func drainLines(from data: Data, source: LogLine.Source, emit: (LogLine) -> Void) -> Data {
        var remainder = data
        while let newlineRange = remainder.range(of: Data([0x0A])) { // 0x0A = '\n'
            let lineData = remainder[remainder.startIndex ..< newlineRange.lowerBound]
            let text = String(decoding: lineData, as: UTF8.self)
                .trimmingCharacters(in: .init(charactersIn: "\r"))
            if !text.isEmpty { emit(LogLine(source: source, text: text)) }
            remainder = Data(remainder[newlineRange.upperBound...])
        }
        return remainder
    }

    private func parseMultiplexed(_ data: Data) -> [LogLine] {
        var lines: [LogLine] = []
        _ = drainMultiplexedFrames(from: data) { lines.append($0) }
        return lines
    }

    private func parseRaw(_ data: Data, source: LogLine.Source) -> [LogLine] {
        var lines: [LogLine] = []
        _ = drainLines(from: data, source: source) { lines.append($0) }
        return lines
    }
}
