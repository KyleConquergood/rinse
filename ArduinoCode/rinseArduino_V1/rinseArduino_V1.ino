#include <ArduinoBLE.h>

// Sensor and Bluetooth configurations
const int sensorPin = 2; // Choose the appropriate digital pin connected to sensor
const int sensorThreshold = 500; // Set a threshold for the sensor to trigger
const int debounceDelay = 50; // Add debounce delay to avoid multiple triggers, may have to change dely length

// Create a BLE service and two characteristics
BLEService sensorService("180D"); 
BLEUnsignedIntCharacteristic sensorDataCharacteristic("2A37", BLERead | BLENotify);
BLEUnsignedIntCharacteristic timeStampCharacteristic("2A38", BLERead | BLENotify);

// Initialize variables
unsigned long lastTriggerTime = 0;
int sensorState = 0;

void setup() {
  Serial.begin(9600); // Initialize serial communication

  pinMode(sensorPin, INPUT); // Set the sensor pin as an input

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

  Serial.println("Sensor Tracker is ready to connect"); // Print message indicating device is ready
}

void loop() {
  BLEDevice central = BLE.central(); // Check if a central device is connected

  if (central) { // If a central device is connected
    Serial.print("Connected to central: ");
    Serial.println(central.address()); // Print the address of the connected device

    while (central.connected()) { // While the central device is connected
      checkSensorAndSendData(); // Check the sensor and send data
    }

    Serial.print("Disconnected from central: ");
    Serial.println(central.address()); // Print the address of the disconnected device
  }
}

void checkSensorAndSendData() {
  int currentSensorValue = digitalRead(sensorPin); // Read the value from the sensor

  if (currentSensorValue != sensorState) { // If the sensor value has changed
    unsigned long currentTime = millis(); // Get the current time

    if ((currentTime - lastTriggerTime) > debounceDelay) { // If debounce delay has passed
      lastTriggerTime = currentTime; // Update last trigger time
      sensorState = currentSensorValue; // Update sensor state

      if (sensorState) { // If sensor has been triggered
        Serial.println("Sensor triggered!"); // Print message indicating sensor has been triggered
        sensorDataCharacteristic.writeValue(1); // Write the sensor data characteristic value to 1
        timeStampCharacteristic.writeValue((uint32_t)currentTime); // Write the timestamp characteristic value
      } else {
        Serial.println("Sensor reset."); // Print message indicating sensor has been reset
        sensorDataCharacteristic.writeValue(0); // Write the sensor data characteristic value to 0
      }
    }
  }
}