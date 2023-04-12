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
    
    // Add the following state properties for medication schedule input
    @State private var medicationName: String = ""
    @State private var medicationTime: Date = Date()
    @State private var repeatsDaily: Bool = false
    
    // Add a function to save medication schedules
    func saveMedicationSchedule() {
        bluetoothManager.addMedicationSchedule(name: medicationName, time: medicationTime, repeatsDaily: repeatsDaily) {
            print("Medication schedule saved with notification")
        }
        
        medicationName = ""
        medicationTime = Date()
        repeatsDaily = false
    }
    
    
    var body: some View {
        // Add the following VStack for medication schedule input
        TabView{
            VStack(spacing: 10) {
                TextField("Medication Name", text: $medicationName)
                    .padding()
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
                DatePicker("Medication Time", selection: $medicationTime, displayedComponents: [.hourAndMinute])
                    .padding()
                    .background(Color.white)
                    .cornerRadius(8)
                    .padding()
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
                Toggle(isOn: $repeatsDaily) { // Add this Toggle to let the user choose the repeat daily option
                    Text("Repeat daily")
                }
                .padding()
                Button(action: saveMedicationSchedule) {
                    Text("Save Medication Schedule")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                Button(action: {
                    bluetoothManager.deleteAllMedicationSchedules()
                }) {
                    Text("Delete All Medication Schedules")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(8)
                }
            }
            
            .tabItem {
                Image(systemName: "pills")
                Text("Medication Schedule")
            }
            
            VStack(spacing: 20) {
                
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
            .tabItem {
                Image(systemName: "chart.bar.xaxis")
                Text("Logs")
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
}
