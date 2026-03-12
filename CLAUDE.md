# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Portasaurus is a native Swift client for Portainer CE (Community Edition). It targets iOS, macOS, and visionOS from a single codebase using SwiftUI and SwiftData. The Portainer source repo is available locally at `/Users/snail/Development/portainer` for API reference.

## Build & Test

This is an Xcode project (not a Swift Package). All build/test commands use `xcodebuild` from the `Portasaurus/` subdirectory.

```bash
# Build for macOS
xcodebuild -project Portasaurus/Portasaurus.xcodeproj -scheme Portasaurus -destination 'platform=macOS' build

# Build for iOS Simulator
xcodebuild -project Portasaurus/Portasaurus.xcodeproj -scheme Portasaurus -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run unit tests
xcodebuild -project Portasaurus/Portasaurus.xcodeproj -scheme Portasaurus -destination 'platform=macOS' test

# Run a single test
xcodebuild -project Portasaurus/Portasaurus.xcodeproj -scheme Portasaurus -destination 'platform=macOS' -only-testing:PortasaurusTests/TestClassName/testMethodName test
```

## Architecture

- **UI**: SwiftUI with `NavigationSplitView` pattern
- **Persistence**: SwiftData for server metadata; Keychain (Security framework) for credentials — passwords never in SwiftData
- **Networking**: `URLSession` async/await; `URLSessionWebSocketTask` for exec/attach; chunked HTTP streaming for logs
- **Concurrency**: Swift structured concurrency. Project uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY = YES`
- **View architecture**: Views are thin; `@Observable` ViewModels hold all API/state logic
- **API models**: Codable structs matching Portainer/Docker API responses directly

## File Organization

- **One public type per file** — each public/internal struct, class, enum, or protocol goes in its own `.swift` file
- **Private helpers stay with their owner** — small private types used only by a single class (e.g. lock wrappers, weak reference wrappers) remain in that class's file
- **Directory structure by role**:
  - `Models/` — data types: Codable API models, error types, enums
  - `Services/` — networking, persistence, and other service layers
  - `Views/` — SwiftUI views
  - `ViewModels/` — `@Observable` view models

## Key Constraints

- **No third-party dependencies** — Apple frameworks only (URLSession, Security, SwiftData, SwiftUI)
- **Xcode uses file system synchronized groups** — files added to `Portasaurus/Portasaurus/` are auto-discovered; no manual pbxproj edits needed for new Swift files
- **Deployment targets**: iOS 26+, macOS 26+, visionOS 26+ (Xcode 26.3)
- **Bundle ID**: `com.snailengineering.swift.Portasaurus`
- **App Sandbox and Hardened Runtime** are enabled
- **Platform-adaptive**: use `#if os()` only when truly needed; lean on SwiftUI's built-in adaptivity

## Portainer API Pattern

All Docker operations proxy through Portainer: `/api/endpoints/{envId}/docker/...` (standard Docker Engine API responses). Portainer-native endpoints (stacks, auth, system) are at `/api/...` with no version prefix. Auth is JWT via `POST /api/auth` with 8-hour expiry, no refresh — re-authenticate on 401.

## Git Workflow

- **Before starting any work**, create a feature branch off `main` (e.g., `feat/phase-1-server-connection`, `fix/auth-token-handling`)
- **Commit after completing each task** using [Conventional Commits](https://www.conventionalcommits.org/):
  - `feat:` — new feature
  - `fix:` — bug fix
  - `refactor:` — code restructuring without behavior change
  - `test:` — adding or updating tests
  - `chore:` — build config, project settings, non-code changes
  - `docs:` — documentation changes
  - Include scope when useful, e.g. `feat(auth): implement JWT login flow`
- Keep commits granular — one logical change per commit so diffs are easy to review
- Do NOT push unless explicitly asked

## README.md

Do **not** edit anything above the `## Target` heading in README.md. Everything above that line is maintained by the user.

## Development Approach

This project is built incrementally, one phase at a time per the checklist in README.md. Each phase should be complete and testable before starting the next. Avoid adding code for future phases.
