import SwiftUI

/// A small pill-shaped badge indicating an environment's up/down status.
struct StatusBadge: View {

    let status: PortainerEndpoint.EndpointStatus

    var body: some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    private var label: String {
        switch status {
        case .up:   "Up"
        case .down: "Down"
        }
    }

    private var color: Color {
        switch status {
        case .up:   .green
        case .down: .red
        }
    }
}

#Preview {
    HStack {
        StatusBadge(status: .up)
        StatusBadge(status: .down)
    }
    .padding()
}
