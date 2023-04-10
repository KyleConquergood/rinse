//
//  BluetoothManager.swift
//  rinse
//
//  Created by kyle on 2023-04-08.
//

import Foundation
import CoreBluetooth

class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    // Central Manager and Peripheral
    private var centralManager: CBCentralManager!
    private var sensorTrackerPeripheral: CBPeripheral?
    
    // UUIDs for Service and Characteristics
    private let sensorServiceUUID = CBUUID(string: "180D")
    private let sensorDataCharacteristicUUID = CBUUID(string: "2A37")
    private let timeStampCharacteristicUUID = CBUUID(string: "2A38")
    private let timeSyncServiceUUID = CBUUID(string: "180F")
    private let currentTimeCharacteristicUUID = CBUUID(string: "2A39")
    
    // Published sensor data and timestamp
    @Published var sensorData: UInt32 = 0
    @Published var timeStamp: UInt32 = 0
    
    @Published var dataModel = DataModel()
    
    // Initialize the Central Manager
    override init() {
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

    // Enable notifications for target characteristics
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                if characteristic.uuid == sensorDataCharacteristicUUID || characteristic.uuid == timeStampCharacteristicUUID || characteristic.uuid == currentTimeCharacteristicUUID {
                    peripheral.setNotifyValue(true, for: characteristic)
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
                dataModel.addLog(log: Log(timestamp: Int(timeStamp), source: "Arduino"))
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

    func manualLog() {
        sensorData = 1
        timeStamp = UInt32(Date().timeIntervalSince1970)
        
        // Add this line to store the log created manually
        dataModel.addLog(log: Log(timestamp: Int(timeStamp), source: "Manual"))
        
        print("Manual log registered.")
    }
}
