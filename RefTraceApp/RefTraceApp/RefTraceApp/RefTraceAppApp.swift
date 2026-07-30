//
//  RefTraceAppApp.swift
//  RefTraceApp
//
//  Created by Harvey Watson on 7/22/26.
//

import SwiftUI
import CoreData

@main
struct RefTraceAppApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
