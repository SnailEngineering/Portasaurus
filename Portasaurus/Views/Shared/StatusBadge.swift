import SwiftUI

/// A small pill-shaped badge conveying a status at a glance.
///
/// Use the typed convenience initializers for endpoint status or container state.
struct StatusBadge: View {

    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    // MARK: - Endpoint status

    init(status: PortainerEndpoint.EndpointStatus) {
        switch status {
        case .up:   self.init(label: "Up",   color: .green)
        case .down: self.init(label: "Down", color: .red)
        }
    }

    // MARK: - Container state

    init(containerState: ContainerState) {
        switch containerState {
        case .running:    self.init(label: containerState.displayName, color: .green)
        case .paused:     self.init(label: containerState.displayName, color: .yellow)
        case .restarting: self.init(label: containerState.displayName, color: .orange)
        case .exited, .dead, .removing, .created:
            self.init(label: containerState.displayName, color: .gray)
        }
    }
}

private extension StatusBadge {
    init(label: String, color: Color) {
        self.label = label
        self.color = color
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        HStack {
            StatusBadge(status: .up)
            StatusBadge(status: .down)
        }
        HStack {
            StatusBadge(containerState: .running)
            StatusBadge(containerState: .exited)
            StatusBadge(containerState: .paused)
            StatusBadge(containerState: .created)
            StatusBadge(containerState: .dead)
        }
    }
    .padding()
}
