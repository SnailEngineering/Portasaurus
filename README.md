# Portasaurus


## Notes from a Human

_This app is an independent client for Portainer and is not affiliated with or endorsed by Portainer.io._ 

Full disclaimer, yes, I am building this using various AI tools (vibe coding), but my goal is to go one small step at a time, and verify each piece as it is built to insure what comes out is a well built product with minimal tech debt and AI bloat. 

**What is it?** A native Swift app for iOS, macOS, and visionOS that provides home lab users with a clean, intuitive interface for managing their Portainer CE instances. Built with SwiftUI, SwiftData, and Keychain Services. 

**Why are you doing this?** Because I do a lot from my phone and tablet these days, like... [alot](https://hyperboleandahalf.blogspot.com/2010/04/alot-is-better-than-you-at-everything.html). And here recently, I've found myself zooming in and out and moving around the screen try to accomplish basic tasks on my phone so I can change environment vars, re-deploy things, watch logs, etc. When I went poking around, I didn't immediately see anything that looked like I wanted. And it seemed like a fun use case to try to build something better. 

What does that mean for you? The random internet user who landed here, well, nothing right now. Once I get a functional product, I'll post it to the App Store (mainly for myself) and if you want to try it out and/or contribute. Feel free to grab a PR. Otherwise, not much. Dis for me. But thanks for reading!

## Everything below here is in fact AI generated.

If you continue below here, trust, but verify. Thar be dragons. I've asked AI to create a comprehensive plan for me. I plan to build this out one piece at a time and slowly, manually, review and work through the plan. But just know everything below here is AI generated, I haven't reviewed it all. It could all be lies.

## Target

- **Portainer CE (Community Edition)** — all API interactions target the CE variant
- **API base path**: `/api/` (no version prefix)
- **Default ports**: `9443` (HTTPS, self-signed cert) or `9000` (HTTP)

---

## Architecture Overview

### Tech Stack

| Layer | Technology |
|---|---|
| UI | SwiftUI (iOS 26+, macOS 26+, visionOS 26+) |
| Navigation | `NavigationSplitView` (sidebar → list → detail) |
| Persistence | SwiftData (server metadata, preferences) |
| Secrets | Keychain Services via Security framework (credentials) |
| Networking | `URLSession` with async/await |
| Real-time | `URLSessionWebSocketTask` (exec, attach); chunked HTTP streaming (logs) |
| Concurrency | Swift structured concurrency (async/await, AsyncSequence, actors) |

### Project Structure (target)

```
Portasaurus/
├── App/
│   └── PortasaurusApp.swift
├── Models/
│   ├── SwiftData/
│   │   └── SavedServer.swift              # SwiftData model for server bookmarks
│   └── API/
│       ├── PortainerAuth.swift            # Auth request/response types
│       ├── PortainerEndpoint.swift         # Environment model
│       ├── DockerContainer.swift           # Container model
│       ├── DockerContainerDetail.swift     # Container inspect model
│       ├── DockerImage.swift               # Image model
│       ├── DockerVolume.swift              # Volume model
│       ├── DockerNetwork.swift             # Network model
│       ├── PortainerStack.swift            # Stack model
│       └── PortainerSystemStatus.swift     # System status model
├── Services/
│   ├── PortainerClient.swift              # Core API client (URLSession, auth, request building)
│   ├── KeychainService.swift              # Keychain read/write/delete for credentials
│   └── LogStreamService.swift             # Chunked HTTP log streaming
├── ViewModels/
│   ├── ServerConnectionViewModel.swift
│   ├── EnvironmentListViewModel.swift
│   ├── ContainerListViewModel.swift
│   ├── ContainerDetailViewModel.swift
│   ├── ContainerLogsViewModel.swift
│   ├── ImageListViewModel.swift
│   ├── VolumeListViewModel.swift
│   ├── NetworkListViewModel.swift
│   └── StackListViewModel.swift
├── Views/
│   ├── ServerConnection/
│   │   ├── ServerListView.swift           # Landing page — saved servers
│   │   └── AddServerView.swift            # Connect to new server form
│   ├── Environments/
│   │   └── EnvironmentListView.swift      # List of Portainer endpoints
│   ├── Containers/
│   │   ├── ContainerListView.swift
│   │   ├── ContainerDetailView.swift
│   │   └── ContainerLogsView.swift
│   ├── Images/
│   │   └── ImageListView.swift
│   ├── Volumes/
│   │   └── VolumeListView.swift
│   ├── Networks/
│   │   └── NetworkListView.swift
│   ├── Stacks/
│   │   ├── StackListView.swift
│   │   └── StackDetailView.swift
│   └── Shared/
│       ├── StatusBadge.swift              # Running/stopped/etc. indicator
│       └── ErrorBanner.swift              # Reusable error display
└── Utilities/
    └── SSLTrustHandler.swift              # Custom URLSession delegate for self-signed certs
```

---

## Portainer CE API Reference (Key Endpoints)

### Authentication

| Action | Method | Path | Notes |
|---|---|---|---|
| Login | `POST` | `/api/auth` | Body: `{"username":"…","password":"…"}` → `{"jwt":"…"}` |
| Current user | `GET` | `/api/users/me` | Verify token is valid |

- JWT expires after **8 hours**; there is no refresh endpoint — re-authenticate on 401
- Pass token as `Authorization: Bearer <JWT>` header
- For WebSockets, pass as `?token=<JWT>` query parameter

### System

| Action | Method | Path |
|---|---|---|
| Status | `GET` | `/api/system/status` |
| Version | `GET` | `/api/system/version` |

### Environments (Endpoints)

| Action | Method | Path |
|---|---|---|
| List | `GET` | `/api/endpoints` |
| Detail | `GET` | `/api/endpoints/{id}` |

Supports `start`, `limit`, `search`, `groupId`, `tagIds` query params.

### Containers (Docker Proxy)

All container operations are proxied through: `/api/endpoints/{envId}/docker/…`

| Action | Method | Path |
|---|---|---|
| List | `GET` | `.../containers/json?all=true` |
| Inspect | `GET` | `.../containers/{id}/json` |
| Start | `POST` | `.../containers/{id}/start` |
| Stop | `POST` | `.../containers/{id}/stop` |
| Restart | `POST` | `.../containers/{id}/restart` |
| Kill | `POST` | `.../containers/{id}/kill` |
| Remove | `DELETE` | `.../containers/{id}?force=true&v=true` |
| Logs | `GET` | `.../containers/{id}/logs?stdout=1&stderr=1&timestamps=1&tail=100` |
| Logs (stream) | `GET` | `.../containers/{id}/logs?stdout=1&stderr=1&follow=1&tail=100` |
| Stats (snapshot) | `GET` | `.../containers/{id}/stats?stream=false` |
| Rename | `POST` | `.../containers/{id}/rename?name=newname` |
| Pause | `POST` | `.../containers/{id}/pause` |
| Unpause | `POST` | `.../containers/{id}/unpause` |

### Images (Docker Proxy)

| Action | Method | Path |
|---|---|---|
| List | `GET` | `.../images/json` |
| Inspect | `GET` | `.../images/{id}/json` |
| Remove | `DELETE` | `.../images/{id}?force=true` |
| Pull | `POST` | `.../images/create?fromImage=nginx&tag=latest` |
| Prune | `POST` | `.../images/prune` |

### Volumes (Docker Proxy)

| Action | Method | Path |
|---|---|---|
| List | `GET` | `.../volumes` |
| Inspect | `GET` | `.../volumes/{name}` |
| Create | `POST` | `.../volumes/create` |
| Remove | `DELETE` | `.../volumes/{name}` |

### Networks (Docker Proxy)

| Action | Method | Path |
|---|---|---|
| List | `GET` | `.../networks` |
| Inspect | `GET` | `.../networks/{id}` |
| Create | `POST` | `.../networks/create` |
| Remove | `DELETE` | `.../networks/{id}` |

### Stacks (Portainer Native)

| Action | Method | Path |
|---|---|---|
| List | `GET` | `/api/stacks` |
| Inspect | `GET` | `/api/stacks/{id}` |
| Get compose file | `GET` | `/api/stacks/{id}/file` |
| Start | `POST` | `/api/stacks/{id}/start` |
| Stop | `POST` | `/api/stacks/{id}/stop` |
| Delete | `DELETE` | `/api/stacks/{id}?endpointId={envId}` |
| Update | `PUT` | `/api/stacks/{id}?endpointId={envId}` |

### WebSocket

| Action | Path |
|---|---|
| Exec | `ws://…/api/websocket/exec?endpointId={id}&token={jwt}&id={execId}` |
| Attach | `ws://…/api/websocket/attach?endpointId={id}&token={jwt}` |

Exec flow: create exec instance via Docker proxy → connect WebSocket with returned exec ID.

---

## Build Plan — Ordered Checklist

Each phase is designed to be self-contained. Complete one before starting the next. Every phase produces a working, testable feature.

### Phase 1: Foundation & Server Connection

The landing experience. Users can add, save, and connect to Portainer servers.

- [x] **1.1** Set up multi-platform target configuration (iOS, macOS, visionOS) in Xcode project
- [x] **1.2** Create `PortainerClient` — core networking layer
  - `URLSession`-based with async/await
  - Base URL construction from server host/port/scheme
  - Generic `request<T: Decodable>()` method with JSON encoding/decoding
  - Automatic `Authorization: Bearer` header injection
  - 401 response interception for re-authentication flow
- [ ] **1.3** Create `KeychainService` — credential storage
  - Save credentials keyed by server URL
  - Read credentials for a given server
  - Delete credentials
  - Uses Security framework directly (no third-party dependencies)
- [ ] **1.4** Create `SavedServer` SwiftData model
  - Properties: `id` (UUID), `name` (display label), `host`, `port`, `usesHTTPS`, `username`, `dateAdded`, `lastConnected`
  - Credentials stored in Keychain (not in SwiftData)
- [ ] **1.5** Implement authentication — `POST /api/auth`
  - `AuthRequest` / `AuthResponse` Codable types
  - Token stored in memory on `PortainerClient` (not persisted — re-auth on app launch)
  - Validate connection with `GET /api/system/status` after login
- [ ] **1.6** Build `ServerListView` — landing page
  - List of saved servers (from SwiftData) showing name, host, last connected date
  - "Add Server" button
  - Swipe-to-delete to remove saved servers (with Keychain cleanup)
  - Tap to connect → authenticate → navigate into the app
  - Connection status indicator (connecting, failed, success)
- [ ] **1.7** Build `AddServerView` — new server form
  - Fields: display name, host/IP, port (default 9443), HTTPS toggle, username, password
  - "Test Connection" button — attempts `POST /api/auth` + `GET /api/system/status`
  - "Save & Connect" — saves to SwiftData + Keychain, then navigates in
  - Input validation (non-empty host, valid port range, etc.)
  - Option to trust self-signed certificates for this server

### Phase 2: Environment (Endpoint) Selection

After connecting, the user picks which Docker environment to manage.

- [ ] **2.1** Create `PortainerEndpoint` Codable model (id, name, type, status, URL, publicURL, snapshots)
- [ ] **2.2** Implement `GET /api/endpoints` on `PortainerClient`
- [ ] **2.3** Build `EnvironmentListView`
  - List of environments with name, type badge (Docker, Swarm, Kubernetes), status indicator
  - Pull-to-refresh
  - Search/filter
  - Tap to select → navigate to container list
  - Show snapshot summary (containers running, stopped, healthy counts) if snapshot data available

### Phase 3: Container List & Actions

The primary operational view. See all containers and perform quick actions.

- [ ] **3.1** Create `DockerContainer` Codable model (id, names, image, state, status, ports, created, labels)
- [ ] **3.2** Implement container list endpoint on `PortainerClient` — `GET .../containers/json?all=true`
- [ ] **3.3** Build `ContainerListView`
  - List showing container name, image, state (with color-coded `StatusBadge`)
  - Filter by state: all, running, stopped, paused
  - Search by name
  - Pull-to-refresh
  - Auto-refresh on a timer (configurable, default 10s)
- [ ] **3.4** Add container quick actions (swipe actions or context menu)
  - Start / Stop / Restart
  - Confirmation for destructive actions (kill, remove)
  - Visual feedback during action (loading state)
- [ ] **3.5** Create `StatusBadge` shared component
  - Color-coded pill: green (running), red (exited), yellow (paused), gray (created/dead)

### Phase 4: Container Detail & Inspection

Drill into a single container to see its full configuration.

- [ ] **4.1** Create `DockerContainerDetail` Codable model (full inspect response — config, network settings, mounts, state)
- [ ] **4.2** Implement container inspect endpoint — `GET .../containers/{id}/json`
- [ ] **4.3** Build `ContainerDetailView`
  - Sections:
    - **Status** — state, started at, finished at, restart count, health status
    - **Configuration** — image, command, entrypoint, working dir, user
    - **Environment variables** — list of key=value pairs
    - **Ports** — host port → container port mappings
    - **Mounts/Volumes** — source → destination, type, read/write
    - **Network** — connected networks, IP addresses, MAC addresses
    - **Labels** — key-value list
    - **Resource limits** — memory, CPU (if set)
  - Action buttons in toolbar: start/stop/restart, view logs
  - Pull-to-refresh

### Phase 5: Container Logs

View and stream container logs in real-time.

- [ ] **5.1** Implement container logs endpoint — `GET .../containers/{id}/logs`
  - Support query params: `stdout`, `stderr`, `timestamps`, `tail`, `since`, `follow`
- [ ] **5.2** Create `LogStreamService`
  - Uses `URLSession` bytes streaming for `follow=true`
  - Parses Docker multiplexed stream format (8-byte header: stream type + length)
  - Delivers log lines as an `AsyncSequence`
- [ ] **5.3** Build `ContainerLogsView`
  - Scrollable log output with monospace font
  - Auto-scroll to bottom (with manual scroll override)
  - Toggle: follow/pause live streaming
  - Controls: stdout/stderr filter, tail line count, timestamps toggle
  - Search within logs (local text search)
  - Copy log content to clipboard
  - Platform-appropriate display (larger text area on macOS/visionOS)

### Phase 6: Stack Management

View and control Docker Compose stacks.

- [ ] **6.1** Create `PortainerStack` Codable model (id, name, type, status, endpointId, env, creationDate)
- [ ] **6.2** Implement stack endpoints on `PortainerClient`
  - List: `GET /api/stacks`
  - Detail: `GET /api/stacks/{id}`
  - Compose file: `GET /api/stacks/{id}/file`
  - Start: `POST /api/stacks/{id}/start`
  - Stop: `POST /api/stacks/{id}/stop`
- [ ] **6.3** Build `StackListView`
  - List showing stack name, status, number of containers (from related containers)
  - Start/stop actions via swipe or context menu
  - Filter by status (active/inactive)
- [ ] **6.4** Build `StackDetailView`
  - Stack metadata (name, type, creation date, environment variables)
  - Compose file viewer with syntax-highlighted YAML (read-only initially)
  - List of containers belonging to this stack (reuse `ContainerListView` with filter)
  - Start/stop/restart actions in toolbar

### Phase 7: Image Management

Browse and manage Docker images on each environment.

- [ ] **7.1** Create `DockerImage` Codable model (id, repoTags, repoDigests, size, created, containers)
- [ ] **7.2** Implement image endpoints on `PortainerClient`
  - List: `GET .../images/json`
  - Remove: `DELETE .../images/{id}`
  - Prune: `POST .../images/prune`
- [ ] **7.3** Build `ImageListView`
  - List showing image tag(s), size (human-readable), created date
  - Search/filter by name
  - Delete image (with confirmation)
  - Prune unused images (with confirmation showing space to be reclaimed)
  - Badge for "in use" vs "dangling"

### Phase 8: Volume Management

- [ ] **8.1** Create `DockerVolume` Codable model (name, driver, mountpoint, labels, scope, createdAt, usageData)
- [ ] **8.2** Implement volume endpoints on `PortainerClient`
- [ ] **8.3** Build `VolumeListView`
  - List showing volume name, driver, size (if available)
  - Create new volume (name, driver, labels)
  - Delete volume (with confirmation, warn if in use)
  - "In use" indicator based on container mount data

### Phase 9: Network Management

- [ ] **9.1** Create `DockerNetwork` Codable model (id, name, driver, scope, internal, attachable, containers)
- [ ] **9.2** Implement network endpoints on `PortainerClient`
- [ ] **9.3** Build `NetworkListView`
  - List showing network name, driver, scope (local/swarm)
  - Expandable detail: subnet, gateway, connected containers
  - Delete network (with confirmation, prevent deletion of default networks)

### Phase 10: Container Stats & Resource Monitoring

- [ ] **10.1** Implement container stats endpoint — `GET .../containers/{id}/stats?stream=false`
- [ ] **10.2** Parse Docker stats response (CPU %, memory usage/limit, network I/O, block I/O)
- [ ] **10.3** Add stats section to `ContainerDetailView`
  - Live-updating gauges: CPU %, memory usage bar, network Rx/Tx
  - Polling-based refresh (every 2-3 seconds)
- [ ] **10.4** Add stats summary to `ContainerListView`
  - Optional column/row showing CPU% and memory for running containers

### Phase 11: Container Exec (Interactive Shell)

- [ ] **11.1** Implement exec creation — `POST .../containers/{id}/exec`
- [ ] **11.2** Implement WebSocket connection to `/api/websocket/exec`
- [ ] **11.3** Build `ContainerExecView`
  - Terminal-style view with text input
  - Command history (up/down arrow on macOS)
  - Shell selection (sh, bash, zsh, ash)
  - Proper WebSocket lifecycle management (connect, reconnect, close)

### Phase 12: Dashboard / Overview

A summary view after selecting an environment.

- [ ] **12.1** Build `DashboardView`
  - Container summary: running / stopped / total counts with visual breakdown
  - Stack summary: active / inactive counts
  - Resource usage: total images, volumes, networks
  - Recent events or activity (if feasible via Docker events API)
  - Quick-action shortcuts to common tasks
- [ ] **12.2** Wire dashboard as the default view after environment selection (before container list)

### Phase 13: Settings & Polish

- [ ] **13.1** Build `SettingsView`
  - Auto-refresh interval configuration
  - Default log tail count
  - Theme (respect system appearance)
  - Self-signed certificate trust management per server
  - Clear all saved servers & credentials
- [ ] **13.2** Add proper error handling throughout
  - Network error banners (connection lost, timeout, server unreachable)
  - Retry logic with exponential backoff for transient failures
  - Graceful handling of 401 (re-auth prompt) and 403 (permission denied)
- [ ] **13.3** macOS-specific refinements
  - Menu bar commands for common actions
  - Keyboard shortcuts
  - Window management (sidebar toggle)
- [ ] **13.4** visionOS-specific refinements
  - Appropriate use of depth and spatial layout
  - Ornament-based controls where applicable
  - Comfortable text sizing for spatial computing
- [ ] **13.5** Accessibility
  - VoiceOver labels for all interactive elements
  - Dynamic Type support
  - Sufficient color contrast (don't rely solely on color for status)

### Phase 14: Advanced Features (Future)

These are stretch goals for after the core app is solid.

- [ ] **14.1** Container creation wizard (image selection, port mapping, volume mounts, env vars)
- [ ] **14.2** Stack creation (paste/edit compose YAML, deploy)
- [ ] **14.3** Docker registry browsing (configured registries in Portainer)
- [ ] **14.4** Multi-server overview (aggregate view across all saved servers)
- [ ] **14.5** Push notifications via background refresh (container state changes)
- [ ] **14.6** Widgets (iOS/macOS) showing container status summary
- [ ] **14.7** Shortcuts/Siri integration ("How many containers are running?")
- [ ] **14.8** Import/export server configurations (for sharing between devices)

---

## Design Principles

1. **One view at a time** — each phase is a complete, testable feature. No half-built screens.
2. **No third-party dependencies** — use Apple frameworks exclusively (URLSession, Security, SwiftData, SwiftUI).
3. **Models match the API** — Codable structs mirror Portainer/Docker API responses exactly. Use `CodingKeys` only when Swift naming conventions differ.
4. **ViewModels isolate logic** — views are thin. All API calls, state management, and data transformation live in `@Observable` view models.
5. **Credentials never touch disk unencrypted** — Keychain only. SwiftData stores server metadata (host, port, display name) but never passwords or tokens.
6. **Progressive disclosure** — list views show essential info; detail views show everything. Don't overwhelm users on summary screens.
7. **Platform-adaptive, not platform-specific** — one codebase with `#if os()` only where truly needed (toolbars, navigation patterns). Lean on SwiftUI's built-in adaptivity.

---

## Getting Started

Open `Portasaurus/Portasaurus.xcodeproj` in Xcode. The project currently contains the default SwiftData template and is ready to be built out starting with **Phase 1**.

Begin with Phase 1.1 — verify multi-platform targets are configured, then proceed to building `PortainerClient` and `KeychainService` before any views.
