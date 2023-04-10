#include <ArduinoBLE.h>

// Define the central device, service, and characteristics
BLEDevice central;
BLEService sensorService("180D");
BLEByteCharacteristic sensorDataCharacteristic("2A37", BLERead | BLENotify);
BLEUnsignedIntCharacteristic timeStampCharacteristic("2A38", BLERead | BLENotify);

// Define the time synchronization service and characteristic
BLEService timeSyncService("180F");
BLEUnsignedIntCharacteristic currentTimeCharacteristic("2A39", BLERead | BLENotify);

// Variables to keep track of time
unsigned long currentTime = 0;
unsigned long previousTime = 0;
unsigned long startTime = 0;
const long interval = 3000; // Interval for sending random sensor values (3 seconds)

void setup() {
  // Initialize serial communication
  Serial.begin(9600);
  while (!Serial);

  // Initialize BLE and check for errors
  if (!BLE.begin()) {
    Serial.println("Starting BLE failed!");
    while (1);
  }

  // Set the device name and advertised service
  BLE.setLocalName("Sensor Tracker");
  BLE.setAdvertisedService(sensorService);

  // Add characteristics to the sensor service
  sensorService.addCharacteristic(sensorDataCharacteristic);
  sensorService.addCharacteristic(timeStampCharacteristic);
  BLE.addService(sensorService);

  // Add the time synchronization characteristic to the time sync service
  timeSyncService.addCharacteristic(currentTimeCharacteristic);
  BLE.addService(timeSyncService);

  // Initialize characteristics with default values
  sensorDataCharacteristic.writeValue(0);
  timeStampCharacteristic.writeValue(0);

  // Start advertising the BLE device
  BLE.advertise();
  Serial.println("Bluetooth device active, waiting for connections...");
}

void loop() {
  // Attempt to connect to the central device
  central = BLE.central();

  // Check if the central device is connected
  if (central) {
    Serial.print("Connected to central: ");
    Serial.println(central.address());

    // Loop while the central device is connected
    while (central.connected()) {
      currentTime = millis();
      if (startTime == 0) {
        startTime = currentTime;
      }
      
      // Check if the interval has elapsed
      if (currentTime - previousTime >= interval) {
        previousTime = currentTime;
        
        // Calculate the Unix timestamp based on the synced time
        unsigned long unixTime = startTime + (currentTime / 1000);
        timeStampCharacteristic.writeValue(unixTime); // Send the Unix timestamp

        // Generate a random sensor value between 0 and 255
        byte randomSensorValue = random(0, 256);
        sensorDataCharacteristic.writeValue(randomSensorValue); // Send the random sensor value
      }
    }
    startTime = 0;
    Serial.print("Disconnected from central: ");
    Serial.println(central.address());
  }
}