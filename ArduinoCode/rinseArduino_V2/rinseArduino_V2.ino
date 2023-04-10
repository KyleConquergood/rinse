#include <ArduinoBLE.h>

// Create a BLE service and two characteristics
BLEService sensorService("180D"); 
BLEUnsignedIntCharacteristic sensorDataCharacteristic("2A37", BLERead | BLENotify);
BLEUnsignedIntCharacteristic timeStampCharacteristic("2A38", BLERead | BLENotify);

unsigned int counter = 0;

void setup() {
  Serial.begin(9600); // Initialize serial communication

  if (!BLE.begin()) { // Initialize BLE library
    Serial.println("Starting BLE failed!"); // Print error message if initialization fails
    while (1); // Stay in loop indefinitely
  }

  BLE.setLocalName("SensorTracker"); // Set the local name for the device
  BLE.setAdvertisedService(sensorService); // Set the advertised BLE service

  // Add characteristics to the BLE service
  sensorService.addCharacteristic(sensorDataCharacteristic);
  sensorService.addCharacteristic(timeStampCharacteristic);

  BLE.addService(sensorService); // Add BLE service to the device

  // Set initial values for the characteristics
  sensorDataCharacteristic.writeValue(0);
  timeStampCharacteristic.writeValue(0);

  BLE.advertise(); // Start advertising the device

  Serial.println("BLE device initialized");
  Serial.println("Sensor Tracker is ready to connect"); // Print message indicating device is ready
}

void loop() {
  BLEDevice central = BLE.central(); // Check if a central device is connected

  if (central) { // If a central device is connected
    Serial.print("Connected to central: ");
    Serial.println(central.address()); // Print the address of the connected device

    while (central.connected()) { // While the central device is connected
      sendData(); // Send data
    }

    Serial.print("Disconnected from central: ");
    Serial.println(central.address()); // Print the address of the disconnected device
  }
}

void sendData() {
  counter++; // Increment counter
  unsigned long currentTime = millis(); // Get the current time

  sensorDataCharacteristic.writeValue(counter); // Write the counter value to sensor data characteristic
  timeStampCharacteristic.writeValue((uint32_t)currentTime); // Write the timestamp characteristic value

  Serial.print("Data sent: ");
  Serial.println(counter); // Print the counter value
  Serial.print("Timestamp: ");
  Serial.println(currentTime); // Print the timestamp

  delay(1000); // Wait for 1 second before sending the next value
}