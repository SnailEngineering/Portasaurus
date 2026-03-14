import SwiftUI

/// Displays and streams log output for a single container.
///
/// Features:
/// - Scrollable, selectable log area with monospace font
/// - Auto-scroll to bottom (pauses when user scrolls up)
/// - Live streaming toggle (follow mode)
/// - stdout / stderr source filters
/// - Timestamps toggle
/// - Tail-line count picker
/// - In-view text search
/// - Copy-to-clipboard
struct ContainerLogsView: View {

    let client: PortainerClient
    let container: DockerContainer
    let endpointId: Int

    @State private var viewModel: ContainerLogsViewModel
    @State private var isPreview = false
    @State private var showSettings = false
    @State private var isAtBottom = true

    // MARK: - Init

    init(client: PortainerClient, container: DockerContainer, endpointId: Int) {
        self.client = client
        self.container = container
        self.endpointId = endpointId
        self._viewModel = State(initialValue: ContainerLogsViewModel())
    }

    init(client: PortainerClient, container: DockerContainer, endpointId: Int, previewViewModel: ContainerLogsViewModel) {
        self.client = client
        self.container = container
        self.endpointId = endpointId
        self._viewModel = State(initialValue: previewViewModel)
        self._isPreview = State(initialValue: true)
    }

    // MARK: - Body

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.lines.isEmpty {
                ProgressView("Loading logs…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.loadError, viewModel.lines.isEmpty {
                errorView(message: error)
            } else {
                logContent
            }
        }
        .navigationTitle("Logs — \(container.displayName)")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .searchable(text: $viewModel.searchText, prompt: "Search logs")
        .toolbar { toolbarContent }
        .sheet(isPresented: $showSettings) {
            settingsSheet
        }
        .task {
            guard !isPreview else { return }
            await viewModel.load(client: client, containerId: container.id, endpointId: endpointId)
        }
        .onDisappear {
            viewModel.stopStream()
        }
    }

    // MARK: - Log Content

    private var logContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if viewModel.displayedLines.isEmpty {
                        emptyLogsView
                    } else {
                        ForEach(viewModel.displayedLines) { line in
                            logLineView(line)
                        }
                        // Invisible anchor for auto-scroll.
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(Color.primary.opacity(0.001)) // ensures hit-testing for drag gesture
            .onChange(of: viewModel.displayedLines.count) {
                if isAtBottom {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { _ in isAtBottom = false }
            )
            .overlay(alignment: .bottomTrailing) {
                if !isAtBottom {
                    scrollToBottomButton(proxy: proxy)
                }
            }
        }
    }

    // MARK: - Log Line

    private func logLineView(_ line: LogLine) -> some View {
        HStack(alignment: .top, spacing: 0) {
            // Stderr indicator bar
            if line.source == .stderr {
                Rectangle()
                    .fill(Color.orange)
                    .frame(width: 2)
                    .padding(.trailing, 6)
            } else {
                Spacer().frame(width: 8)
            }

            VStack(alignment: .leading, spacing: 0) {
                if viewModel.showTimestamps, let ts = line.timestamp {
                    Text(ts)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                Text(highlightedText(for: line.text))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(line.source == .stderr ? Color.orange : Color.primary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 1)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 1)
    }

    // MARK: - Scroll to Bottom Button

    private func scrollToBottomButton(proxy: ScrollViewProxy) -> some View {
        Button {
            isAtBottom = true
            withAnimation {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        } label: {
            Image(systemName: "arrow.down.circle.fill")
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
                .background(Circle().fill(.background).padding(2))
        }
        .padding()
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Empty State

    private var emptyLogsView: some View {
        ContentUnavailableView {
            Label("No Logs", systemImage: "doc.text")
        } description: {
            if !viewModel.searchText.isEmpty {
                Text("No lines match your search.")
            } else if !viewModel.showStdout || !viewModel.showStderr {
                Text("No lines match the active source filter.")
            } else {
                Text("This container has not produced any log output.")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        ContentUnavailableView {
            Label("Could Not Load Logs", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                Task { await viewModel.load(client: client, containerId: container.id, endpointId: endpointId) }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            // Follow / Pause toggle
            Button {
                viewModel.toggleFollow(client: client, containerId: container.id, endpointId: endpointId)
                if viewModel.isFollowing { isAtBottom = true }
            } label: {
                Label(
                    viewModel.isFollowing ? "Pause" : "Follow",
                    systemImage: viewModel.isFollowing ? "pause.fill" : "play.fill"
                )
            }
            .tint(viewModel.isFollowing ? .orange : .green)

            // Settings sheet
            Button {
                showSettings = true
            } label: {
                Label("Settings", systemImage: "slider.horizontal.3")
            }

            // Copy
            Button {
                viewModel.copyToClipboard()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .disabled(viewModel.displayedLines.isEmpty)

            // Refresh (re-fetch snapshot)
            if !viewModel.isFollowing {
                Button {
                    Task { await viewModel.reload(client: client, containerId: container.id, endpointId: endpointId) }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
        }
    }

    // MARK: - Settings Sheet

    private var settingsSheet: some View {
        NavigationStack {
            Form {
                Section("Sources") {
                    Toggle("Standard Output (stdout)", isOn: $viewModel.showStdout)
                    Toggle("Standard Error (stderr)", isOn: $viewModel.showStderr)
                }

                Section("Display") {
                    Toggle("Show Timestamps", isOn: $viewModel.showTimestamps)
                }

                Section("History") {
                    Picker("Lines to Load", selection: $viewModel.tailLines) {
                        Text("50").tag(50)
                        Text("100").tag(100)
                        Text("200").tag(200)
                        Text("500").tag(500)
                        Text("1000").tag(1000)
                    }
                }

                Section {
                    Button("Reload Logs") {
                        showSettings = false
                        Task { await viewModel.reload(client: client, containerId: container.id, endpointId: endpointId) }
                    }
                }
            }
            .navigationTitle("Log Settings")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showSettings = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Helpers

    /// Returns an `AttributedString` with the search term highlighted.
    private func highlightedText(for text: String) -> AttributedString {
        var attributed = AttributedString(text)
        guard !viewModel.searchText.isEmpty else { return attributed }

        var searchStart = attributed.startIndex
        while searchStart < attributed.endIndex {
            guard let range = attributed[searchStart...].range(
                of: viewModel.searchText,
                options: .caseInsensitive
            ) else { break }
            attributed[range].backgroundColor = .yellow.opacity(0.4)
            attributed[range].foregroundColor = .primary
            searchStart = range.upperBound
        }
        return attributed
    }
}

// MARK: - Previews

#Preview("Logs — Light") {
    NavigationStack {
        ContainerLogsView(
            client: PortainerClient(serverURL: URL(string: "http://localhost:9000")!),
            container: .previewMock,
            endpointId: 1,
            previewViewModel: ContainerLogsViewModel(previewLines: .previewLines)
        )
    }
    .preferredColorScheme(.light)
}

#Preview("Logs — Dark") {
    NavigationStack {
        ContainerLogsView(
            client: PortainerClient(serverURL: URL(string: "http://localhost:9000")!),
            container: .previewMock,
            endpointId: 1,
            previewViewModel: ContainerLogsViewModel(previewLines: .previewLines)
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Empty Logs") {
    NavigationStack {
        ContainerLogsView(
            client: PortainerClient(serverURL: URL(string: "http://localhost:9000")!),
            container: .previewMock,
            endpointId: 1,
            previewViewModel: ContainerLogsViewModel(previewLines: [])
        )
    }
}

// MARK: - Preview Mock Data

private extension DockerContainer {
    static let previewMock: DockerContainer = {
        let json = """
        {"Id":"a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4","Names":["/nginx-proxy"],"Image":"nginx:alpine",
         "ImageID":"sha256:abc","Command":"nginx -g 'daemon off;'","Created":1700000000,
         "State":"running","Status":"Up 3 days","Ports":[],"Labels":{}}
        """
        return try! JSONDecoder().decode(DockerContainer.self, from: Data(json.utf8))
    }()
}

private extension [LogLine] {
    static let previewLines: [LogLine] = {
        let stdoutLines = [
            "2024-01-15T10:30:00.123456789Z nginx/1.25.3 started",
            "2024-01-15T10:30:00.234567890Z Listening on port 80",
            "2024-01-15T10:30:01.345678901Z GET /health HTTP/1.1 200 0 0.001 ms",
            "2024-01-15T10:30:05.456789012Z GET / HTTP/1.1 200 615 0.002 ms",
            "2024-01-15T10:30:10.567890123Z GET /api/v1/status HTTP/1.1 200 142 0.003 ms",
            "2024-01-15T10:30:15.678901234Z POST /api/v1/deploy HTTP/1.1 201 88 0.045 ms",
            "2024-01-15T10:30:20.789012345Z GET /metrics HTTP/1.1 200 4320 0.012 ms",
            "2024-01-15T10:30:25.890123456Z Worker 1: processing job queue",
            "2024-01-15T10:30:30.901234567Z Worker 2: processing job queue",
            "2024-01-15T10:30:35.012345678Z Cache hit ratio: 94.2%",
        ]
        let stderrLines = [
            "2024-01-15T10:30:02.999000000Z [warn] upstream timed out (110: Connection timed out)",
            "2024-01-15T10:30:18.888000000Z [error] connect() failed (111: Connection refused)",
        ]

        var lines: [LogLine] = []
        for text in stdoutLines { lines.append(LogLine(source: .stdout, text: text)) }
        for text in stderrLines { lines.append(LogLine(source: .stderr, text: text)) }
        return lines.sorted { ($0.timestamp ?? "") < ($1.timestamp ?? "") }
    }()
}
