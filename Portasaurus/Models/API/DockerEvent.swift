import Foundation

/// A single event emitted by the Docker Engine events stream.
///
/// Docker sends newline-delimited JSON objects on `GET /events`. Only the
/// fields needed to decide whether to refresh the container list are decoded.
struct DockerEvent: Decodable, Sendable {

    /// The resource type the event relates to (e.g. "container", "image").
    let type: String

    /// The lifecycle action (e.g. "start", "stop", "die", "kill", "destroy").
    let action: String

    enum CodingKeys: String, CodingKey {
        case type   = "Type"
        case action = "Action"
    }

    /// Actions on containers that should trigger a list refresh.
    static let refreshActions: Set<String> = [
        "start", "stop", "die", "kill",
        "pause", "unpause", "destroy",
        "rename", "create", "health_status"
    ]

    /// Whether receiving this event should cause the container list to reload.
    var shouldRefreshContainers: Bool {
        type == "container" && Self.refreshActions.contains(action)
    }
}
