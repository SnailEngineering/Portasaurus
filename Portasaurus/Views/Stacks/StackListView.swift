import SwiftUI

/// Lists all Portainer stacks for an environment.
///
/// Supports filtering by status (active/inactive), text search, swipe actions
/// to start/stop, and navigation to `StackDetailView`.
struct StackListView: View {

    let client: PortainerClient
    let environment: PortainerEndpoint

    @State private var viewModel: StackListViewModel
    @State private var isPreview = false

    // MARK: - Init

    init(client: PortainerClient, environment: PortainerEndpoint) {
        self.client = client
        self.environment = environment
        self._viewModel = State(initialValue: StackListViewModel())
    }

    init(client: PortainerClient, environment: PortainerEndpoint, previewViewModel: StackListViewModel) {
        self.client = client
        self.environment = environment
        self._viewModel = State(initialValue: previewViewModel)
        self._isPreview = State(initialValue: true)
    }

    // MARK: - Body

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.stacks.isEmpty {
                ProgressView("Loading stacks…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.loadError, viewModel.stacks.isEmpty {
                errorView(message: error)
            } else if viewModel.filtered.isEmpty {
                emptyView
            } else {
                list
            }
        }
        .navigationTitle("Stacks")
#if os(iOS)
        .navigationBarTitleDisplayMode(.large)
#endif
        .searchable(text: $viewModel.searchText, prompt: "Search stacks")
        .refreshable { await viewModel.load(client: client, endpointId: environment.id) }
        .task {
            guard !isPreview else { return }
            await viewModel.load(client: client, endpointId: environment.id)
        }
        .navigationDestination(for: PortainerStack.self) { stack in
            StackDetailView(client: client, stack: stack, environment: environment)
        }
        .toolbar { toolbarContent }
        .alert("Action Failed", isPresented: $viewModel.actionError.isPresented) {
            Button("OK", role: .cancel) { viewModel.actionError = nil }
        } message: {
            if let error = viewModel.actionError { Text(error) }
        }
    }

    // MARK: - List

    private var list: some View {
        List(viewModel.filtered) { stack in
            NavigationLink(value: stack) {
                StackRowView(stack: stack)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if stack.status.isActive {
                    Button(role: .destructive) {
                        Task { await viewModel.perform(.stop, stack: stack, client: client, endpointId: environment.id) }
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .tint(.red)
                }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                if !stack.status.isActive {
                    Button {
                        Task { await viewModel.perform(.start, stack: stack, client: client, endpointId: environment.id) }
                    } label: {
                        Label("Start", systemImage: "play.fill")
                    }
                    .tint(.green)
                }
            }
            .disabled(viewModel.isActing)
        }
        .listStyle(.inset)
        .overlay {
            if viewModel.isActing {
                ProgressView()
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Empty State

    private var emptyView: some View {
        ContentUnavailableView {
            Label("No Stacks", systemImage: "square.stack.3d.up")
        } description: {
            if !viewModel.searchText.isEmpty {
                Text("No stacks match \"\(viewModel.searchText)\".")
            } else if viewModel.statusFilter != .all {
                Text("No \(viewModel.statusFilter.rawValue.lowercased()) stacks in this environment.")
            } else {
                Text("No stacks have been deployed to this environment.")
            }
        }
    }

    // MARK: - Error State

    private func errorView(message: String) -> some View {
        ContentUnavailableView {
            Label("Could Not Load", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                Task { await viewModel.load(client: client, endpointId: environment.id) }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Picker("Filter", selection: $viewModel.statusFilter) {
                ForEach(StackListViewModel.StatusFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

// MARK: - Stack Row

private struct StackRowView: View {
    let stack: PortainerStack

    var body: some View {
        HStack(spacing: 12) {
            // Type icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: stack.type.systemImage)
                    .font(.callout)
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(stack.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(stack.type.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !stack.env.isEmpty {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text("\(stack.env.count) env var\(stack.env.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer(minLength: 0)

            // Status badge
            statusBadge
        }
        .padding(.vertical, 2)
    }

    private var statusBadge: some View {
        Text(stack.status.displayName)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(badgeColor.opacity(0.15), in: Capsule())
            .foregroundStyle(badgeColor)
    }

    private var badgeColor: Color {
        stack.status.isActive ? .green : .secondary
    }

    private var iconColor: Color {
        switch stack.type {
        case .dockerSwarm:   .blue
        case .dockerCompose: .indigo
        case .kubernetes:    .purple
        }
    }
}

// MARK: - Optional binding helper

private extension Optional where Wrapped == String {
    var isPresented: Bool {
        get { self != nil }
        set { if !newValue { self = nil } }
    }
}

// MARK: - Previews

#Preview("Stacks — Light") {
    NavigationStack {
        StackListView(
            client: PortainerClient(serverURL: URL(string: "http://localhost:9000")!),
            environment: .previewMock,
            previewViewModel: StackListViewModel(previewStacks: .mockStacks)
        )
    }
    .preferredColorScheme(.light)
}

#Preview("Stacks — Dark") {
    NavigationStack {
        StackListView(
            client: PortainerClient(serverURL: URL(string: "http://localhost:9000")!),
            environment: .previewMock,
            previewViewModel: StackListViewModel(previewStacks: .mockStacks)
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Empty Stacks") {
    NavigationStack {
        StackListView(
            client: PortainerClient(serverURL: URL(string: "http://localhost:9000")!),
            environment: .previewMock,
            previewViewModel: StackListViewModel(previewStacks: [])
        )
    }
}

// MARK: - Preview Mock Data

private extension PortainerEndpoint {
    static let previewMock: PortainerEndpoint = {
        let json = """
        {"Id":1,"Name":"production","Type":1,"Status":1,"URL":"tcp://localhost:2375","PublicURL":"","Snapshots":[]}
        """
        return try! JSONDecoder().decode(PortainerEndpoint.self, from: Data(json.utf8))
    }()
}

private struct _MockStack {
    var id: Int; var name: String; var type: Int; var status: Int; var envCount: Int
}

private extension [PortainerStack] {
    static let mockStacks: [PortainerStack] = {
        let items: [_MockStack] = [
            .init(id: 1, name: "nginx-proxy",    type: 2, status: 1, envCount: 3),
            .init(id: 2, name: "monitoring",     type: 2, status: 1, envCount: 5),
            .init(id: 3, name: "database-stack", type: 2, status: 2, envCount: 8),
            .init(id: 4, name: "app-backend",    type: 1, status: 1, envCount: 2),
            .init(id: 5, name: "redis-cluster",  type: 1, status: 2, envCount: 0),
        ]
        return items.map { item in
            let envPairs = (0..<item.envCount).map { i in
                #"{"name":"VAR_\#(i)","value":"value_\#(i)"}"#
            }.joined(separator: ",")
            let json = """
            {"Id":\(item.id),"Name":"\(item.name)","Type":\(item.type),"EndpointId":1,"Status":\(item.status),"Env":[\(envPairs)],"AdditionalFiles":[]}
            """
            return try! JSONDecoder().decode(PortainerStack.self, from: Data(json.utf8))
        }
    }()
}
