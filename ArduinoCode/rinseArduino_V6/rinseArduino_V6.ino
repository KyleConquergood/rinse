#include <ArduinoBLE.h>
#include <ArduinoQueue.h>
#include <pitches.h>

// define the arduino pins we are using
#define BUTTON_PIN4 D4
#define BUTTON_PIN5 D5
#define BUTTON_PIN6 D6

// array to play the song
int melody[] = {
NOTE_D4, NOTE_G4, NOTE_FS4, NOTE_A4,
NOTE_G4, NOTE_C5, NOTE_AS4, NOTE_A4,                   
NOTE_FS4, NOTE_G4, NOTE_A4, NOTE_FS4, NOTE_DS4, NOTE_D4,
NOTE_C4, NOTE_D4,0,                                 

// NOTE_D4, NOTE_G4, NOTE_FS4, NOTE_A4,
// NOTE_G4, NOTE_C5, NOTE_D5, NOTE_C5, NOTE_AS4, NOTE_C5, NOTE_AS4, NOTE_A4,  
// NOTE_FS4, NOTE_G4, NOTE_A4, NOTE_FS4, NOTE_DS4, NOTE_D4,
// NOTE_C4, NOTE_D4,0,                                       

// NOTE_D4, NOTE_FS4, NOTE_G4, NOTE_A4, NOTE_DS5, NOTE_D5,
// NOTE_C5, NOTE_AS4, NOTE_A4, NOTE_C5,
// NOTE_C4, NOTE_D4, NOTE_DS4, NOTE_FS4, NOTE_D5, NOTE_C5,
// NOTE_AS4, NOTE_A4, NOTE_C5, NOTE_AS4,             

// NOTE_D4, NOTE_FS4, NOTE_G4, NOTE_A4, NOTE_DS5, NOTE_D5,
// NOTE_C5, NOTE_D5, NOTE_C5, NOTE_AS4, NOTE_C5, NOTE_AS4, NOTE_A4, NOTE_C5, NOTE_G4,
// NOTE_A4, 0, NOTE_AS4, NOTE_A4, 0, NOTE_G4,
// NOTE_G4, NOTE_A4, NOTE_G4, NOTE_FS4, 0,

// NOTE_C4, NOTE_D4, NOTE_G4, NOTE_FS4, NOTE_DS4,
// NOTE_C4, NOTE_D4, 0,
// NOTE_C4, NOTE_D4, NOTE_G4, NOTE_FS4, NOTE_DS4,
// NOTE_C4, NOTE_D4, 
END
};

int noteDurations[] = {       //duration of the notes
8,4,8,4,
4,4,4,12,
4,4,4,4,4,4,
4,16,4,

8,4,8,4,
4,2,1,1,2,1,1,12,
4,4,4,4,4,4,
4,16,4,

4,4,4,4,4,4,
4,4,4,12,
4,4,4,4,4,4,
4,4,4,12,

4,4,4,4,4,4,
2,1,1,2,1,1,4,8,4,
2,6,4,2,6,4,
2,1,1,16,4,

4,8,4,4,4,
4,16,4,
4,8,4,4,4,
4,20,
};

int speed=90;  //higher value, slower notes

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
    play();
    reminderSignal = 0;
  }
}

//Function for playing reminder song
void play(){
  for (int thisNote = 0; melody[thisNote]!=-1; thisNote++) {
    int noteDuration = speed*noteDurations[thisNote];
    tone(BUTTON_PIN6, melody[thisNote],noteDuration*.95);
    Serial.println(melody[thisNote]);
    delay(noteDuration);
    
  }
}

//Checks Bluetooth connection
bool isBluetoothConnected() {
  // Check if the central device is connected
  if (central.connected()) {
    return true;
  } else {
    return false;
  }
}


void checkSensorAndSendData() {
  const unsigned long timeout = 5000; // Timeout duration in milliseconds
  unsigned long waterCheckStart = millis();
  bool timeoutReached = false;

  int pos1 = digitalRead(BUTTON_PIN4);
  int pos2 = digitalRead(BUTTON_PIN5);

  // Check if water is detected on both sensors
  if (pos1 == 0 && pos2 == 0) {
    Serial.println("Water detected");
    unsigned long time_start = millis();

    // Wait for 3 seconds or until one of the sensors goes back to 1 or timeout is reached
    while ((millis() - waterCheckStart < 3000) && pos1 == 0 && pos2 == 0 && !timeoutReached) {
      pos1 = digitalRead(BUTTON_PIN4);
      pos2 = digitalRead(BUTTON_PIN5);

      if (millis() - waterCheckStart >= timeout) {
        timeoutReached = true;
      }
    }
    
    if (!timeoutReached) {
      // Check if both sensors still detect water after 3 seconds
      if (pos1 == 0 && pos2 == 0) {
        Serial.println("Water check passed");

        // Wait for both sensors to detect no water
        while (pos1 != 1 || pos2 != 1) {
          pos1 = digitalRead(BUTTON_PIN4);
          pos2 = digitalRead(BUTTON_PIN5);
        }

        Serial.println("No water detected");
        time_start = millis();

        // Wait for 3 seconds or until one of the sensors goes back to 0
        while ((millis() - time_start < 3000) && pos1 == 1 && pos2 == 1) {
          pos1 = digitalRead(BUTTON_PIN4);
          pos2 = digitalRead(BUTTON_PIN5);
        }

        // Check if both sensors still detect no water after 3 seconds
        if (pos1 == 1 && pos2 == 1) {
          Serial.println("No water check passed");
          unsigned long unixTime = startTime + (millis() / 1000);

          // Send the data
          if (isBluetoothConnected()){
            sensorDataCharacteristic.writeValue(1); // Write the sensor data characteristic value to 1
            timeStampCharacteristic.writeValue(unixTime);

            // Print the data and timestamp to the serial monitor
            Serial.print("Data sent: ");
            Serial.print(1);
            Serial.print(" | Timestamp: ");
            Serial.println(unixTime);
            }

          //Store the data
          else {
            unsentSensorData.enqueue(1);
            unsentTimestamps.enqueue(unixTime);
            // Print the data and timestamp to the serial monitor
            Serial.print("Data cached: ");
            Serial.print(1);
            Serial.print(" | Timestamp: ");
            Serial.println(unixTime);
          }
        }
      }
    } else {
      Serial.println("Timeout reached, water level check interrupted");
    }
  }
}

void setup() {
  // Set pin mode
  pinMode(BUTTON_PIN4, INPUT_PULLUP);
  pinMode(BUTTON_PIN5, INPUT_PULLUP);

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
        checkSensorAndSendData();
      }
    }

    // Reset start time and print disconnected central device address
    timeSynced = false;
    Serial.print("Disconnected from central: ");
    Serial.println(central.address());
  }

  // Generate and store data only if the time has been synced and not connected to the central
  if (prevTimeSync && !central.connected()) {
        checkSensorAndSendData();
  }    
}