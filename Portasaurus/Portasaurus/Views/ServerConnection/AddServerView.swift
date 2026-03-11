import SwiftUI
import SwiftData

/// Form for connecting to a new Portainer server.
struct AddServerView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = AddServerViewModel()

    /// Called with the connected client and server display name after a successful "Save & Connect".
    var onConnected: (PortainerClient, String) -> Void

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
        Section("Server") {
            LabeledContent("Name") {
                TextField("My Portainer", text: $viewModel.name)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("Host") {
                TextField("192.168.1.100", text: $viewModel.host)
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
#if os(iOS)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
#endif
            }
            LabeledContent("Port") {
                TextField("9443", text: $viewModel.port)
                    .multilineTextAlignment(.trailing)
#if os(iOS)
                    .keyboardType(.numberPad)
#endif
            }
            Toggle("Use HTTPS", isOn: $viewModel.usesHTTPS)
                .onChange(of: viewModel.usesHTTPS) {
                    // Suggest the standard port when toggling scheme.
                    if viewModel.port == "9000" && viewModel.usesHTTPS {
                        viewModel.port = "9443"
                    } else if viewModel.port == "9443" && !viewModel.usesHTTPS {
                        viewModel.port = "9000"
                    }
                }
        }
    }

    private var credentialsSection: some View {
        Section("Credentials") {
            LabeledContent("Username") {
                TextField("admin", text: $viewModel.username)
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
#if os(iOS)
                    .textInputAutocapitalization(.never)
#endif
            }
            LabeledContent("Password") {
                SecureField("Required", text: $viewModel.password)
                    .multilineTextAlignment(.trailing)
            }
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
            let client = try await viewModel.saveAndConnect(modelContext: modelContext)
            onConnected(client, viewModel.name)
        } catch {
            // Surface the error via testResult so it's visible in the form.
            viewModel.testResult = .failure(error.localizedDescription)
        }
    }
}

#Preview {
    AddServerView { _, _ in }
        .modelContainer(for: SavedServer.self, inMemory: true)
}
