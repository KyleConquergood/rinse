//
//  BluetoothManager.swift
//  rinse
//
//  Created by kyle on 2023-04-08.
//

import Foundation
import CoreBluetooth
import CoreData

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

    // Published sensor data and timestamp
    @Published var sensorData: UInt32 = 0
    @Published var timeStamp: UInt32 = 0
    
    @Published var logs: [LogEntity] = []
    @Published var logsChanged = false
    
    // Add managedObjectContext as a parameter in the initializer
    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
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
        centralManager.stopScan()
        sensorTrackerPeripheral?.discoverServices([sensorServiceUUID, timeSyncServiceUUID])
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
                if characteristic.uuid == sensorDataCharacteristicUUID || characteristic.uuid == timeStampCharacteristicUUID || characteristic.uuid == currentTimeCharacteristicUUID {
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
        PersistenceController.shared.container.performBackgroundTask { backgroundContext in
            let logEntity = LogEntity(context: backgroundContext)
            logEntity.timestamp = Int64(log.timestamp)
            logEntity.source = log.source

            do {
                try backgroundContext.save()
                print("Log saved: \(logEntity)")

                DispatchQueue.main.async {
                    completion() // Add this line
                }
            } catch {
                print("Error saving log:", error.localizedDescription)
            }
            print("Auto log registered.")
        }
    }
    

    func manualLog(completion: (() -> Void)? = nil) {
        PersistenceController.shared.container.performBackgroundTask { backgroundContext in
            let log = LogEntity(context: backgroundContext)
            log.source = "Manual"
            log.timestamp = Int64(Date().timeIntervalSince1970)

            do {
                try backgroundContext.save()
                print("Log saved:", log)

                DispatchQueue.main.async {
                    completion?()
                }
            } catch {
                print("Error saving log:", error.localizedDescription)
            }
            print("Manual log registered.")
        }
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
                DispatchQueue.main.async {
                    self.logsChanged.toggle()
                }
            } catch {
                print("Error deleting logs:", error.localizedDescription)
            }
        }
    }
}
