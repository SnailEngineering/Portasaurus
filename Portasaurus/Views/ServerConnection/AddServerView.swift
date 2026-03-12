import SwiftUI
import SwiftData

/// Form for connecting to a new Portainer server.
struct AddServerView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = AddServerViewModel()

    /// Called with the connected client, server ID, and display name after a successful "Save & Connect".
    var onConnected: (PortainerClient, UUID, String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                serverSection
                credentialsSection
                sslSection
                testSection
                if let msg = viewModel.validationMessage {
                    Section {
                        Label(msg, systemImage: "exclamationmark.circle")
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Server")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await saveAndConnect() }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Save & Connect")
                        }
                    }
                    .disabled(!viewModel.isValid || viewModel.isSaving || viewModel.isTesting)
                }
            }
        }
    }

    // MARK: - Form Sections

    private var serverSection: some View {
        Section {
            TextField("Name", text: $viewModel.name)
            TextField("URL", text: $viewModel.serverURL)
                .autocorrectionDisabled()
#if os(iOS)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
#endif
        } footer: {
            if let url = viewModel.parsedURL {
                Label(url.absoluteString, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }
        }
    }

    private var credentialsSection: some View {
        Section {
            TextField("Username", text: $viewModel.username)
                .autocorrectionDisabled()
#if os(iOS)
                .textInputAutocapitalization(.never)
#endif
            SecureField("Password", text: $viewModel.password)
        }
    }

    private var sslSection: some View {
        Section {
            Toggle("Trust Self-Signed Certificate", isOn: $viewModel.trustSelfSigned)
        } footer: {
            Text("Enable this if your Portainer instance uses a self-signed or private CA certificate. Only enable for servers you control.")
                .font(.footnote)
        }
    }

    private var testSection: some View {
        Section {
            Button {
                Task { await viewModel.testConnection() }
            } label: {
                HStack {
                    Text("Test Connection")
                    Spacer()
                    if viewModel.isTesting {
                        ProgressView().controlSize(.small)
                    }
                }
            }
            .disabled(!viewModel.isValid || viewModel.isTesting || viewModel.isSaving)

            if let result = viewModel.testResult {
                testResultRow(result)
            }
        }
    }

    @ViewBuilder
    private func testResultRow(_ result: AddServerViewModel.TestResult) -> some View {
        switch result {
        case .success(let version):
            Label("Connected — Portainer \(version)", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.callout)
        case .failure(let message):
            Label(message, systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.callout)
        }
    }

    // MARK: - Save & Connect

    private func saveAndConnect() async {
        do {
            let (client, serverID) = try await viewModel.saveAndConnect(modelContext: modelContext)
            onConnected(client, serverID, viewModel.name)
        } catch {
            viewModel.testResult = .failure(error.localizedDescription)
        }
    }
}

#Preview("Light") {
    AddServerView { _, _, _ in }
        .modelContainer(for: SavedServer.self, inMemory: true)
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    AddServerView { _, _, _ in }
        .modelContainer(for: SavedServer.self, inMemory: true)
        .preferredColorScheme(.dark)
}

