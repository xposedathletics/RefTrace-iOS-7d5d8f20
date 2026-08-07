import SwiftUI
import CoreData

@main
struct RefTraceAppApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            RefTraceRootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
