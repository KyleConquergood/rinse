//
//  ContentView.swift
//  rinse
//
//  Created by kyle on 2023-04-08.
//

import SwiftUI

struct ContentView: View {
    // Create an instance of BluetoothManager
    @StateObject private var bluetoothManager = BluetoothManager()

    var body: some View {
        // Display the sensor data and timestamp
        VStack(spacing: 20) {
            Text("Sensor Data")
                .font(.title)
            Text("\(bluetoothManager.sensorData)")
                .font(.largeTitle)
            Text("Timestamp")
                .font(.title)
            Text("\(bluetoothManager.timeStamp)")
                .font(.largeTitle)
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
