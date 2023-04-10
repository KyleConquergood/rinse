#include <ArduinoBLE.h>

// Declare BLE objects
BLEDevice central;
BLEService sensorService("180D");
BLEByteCharacteristic sensorDataCharacteristic("2A37", BLERead | BLENotify);
BLEUnsignedIntCharacteristic timeStampCharacteristic("2A38", BLERead | BLENotify);

BLEService timeSyncService("180F");
BLEUnsignedIntCharacteristic currentTimeCharacteristic("2A39", BLERead | BLENotify);
BLEUnsignedIntCharacteristic syncTimeCharacteristic("2A3A", BLEWrite); // New characteristic to receive the synced Unix time


// Declare variables for timing and syncing
unsigned long currentTime = 0;
unsigned long previousTime = 0;
unsigned long startTime = 0;
const long interval = 3000;

// Function for handling incoming synced Unix time
void syncTimeReceived(BLEDevice central, BLECharacteristic characteristic) {
  startTime = *((unsigned long *) characteristic.value()) - (millis() / 1000);

  // Print the value of startTime to the serial monitor
  Serial.print("Received synced time: ");
  Serial.println(startTime);
}

void setup() {
  Serial.begin(9600);
  while (!Serial);

  // Initialize BLE module
  if (!BLE.begin()) {
    Serial.println("Starting BLE failed!");
    while (1);
  }

  // Set BLE device name and advertised service
  BLE.setLocalName("Sensor Tracker");
  BLE.setAdvertisedService(sensorService);

  // Add characteristics to the sensor service
  sensorService.addCharacteristic(sensorDataCharacteristic);
  sensorService.addCharacteristic(timeStampCharacteristic);
  BLE.addService(sensorService);

  // Add characteristics to the time sync service and set the event handler for synced time
  timeSyncService.addCharacteristic(currentTimeCharacteristic);
  timeSyncService.addCharacteristic(syncTimeCharacteristic); // Add the new characteristic to the service
  BLE.addService(timeSyncService);

  syncTimeCharacteristic.setEventHandler(BLEWritten, syncTimeReceived); // Set the event handler for receiving the synced Unix time
  Serial.println("Sync time event handler set"); 

  // Initialize characteristics to zero and advertise BLE device
  sensorDataCharacteristic.writeValue(0);
  timeStampCharacteristic.writeValue(0);

  BLE.advertise();
  Serial.println("Bluetooth device active, waiting for connections...");
}

void loop() {
  // Check for central device connection
  central = BLE.central();

  if (central) {
    // Print connected central device address
    Serial.print("Connected to central: ");
    Serial.println(central.address());

    // Loop while central device is connected
    while (central.connected()) {
      currentTime = millis();
      
      // Check if interval has elapsed for updating sensor data
      if (currentTime - previousTime >= interval) {
        previousTime = currentTime;
        unsigned long unixTime = startTime + (currentTime / 1000);
        timeStampCharacteristic.writeValue(unixTime);

        byte randomSensorValue = random(0, 256);
        sensorDataCharacteristic.writeValue(randomSensorValue);
        
        // Print the data and timestamp to the serial monitor
        Serial.print("Data: ");
        Serial.print(randomSensorValue);
        Serial.print(" | Timestamp: ");
        Serial.println(unixTime);
      }
    }
    // Reset start time and print disconnected central device address
    startTime = 0;
    Serial.print("Disconnected from central: ");
    Serial.println(central.address());
  }
}