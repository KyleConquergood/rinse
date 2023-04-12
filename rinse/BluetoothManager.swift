//
//  BluetoothManager.swift
//  rinse
//
//  Created by kyle on 2023-04-08.
//

import Foundation
import CoreBluetooth
import CoreData
import UserNotifications
import Combine

struct Log {
    var timestamp: Int
    var source: String
}

class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    // Central Manager and Peripheral
    private var centralManager: CBCentralManager!
    private var sensorTrackerPeripheral: CBPeripheral?
    public var managedObjectContext: NSManagedObjectContext
    
    // UUIDs for Service and Characteristics
    private let sensorServiceUUID = CBUUID(string: "180D")
    private let sensorDataCharacteristicUUID = CBUUID(string: "2A37")
    private let timeStampCharacteristicUUID = CBUUID(string: "2A38")
    private let timeSyncServiceUUID = CBUUID(string: "180F")
    private let currentTimeCharacteristicUUID = CBUUID(string: "2A39")
    private let syncTimeCharacteristicUUID = CBUUID(string: "2A3A") // New characteristic for sync time
    private let reminderCharacteristicUUID = CBUUID(string: "2A3B") // custom UUID for the reminder characteristic
    private var cancellables = Set<AnyCancellable>()

    // Published sensor data and timestamp
    @Published var sensorData: UInt32 = 0
    @Published var timeStamp: UInt32 = 0
    
    @Published var logs: [LogEntity] = []
    @Published var logsChanged = false
    
    @Published var isConnected: Bool = false
    
    // Add managedObjectContext as a parameter in the initializer
    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        requestNotificationPermission()
        _logsChanged.projectedValue.receive(on: DispatchQueue.main).sink { _ in self.logs = self.fetchLogs() }.store(in: &cancellables)
        
        // Fetch and print logs and medication schedules
        let fetchedLogs = fetchLogs()
        print("Stored logs:")
        fetchedLogs.forEach { log in
            print("Timestamp: \(log.timestamp), Source: \(log.source ?? "")")
        }
        
        let fetchedSchedules = fetchMedicationSchedules()
        print("Stored medication schedules:")
        fetchedSchedules.forEach { schedule in
            print("Name: \(schedule.name ?? ""), Time: \(schedule.time), Repeats daily: \(schedule.repeatsDaily)")
        }
    }
    
    // Central Manager state update
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: [sensorServiceUUID, timeSyncServiceUUID], options: nil)
        } else {
            print("Central is not powered on")
        }
    }
    
    // Discover peripheral with target service UUID
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        sensorTrackerPeripheral = peripheral
        sensorTrackerPeripheral?.delegate = self
        centralManager.connect(sensorTrackerPeripheral!, options: nil)
    }
    
    // Connect to peripheral and discover services
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to Sensor Tracker")
        isConnected = true
        centralManager.stopScan()
        sensorTrackerPeripheral?.discoverServices([sensorServiceUUID, timeSyncServiceUUID])
    }
    
    // Handle disconention from target service
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from Sensor Tracker")
        isConnected = false
        if central.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: [sensorServiceUUID, timeSyncServiceUUID], options: nil)
        }
    }
    
    // Discover characteristics for target service
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            for service in services {
                if service.uuid == sensorServiceUUID || service.uuid == timeSyncServiceUUID {
                    peripheral.discoverCharacteristics(nil, for: service)
                }
            }
        }
    }

    // Enable notifications for target characteristics and write current time to syncTimeCharacteristic
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                if characteristic.uuid == sensorDataCharacteristicUUID || characteristic.uuid == timeStampCharacteristicUUID || characteristic.uuid == currentTimeCharacteristicUUID || characteristic.uuid == reminderCharacteristicUUID {
                    peripheral.setNotifyValue(true, for: characteristic)
                }
                if characteristic.uuid == syncTimeCharacteristicUUID {
                    var currentTime = UInt32(Date().timeIntervalSince1970)
                    peripheral.writeValue(Data(bytes: &currentTime, count: MemoryLayout<UInt32>.size), for: characteristic, type: .withResponse)
                }
            }
        }
    }

    // Update published properties when new data is received
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic.uuid == sensorDataCharacteristicUUID {
            if let sensorDataValue = characteristic.value {
                sensorData = UInt32(sensorDataValue[0])
            }
        }

        if characteristic.uuid == timeStampCharacteristicUUID {
            if let timeStampValue = characteristic.value {
                timeStamp = timeStampValue.withUnsafeBytes { $0.load(as: UInt32.self) }
                addLog(log: Log(timestamp: Int(timeStamp), source: "Arduino"), completion: { [weak self] in
                    self?.logsChanged.toggle()
                })
            }
        }
        
        if characteristic.uuid == currentTimeCharacteristicUUID {
            if let currentTimeValue = characteristic.value {
                let currentTime = currentTimeValue.withUnsafeBytes { $0.load(as: UInt32.self) }
                let unixTime = Date(timeIntervalSince1970: TimeInterval(currentTime))
                print("Arduino current time: \(unixTime)")
            }
        }
    }
    
    func addLog(log: Log, completion: @escaping () -> Void) {
        let logEntity = LogEntity(context: self.managedObjectContext)
        logEntity.timestamp = Int64(log.timestamp)
        logEntity.source = log.source

        do {
            try self.managedObjectContext.save()
            print("Log saved: \(logEntity)")

            DispatchQueue.main.async {
                completion()
            }
        } catch {
            print("Error saving log:", error.localizedDescription)
        }
        print("Auto log registered.")
    }
    

    func manualLog(completion: (() -> Void)? = nil) {
        let log = LogEntity(context: self.managedObjectContext)
        log.source = "Manual"
        log.timestamp = Int64(Date().timeIntervalSince1970)

        do {
            try self.managedObjectContext.save()
            print("Log saved:", log)

            DispatchQueue.main.async {
                let fetchedLogs = self.fetchLogs()
                print("Stored logs:")
                fetchedLogs.forEach { log in
                    print("Timestamp: \(log.timestamp), Source: \(log.source ?? "")")
                }
                
                let fetchedSchedules = self.fetchMedicationSchedules()
                print("Stored medication schedules:")
                fetchedSchedules.forEach { schedule in
                    print("Name: \(schedule.name ?? ""), Time: \(schedule.time), Repeats daily: \(schedule.repeatsDaily)")
                }
                completion?()
            }
        } catch {
            print("Error saving log:", error.localizedDescription)
        }
        print("Manual log registered.")
    }
    
    func fetchLogs() -> [LogEntity] {
        let request: NSFetchRequest<LogEntity> = LogEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \LogEntity.timestamp, ascending: false)]

        do {
            let logs = try managedObjectContext.fetch(request)
            return logs
        } catch {
            print("Error fetching logs:", error.localizedDescription)
        }
        return []
    }
    
    func deleteAllLogs() {
        PersistenceController.shared.container.performBackgroundTask { backgroundContext in
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = LogEntity.fetchRequest()

            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

            do {
                try backgroundContext.execute(deleteRequest)
                try backgroundContext.save()
                DispatchQueue.main.async {
                    self.logsChanged.toggle()
                }
            } catch {
                print("Error deleting logs:", error.localizedDescription)
            }
        }
    }
    
    func sendReminderSignal() {
        guard let peripheral = sensorTrackerPeripheral else {
            print("Peripheral not found")
            return
        }
        guard let service = peripheral.services?.first(where: { $0.uuid == timeSyncServiceUUID }) else {
            print("Service not found")
            return
        }
        guard let characteristic = service.characteristics?.first(where: { $0.uuid == reminderCharacteristicUUID }) else {
            print("Characteristic not found")
            return
        }

        var reminderSignal: UInt8 = 1
        let reminderData = Data(bytes: &reminderSignal, count: MemoryLayout<UInt8>.size)
        peripheral.writeValue(reminderData, for: characteristic, type: .withResponse)
        print("Reminder signal sent")
    }
    
    func addMedicationSchedule(name: String, time: Date, repeatsDaily: Bool, completion: (() -> Void)? = nil) {
        PersistenceController.shared.container.performBackgroundTask { backgroundContext in
            let medicationSchedule = MedicationSchedule(context: backgroundContext)
            medicationSchedule.name = name
            medicationSchedule.time = time
            medicationSchedule.repeatsDaily = repeatsDaily

            do {
                try backgroundContext.save()
                let medicationTime = medicationSchedule.time // Extract the time value here
                print("Medication schedule saved: Name: \(medicationSchedule.name ?? ""), Time: \(medicationTime)") // Use the extracted time value

                DispatchQueue.main.async {
                    self.scheduleNotification(for: medicationSchedule, time: medicationTime) // Schedule the notification
                    completion?()
                }
            } catch {
                print("Error saving medication schedule:", error.localizedDescription)
            }
        }
    }
    
    func fetchMedicationSchedules() -> [MedicationSchedule] {
        let request: NSFetchRequest<MedicationSchedule> = MedicationSchedule.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MedicationSchedule.time, ascending: true)]

        do {
            let schedules = try managedObjectContext.fetch(request)
            return schedules
        } catch {
            print("Error fetching medication schedules:", error.localizedDescription)
        }
        return []
    }
    
    func deleteAllMedicationSchedules(completion: (() -> Void)? = nil) {
        PersistenceController.shared.container.performBackgroundTask { backgroundContext in
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = MedicationSchedule.fetchRequest()

            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

            do {
                try backgroundContext.execute(batchDeleteRequest)
                try backgroundContext.save()
                print("All medication schedules deleted")
                
                DispatchQueue.main.async {
                    completion?()
                }
            } catch {
                print("Error deleting all medication schedules:", error.localizedDescription)
            }
        }
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else {
                print("Notification permission denied")
            }
        }
    }
    
    func scheduleNotification(for medicationSchedule: MedicationSchedule, time: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Medication Reminder"
        content.body = "It's time to take \(medicationSchedule.name ?? "your medication")"
        content.sound = UNNotificationSound.default

        let components = Calendar.current.dateComponents([.hour, .minute], from: time)

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: medicationSchedule.repeatsDaily)

        let identifier = UUID().uuidString // Unique identifier for the notification
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            } else {
                print("Notification scheduled for \(medicationSchedule.name ?? "medication") at \(time)")
            }
        }

        // Schedule the reminder signal check
        scheduleReminderSignal(for: identifier, time: time)
    }
    
    func scheduleReminderSignal(for notificationIdentifier: String, time: Date) {
        let timeInterval = time.timeIntervalSinceNow
        DispatchQueue.main.asyncAfter(deadline: .now() + timeInterval) {
            self.checkNotificationDelivery(for: notificationIdentifier)
        }
    }
    
    func checkNotificationDelivery(for notificationIdentifier: String) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            if requests.contains(where: { $0.identifier == notificationIdentifier }) {
                // If the notification is still pending, reschedule the check
                self.scheduleReminderSignal(for: notificationIdentifier, time: Date().addingTimeInterval(1))
            } else {
                // If the notification is not pending, send the reminder signal
                self.sendReminderSignal()
            }
        }
    }
    
}
