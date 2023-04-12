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
    
    func updateLogs() {
        logs = bluetoothManager.fetchLogs()
        print("Logs updated")
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
                bluetoothManager.manualLog(completion: updateLogs)
            }) {
                Text("Manual Log")
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            
            Button(action: {
                bluetoothManager.deleteAllLogs()
                updateLogs()
            }) {
                Text("Delete All Logs")
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(8)
            }
            
            Button(action: {
                bluetoothManager.sendReminderSignal()
            }) {
                Text("Send Reminder")
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.green)
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
        .overlay(
            Group {
                if bluetoothManager.isConnected {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 10, height: 10)
                }
            },
            alignment: .topLeading
        )
        .onAppear {
            logs = bluetoothManager.fetchLogs()
        }
        .onChange(of: bluetoothManager.logsChanged) { _ in
            updateLogs()
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
