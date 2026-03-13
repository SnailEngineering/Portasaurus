import SwiftUI
import SwiftData
import OSLog

@main
struct PortasaurusApp: App {

    private let modelContainer: ModelContainer = {
        let schema = Schema([SavedServer.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Schema migration failed (e.g. a new property was added during development).
            // Wipe the store and start fresh rather than hard-crashing.
            // In production this would need a proper migration plan instead.
            AppLogger.persistence.error("ModelContainer creation failed, recreating store: \(error)")
            let storeURL = config.url
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Could not recreate ModelContainer after wiping store: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ServerListView()
        }
        .modelContainer(modelContainer)
    }
}
