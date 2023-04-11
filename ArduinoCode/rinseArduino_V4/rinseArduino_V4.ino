#include <ArduinoBLE.h>
#include <ArduinoQueue.h>

// Declare BLE objects
BLEDevice central;
BLEService sensorService("180D");
BLEByteCharacteristic sensorDataCharacteristic("2A37", BLERead | BLENotify);
BLEUnsignedIntCharacteristic timeStampCharacteristic("2A38", BLERead | BLENotify);

BLEService timeSyncService("180F");
BLEUnsignedIntCharacteristic currentTimeCharacteristic("2A39", BLERead | BLENotify);
BLEUnsignedIntCharacteristic syncTimeCharacteristic("2A3A", BLEWrite);
BLEByteCharacteristic reminderSignalCharacteristic("2A3B", BLEWrite);

// Declare variables for timing and syncing
unsigned long currentTime = 0;
unsigned long previousTime = 0;
unsigned long startTime = 0;
const long interval = 10000;
bool timeSynced = false;
bool prevTimeSync = false;
bool waitingForCacheSend = false;
unsigned long cacheSendStartTime = 0;
const unsigned long cacheSendDelay = 10000;
bool generatingData = false;

// Declare queues for unsent data
ArduinoQueue<unsigned long> unsentTimestamps(50);
ArduinoQueue<byte> unsentSensorData(50);

// Function for handling incoming synced Unix time
void syncTimeReceived(BLEDevice central, BLECharacteristic characteristic) {
  startTime = *((unsigned long *) characteristic.value()) - (millis() / 1000);
  timeSynced = true;
  prevTimeSync = true;

  // Print the value of startTime to the serial monitor
  Serial.print("Received synced time: ");
  Serial.println(startTime);
}

// Function for handling reminder signal
void playReminder(BLEDevice central, BLECharacteristic characteristic) {
  byte reminderSignal = *((byte *) characteristic.value());

  if (reminderSignal == 1) {
    Serial.println("Reminder signal received");
  }
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
  timeSyncService.addCharacteristic(syncTimeCharacteristic);
  timeSyncService.addCharacteristic(reminderSignalCharacteristic);
  BLE.addService(timeSyncService);

  syncTimeCharacteristic.setEventHandler(BLEWritten, syncTimeReceived);
  reminderSignalCharacteristic.setEventHandler(BLEWritten, playReminder);
  Serial.println("Sync time and reminder event handlers set");

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
    waitingForCacheSend = true;
    cacheSendStartTime = millis();

    // Loop while central device is connected
    while (central.connected()) {
      currentTime = millis();

      // Check if it's time to send cached data
      if (waitingForCacheSend && currentTime - cacheSendStartTime >= cacheSendDelay) {
        waitingForCacheSend = false;

        // Send cached data one by one every 0.5 seconds
        while (!unsentTimestamps.isEmpty() && !unsentSensorData.isEmpty()) {
          unsigned long cachedTimestamp = unsentTimestamps.dequeue();
          byte cachedSensorData = unsentSensorData.dequeue();

          timeStampCharacteristic.writeValue(cachedTimestamp);
          sensorDataCharacteristic.writeValue(cachedSensorData);

          // Print the data and timestamp to the serial monitor
          Serial.print("Cached data sent: ");
          Serial.print(cachedSensorData);
          Serial.print(" | Timestamp: ");
          Serial.println(cachedTimestamp);

          delay(500); // wait for 0.5 seconds before sending the next data
        }
        Serial.println("Finished sending cached data");
      }

      // Generate and store data only if the time has been synced and waitingForCacheSend is false
      if (timeSynced && !waitingForCacheSend && currentTime - previousTime >= interval) {
        previousTime = currentTime;
        unsigned long unixTime = startTime + (currentTime / 1000);
        byte randomSensorValue = random(0, 256);

        timeStampCharacteristic.writeValue(unixTime);
        sensorDataCharacteristic.writeValue(randomSensorValue);

        // Print the data and timestamp to the serial monitor
        Serial.print("Data: ");
        Serial.print(randomSensorValue);
        Serial.print(" | Timestamp: ");
        Serial.println(unixTime);
      }
    }

    // Reset start time and print disconnected central device address
    timeSynced = false;
    Serial.print("Disconnected from central: ");
    Serial.println(central.address());
  }

  // Generate and store data only if the time has been synced and not connected to the central
  if (prevTimeSync && !central.connected()) {
    currentTime = millis();
    if (currentTime - previousTime >= interval) {
      previousTime = currentTime;
      unsigned long unixTime = startTime + (currentTime / 1000);
      byte randomSensorValue = random(0, 256);

      unsentTimestamps.enqueue(unixTime);
      unsentSensorData.enqueue(randomSensorValue);

      // Print the data and timestamp to the serial monitor
      Serial.print("Data stored: ");
      Serial.print(randomSensorValue);
      Serial.print(" | Timestamp: ");
      Serial.println(unixTime);
    }
  }
}