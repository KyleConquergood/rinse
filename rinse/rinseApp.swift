//
//  rinseApp.swift
//  rinse
//
//  Created by kyle on 2023-04-08.
//

import SwiftUI

@main
struct RinseApp: App {
    var bluetoothManager = BluetoothManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bluetoothManager)
        }
    }
}
