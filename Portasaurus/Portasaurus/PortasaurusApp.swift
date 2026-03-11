import SwiftUI
import SwiftData

@main
struct PortasaurusApp: App {

    private let modelContainer: ModelContainer = {
        let schema = Schema([SavedServer.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ServerListView()
        }
        .modelContainer(modelContainer)
    }
}
