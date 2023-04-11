//
//  rinseApp.swift
//  rinse
//
//  Created by kyle on 2023-04-08.
//

import SwiftUI
import CoreData

@main
struct RinseApp: App {
    let persistenceController = PersistenceController.shared
    var bluetoothManager: BluetoothManager

    init() {
        let managedObjectContext = persistenceController.container.viewContext
        bluetoothManager = BluetoothManager(managedObjectContext: managedObjectContext)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bluetoothManager)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
