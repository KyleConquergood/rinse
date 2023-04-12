//
//  rinseApp.swift
//  rinse
//
//  Created by kyle on 2023-04-08.
//

import SwiftUI
import CoreData
import UserNotifications

@main
struct RinseApp: App {
    @Environment(\.scenePhase) private var scenePhase
    
    let persistenceController = PersistenceController.shared
    var bluetoothManager: BluetoothManager

    init() {
        let managedObjectContext = persistenceController.container.viewContext
        bluetoothManager = BluetoothManager(managedObjectContext: managedObjectContext)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(bluetoothManager)
                .onChange(of: scenePhase) { phase in
                    switch phase {
                    case .background, .inactive:
                        persistenceController.saveContext()
                    default:
                        break
                    }
                }
        }
    }
}
