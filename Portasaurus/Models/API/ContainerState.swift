import Foundation

/// The lifecycle state of a Docker container.
enum ContainerState: String, Decodable, Sendable, CaseIterable {
    case running
    case exited
    case paused
    case created
    case dead
    case removing
    case restarting

    nonisolated init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ContainerState(rawValue: raw.lowercased()) ?? .dead
    }

    var displayName: String {
        switch self {
        case .running:    "Running"
        case .exited:     "Exited"
        case .paused:     "Paused"
        case .created:    "Created"
        case .dead:       "Dead"
        case .removing:   "Removing"
        case .restarting: "Restarting"
        }
    }

    var canStart:   Bool { self == .exited || self == .created || self == .dead }
    var canStop:    Bool { self == .running || self == .paused }
    var canPause:   Bool { self == .running }
    var canUnpause: Bool { self == .paused }
    var canRestart: Bool { self == .running || self == .exited }
}
