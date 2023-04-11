//
//  ContentView.swift
//  rinse
//
//  Created by kyle on 2023-04-08.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    private var managedObjectContext: NSManagedObjectContext {
        bluetoothManager.managedObjectContext
    }
    
    @State private var logs: [LogEntity] = []
    
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
                logs = bluetoothManager.fetchLogs()
            }) {
                Text("Manual Log")
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(logs, id: \.self) { log in
                        HStack {
                            Text("\(log.source ?? "")")
                            Spacer()
                            Text("\(Date(timeIntervalSince1970: TimeInterval(log.timestamp)))")
                        }
                        .onAppear {
                            print(log) // Add this line to check if logs have data
                        }
                    }
                }
            }
        }
        .padding()
        .onAppear {
            logs = bluetoothManager.fetchLogs()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController.shared
        let bluetoothManager = BluetoothManager(managedObjectContext: persistenceController.container.viewContext)
        return ContentView()
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
            .environmentObject(bluetoothManager)
    }
}
