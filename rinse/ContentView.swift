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
        updateProgressValues()
    }
    
    func fetchMedicationSchedules() {
        medicationSchedules = bluetoothManager.fetchMedicationSchedules()
        updateProgressValues()
    }
    
    @State private var logs: [LogEntity] = []
    @State private var medicationSchedules: [MedicationSchedule] = []
    @State private var weeklyProgress: Double = 0.0
    @State private var monthlyProgress: Double = 0.0

    
    // Add the following state properties for medication schedule input
    @State private var medicationName: String = ""
    @State private var medicationTime: Date = Date()
    @State private var repeatsDaily: Bool = false
    
    // Add a function to save medication schedules
    func saveMedicationSchedule() {
        bluetoothManager.addMedicationSchedule(name: medicationName, time: medicationTime, repeatsDaily: repeatsDaily) {
            fetchMedicationSchedules()
            print("Medication schedule saved with notification")
        }

        medicationName = ""
        medicationTime = Date()
        repeatsDaily = false
    }
    
    func medicationAdherencePercentage(logs: [LogEntity], medicationSchedules: [MedicationSchedule], startDate: Date, endDate: Date) -> Double {
        let calendar = Calendar.current
        var currentDate = startDate
        var adherenceDays = 0
        var totalDays = 0
        
        while currentDate <= endDate {
            totalDays += 1
            let dayLogs = logs.filter { log in
                let logDate = Date(timeIntervalSince1970: TimeInterval(log.timestamp))
                return calendar.isDate(logDate, inSameDayAs: currentDate)
            }
            
            var dayAdherence = true
            for schedule in medicationSchedules {
                let scheduleTime = calendar.dateComponents([.hour, .minute], from: schedule.time)
                let adherenceWindowStart = calendar.date(bySettingHour: scheduleTime.hour!, minute: scheduleTime.minute!, second: 0, of: currentDate)!
                let adherenceWindowEnd = calendar.date(bySettingHour: scheduleTime.hour!, minute: scheduleTime.minute! + 30, second: 59, of: currentDate)!
                
                let correctLog = dayLogs.first { log in
                    let logDate = Date(timeIntervalSince1970: TimeInterval(log.timestamp))
                    return logDate >= adherenceWindowStart && logDate <= adherenceWindowEnd
                }
                
                if correctLog == nil {
                    dayAdherence = false
                    break
                }
            }
            
            if dayAdherence {
                adherenceDays += 1
            }
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return (Double(adherenceDays) / Double(totalDays)) * 100
    }
    
    func updateProgressValues() {
        let now = Date()
        let weeklyStartDate = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        let monthlyStartDate = Calendar.current.date(byAdding: .month, value: -1, to: now) ?? now
        
        weeklyProgress = medicationAdherencePercentage(logs: logs, medicationSchedules: medicationSchedules, startDate: weeklyStartDate, endDate: now)
        monthlyProgress = medicationAdherencePercentage(logs: logs, medicationSchedules: medicationSchedules, startDate: monthlyStartDate, endDate: now)
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
                Toggle(isOn: $repeatsDaily) {
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
                    bluetoothManager.deleteAllMedicationSchedules() {
                        fetchMedicationSchedules()
                    }
                }) {
                    Text("Delete All Medication Schedules")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(8)
                }

                List {
                    ForEach(medicationSchedules, id: \.self) { schedule in
                        VStack(alignment: .leading) {
                            Text(schedule.name ?? "Unknown")
                                .font(.headline)
                            Text("Time: \(schedule.time, style: .time)")
                            if schedule.repeatsDaily {
                                Text("Repeats daily")
                            }
                        }
                        .padding()
                    }
                }
            }
            .onAppear {
                fetchMedicationSchedules()
            }
            .tabItem {  
                Image(systemName: "pills")
                Text("Medication Schedule")
            }
            
            VStack {
//                ProgressRingView(weeklyProgress: weeklyProgress, monthlyProgress: monthlyProgress)
//                    .frame(width: 200, height: 200)
                ProgressRingView(weeklyProgress: 0.75, monthlyProgress: 0.4)
                    .frame(width: 200, height: 200)
            }
            .tabItem {
                Image(systemName: "chart.pie")
                Text("Data Visualization")
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
