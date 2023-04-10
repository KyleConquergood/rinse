//
//  ContentView.swift
//  rinse
//
//  Created by kyle on 2023-04-08.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager

    var body: some View {
        VStack(spacing: 20) {
            Text("Sensor Data")
                .font(.title)
            Text("\(bluetoothManager.sensorData)")
                .font(.largeTitle)
            Text("Timestamp")
                .font(.title)
            Text("\(bluetoothManager.timeStamp)")
                .font(.largeTitle)
            
            Button(action: {
                bluetoothManager.manualLog()
            }) {
                Text("Manual Log")
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(8)
            }
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(BluetoothManager())
    }
}
