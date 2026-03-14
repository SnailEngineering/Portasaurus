import Foundation
import OSLog
#if os(macOS)
import AppKit
#else
import UIKit
#endif

@Observable
final class ContainerLogsViewModel {

    // MARK: - Configuration

    /// Whether to include stdout lines.
    var showStdout: Bool = true
    /// Whether to include stderr lines.
    var showStderr: Bool = true
    /// Whether to show timestamps on each line.
    var showTimestamps: Bool = false
    /// Maximum number of historical lines fetched on load / when streaming starts.
    var tailLines: Int = 200
    /// Whether the live log stream is active.
    var isFollowing: Bool = false
    /// Text the user is searching within the displayed log.
    var searchText: String = ""

    // MARK: - State

    private(set) var lines: [LogLine] = []
    private(set) var isLoading: Bool = false
    var loadError: String?

    // MARK: - Private

    private let service = LogStreamService()
    private var streamTask: Task<Void, Never>?

    // MARK: - Computed

    /// Lines filtered by source toggles and the search string.
    var displayedLines: [LogLine] {
        let sourceFiltered = lines.filter { line in
            switch line.source {
            case .stdout: return showStdout
            case .stderr: return showStderr
            }
        }
        guard !searchText.isEmpty else { return sourceFiltered }
        return sourceFiltered.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
    }

    // MARK: - Init

    init() {}

    /// Preview-only initializer.
    init(previewLines: [LogLine]) {
        self.lines = previewLines
    }

    // MARK: - Actions

    /// Fetches a log snapshot and optionally starts the live stream.
    func load(client: PortainerClient, containerId: String, endpointId: Int) async {
        stopStream()
        lines = []
        loadError = nil
        isLoading = true
        defer { isLoading = false }

        AppLogger.viewModel.info("Loading logs for container \(containerId, privacy: .public) (tail: \(self.tailLines))")

        do {
            let data = try await client.containerLogsSnapshot(
                id: containerId,
                endpointId: endpointId,
                stdout: true,
                stderr: true,
                timestamps: showTimestamps,
                tail: tailLines
            )
            lines = service.parse(snapshotData: data)
            AppLogger.viewModel.info("Loaded \(self.lines.count, privacy: .public) log lines")
        } catch {
            AppLogger.viewModel.error("Failed to load logs: \(error.localizedDescription, privacy: .public)")
            loadError = error.localizedDescription
        }

        if isFollowing {
            startStream(client: client, containerId: containerId, endpointId: endpointId)
        }
    }

    /// Toggles live log streaming on or off.
    func toggleFollow(client: PortainerClient, containerId: String, endpointId: Int) {
        isFollowing.toggle()
        if isFollowing {
            startStream(client: client, containerId: containerId, endpointId: endpointId)
        } else {
            stopStream()
        }
    }

    /// Reloads logs with current settings (called after settings changes).
    func reload(client: PortainerClient, containerId: String, endpointId: Int) async {
        await load(client: client, containerId: containerId, endpointId: endpointId)
    }

    /// Copies all currently-displayed log lines to the system clipboard.
    func copyToClipboard() {
        let text = displayedLines.map { line -> String in
            if showTimestamps, let ts = line.timestamp {
                return "\(ts) \(line.text)"
            }
            return line.text
        }.joined(separator: "\n")

        copyTextToPasteboard(text)
    }

    // MARK: - Stream Management

    private func startStream(client: PortainerClient, containerId: String, endpointId: Int) {
        stopStream()
        AppLogger.viewModel.info("Starting log stream for \(containerId, privacy: .public)")
        let chunks = client.containerLogsStream(
            id: containerId,
            endpointId: endpointId,
            stdout: true,
            stderr: true,
            timestamps: showTimestamps,
            tail: 0 // tail=0 with follow=1 means "only new lines"
        )
        let parsedStream = service.stream(chunks: chunks)
        streamTask = Task {
            do {
                for try await line in parsedStream {
                    lines.append(line)
                }
            } catch {
                // Stream ended — could be network loss or container stop.
                AppLogger.viewModel.info("Log stream ended: \(error.localizedDescription, privacy: .public)")
                isFollowing = false
            }
        }
    }

    func stopStream() {
        streamTask?.cancel()
        streamTask = nil
    }

    deinit {
        streamTask?.cancel()
    }
}

// MARK: - Platform clipboard helper

private func copyTextToPasteboard(_ text: String) {
#if os(macOS)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
#else
    UIPasteboard.general.string = text
#endif
}
