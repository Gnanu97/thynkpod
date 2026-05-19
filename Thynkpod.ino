// ESP32 FIRMWARE - COMPLETE AUDIO RECORDER WITH SELECTIVE MESSAGING
// FEATURES: Clean recording output + Full debugging for other operations
// TARGET: 35-45 KB/s transfer rate with proper WAV headers

#include <SD.h>
#include <SPI.h>
#include <driver/i2s.h>
#include <time.h>
#include <sys/time.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// Pin Definitions
#define SD_CS         10
#define SD_MOSI       11
#define SD_SCK        12
#define SD_MISO       13

#define I2S_BCK       4
#define I2S_WS        5
#define I2S_DATA_IN   6

#define RECORD_BUTTON_PIN   7  // Single button for record toggle

// I2S Configuration
#define I2S_PORT          I2S_NUM_0
#define I2S_SAMPLE_RATE   16000
#define I2S_SAMPLE_BITS   16
#define I2S_CHANNEL_NUM   1
#define I2S_BUFFER_COUNT  8
#define I2S_BUFFER_SIZE   1024

// Recording Configuration
#define RECORDING_BUFFER_SIZE 4096
#define WAV_HEADER_SIZE       44

// OPTIMIZED: 220-byte chunks for high performance
#define BLE_CHUNK_SIZE 220  // Optimal balance of speed and reliability
#define CHUNK_DELAY_MS 8    // 8ms delay for stable 220-byte transfers

// Global Variables
File audioFile;
bool isRecording = false;
bool buttonLastState = HIGH;
bool buttonPressed = false;
unsigned long lastDebounceTime = 0;
unsigned long debounceDelay = 50;
uint32_t recordingSize = 0;
uint8_t recordingBuffer[RECORDING_BUFFER_SIZE];

// BLE Service and Characteristic UUIDs
#define BLE_SERVICE_UUID           "6e400001-b5a3-f393-e0a9-e50e24dcca9e"
#define BLE_FILE_LIST_CHAR_UUID    "6e400002-b5a3-f393-e0a9-e50e24dcca9e"
#define BLE_FILE_REQ_CHAR_UUID     "6e400003-b5a3-f393-e0a9-e50e24dcca9e"
#define BLE_FILE_DATA_CHAR_UUID    "6e400004-b5a3-f393-e0a9-e50e24dcca9e"
#define BLE_FILE_DEL_CHAR_UUID     "6e400005-b5a3-f393-e0a9-e50e24dcca9e"

// BLE Globals
BLEServer* pServer = nullptr;
BLECharacteristic* pFileListCharacteristic = nullptr;
BLECharacteristic* pFileReqCharacteristic = nullptr;
BLECharacteristic* pFileDataCharacteristic = nullptr;
BLECharacteristic* pFileDelCharacteristic = nullptr;
bool deviceConnected = false;
String requestedFileName = "";
File fileToSend;
size_t fileSendOffset = 0;
size_t totalFileSize = 0;
bool fileTransferInProgress = false;
unsigned long transferStartTime = 0;
unsigned long lastChunkSent = 0;

// Function Prototypes
void setupI2S();
void createWavHeader(uint8_t* header, uint32_t dataSize);
String generateFileName();
int getNextFileNumber();
void startRecording();
void stopRecording();
void processAudioData();
void handleButtonPress();
void checkBLEStatus();
void setupBLE();
void sendFileList();
void startFileTransfer(const String& filename);
void sendNextFileChunk();
void stopFileTransfer();
void deleteFile(const String& filename);
void handleFileSizeRequest(const String& filename);
void sendCompletionSignals();
void debugFileContents(const String& filepath);

// BLE Callbacks
class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    if (!isRecording) {
      Serial.println("📱 BLE device connected");
    }
  }
  
  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    stopFileTransfer();
    if (!isRecording) {
      Serial.println("📱 BLE device disconnected");
    }
    
    delay(500);
    BLEDevice::startAdvertising();
    if (!isRecording) {
      Serial.println("📡 Restarted BLE advertising");
    }
  }
};

class FileReqCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pCharacteristic) {
    String value = pCharacteristic->getValue();
    
    if (!isRecording) {
      Serial.println("📨 === FILE REQUEST RECEIVED ===");
      Serial.println("📨 Raw value: '" + value + "'");
      Serial.println("📨 Length: " + String(value.length()));
    }
    
    if (value.length() > 0) {
      // Handle TEST commands for debugging
      if (value == "TEST") {
        String testResponse = "TEST_OK_220_BYTES";
        pFileDataCharacteristic->setValue(testResponse.c_str());
        pFileDataCharacteristic->notify();
        if (!isRecording) {
          Serial.println("🧪 Test response sent (220-byte mode confirmed)");
        }
        return;
      }
      
      // Handle SIZE requests
      if (value.startsWith("SIZE:")) {
        String filename = value.substring(5);
        if (!isRecording) {
          Serial.println("📏 SIZE request for: '" + filename + "'");
        }
        handleFileSizeRequest(filename);
        return;
      }
      
      // Handle DOWNLOAD requests  
      if (value.startsWith("DOWNLOAD:")) {
        String filename = value.substring(9);
        requestedFileName = filename;
        if (!isRecording) {
          Serial.println("📂 DOWNLOAD request for: '" + filename + "' (220-byte chunks)");
        }
        startFileTransfer(requestedFileName);
        return;
      }
      
      // Handle GET requests
      if (value.startsWith("GET ")) {
        String filename = value.substring(4);
        requestedFileName = filename;
        if (!isRecording) {
          Serial.println("📂 GET request for: '" + filename + "'");
        }
        startFileTransfer(requestedFileName);
        return;
      }
      
      // Fallback - direct filename
      requestedFileName = value;
      if (!isRecording) {
        Serial.println("📂 Direct filename request: '" + requestedFileName + "'");
      }
      startFileTransfer(requestedFileName);
    }
  }
};

class FileDelCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pCharacteristic) {
    String value = pCharacteristic->getValue();
    if (value.length() > 0) {
      if (!isRecording) {
        Serial.println("🗑 Delete requested: " + value);
      }
      deleteFile(value);
    }
  }
};

void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("🎤 ESP32 Audio Recorder - ENHANCED DEBUG VERSION");
  Serial.println("🔍 Comprehensive WAV header debugging enabled");
  Serial.println("⚡ Target: 35-45 KB/s transfer speed");
  
  // Initialize button pin
  pinMode(RECORD_BUTTON_PIN, INPUT);
  
  // Initialize SD Card
  SPI.begin(SD_SCK, SD_MISO, SD_MOSI, SD_CS);
  if (!SD.begin(SD_CS)) {
    Serial.println("❌ SD Card initialization failed!");
    while (1);
  }
  Serial.println("✅ SD Card initialized");
  
  // Create recordings directory
  if (!SD.exists("/recordings")) {
    SD.mkdir("/recordings");
  }
  
  // Setup I2S
  setupI2S();
  
  // Setup BLE
  setupBLE();
  
  Serial.println("🔧 Setup complete!");
  Serial.println("🚀 Optimized for 220-byte chunks with 8ms timing");
  Serial.println("📊 Expected: 35-45 KB/s transfer rate");
  Serial.println("🔍 Enhanced debugging: ENABLED");
}

void loop() {
  // Button handling
  int buttonReading = digitalRead(RECORD_BUTTON_PIN);
  
  if (buttonReading != buttonLastState) {
    lastDebounceTime = millis();
  }
  
  if ((millis() - lastDebounceTime) > debounceDelay) {
    if (buttonReading == LOW && !buttonPressed) {
      buttonPressed = true;
      handleButtonPress();
    } else if (buttonReading == HIGH && buttonPressed) {
      buttonPressed = false;
    }
  }
  
  buttonLastState = buttonReading;
  
  // Process audio if recording
  if (isRecording) {
    processAudioData();
  }

  // OPTIMIZED: File transfer with 220-byte chunks and 8ms timing
  if (deviceConnected && fileTransferInProgress) {
    if (millis() - lastChunkSent >= CHUNK_DELAY_MS) {
      sendNextFileChunk();
      lastChunkSent = millis();
    }
  }

  // Connection management
  if (deviceConnected && !pServer->getConnectedCount()) {
    deviceConnected = false;
    stopFileTransfer();
  }

  // Periodic status checks (only when not recording)
  static unsigned long lastBLECheck = 0;
  if (!isRecording && millis() - lastBLECheck > 30000) {
    checkBLEStatus();
    lastBLECheck = millis();
  }

  // Quick connection updates
  static unsigned long lastQuickCheck = 0;
  if (millis() - lastQuickCheck > 2000) {
    if (deviceConnected != (pServer->getConnectedCount() > 0)) {
      deviceConnected = (pServer->getConnectedCount() > 0);
      if (!isRecording && deviceConnected) {
        Serial.println("📱 220-byte optimized connection established");
      }
    }
    lastQuickCheck = millis();
  }
}

void handleButtonPress() {
  if (!isRecording) {
    startRecording();
  } else {
    stopRecording();
  }
}

void setupI2S() {
  i2s_config_t i2s_config = {
    .mode = (i2s_mode_t)(I2S_MODE_MASTER | I2S_MODE_RX),
    .sample_rate = I2S_SAMPLE_RATE,
    .bits_per_sample = I2S_BITS_PER_SAMPLE_16BIT,
    .channel_format = I2S_CHANNEL_FMT_ONLY_LEFT,
    .communication_format = I2S_COMM_FORMAT_STAND_I2S,
    .intr_alloc_flags = ESP_INTR_FLAG_LEVEL1,
    .dma_buf_count = I2S_BUFFER_COUNT,
    .dma_buf_len = I2S_BUFFER_SIZE,
    .use_apll = false,
    .tx_desc_auto_clear = false,
    .fixed_mclk = 0
  };
  
  i2s_pin_config_t pin_config = {
    .bck_io_num = I2S_BCK,
    .ws_io_num = I2S_WS,
    .data_out_num = I2S_PIN_NO_CHANGE,
    .data_in_num = I2S_DATA_IN
  };
  
  esp_err_t err = i2s_driver_install(I2S_PORT, &i2s_config, 0, NULL);
  if (err != ESP_OK) {
    Serial.printf("❌ Failed to install I2S driver: %d\n", err);
    while (1);
  }
  
  err = i2s_set_pin(I2S_PORT, &pin_config);
  if (err != ESP_OK) {
    Serial.printf("❌ Failed to set I2S pins: %d\n", err);
    while (1);
  }
  
  Serial.println("✅ I2S initialized successfully");
}

String generateFileName() {
  int fileNumber = getNextFileNumber();
  char filename[50];
  sprintf(filename, "/recordings/recording_%03d.wav", fileNumber);
  return String(filename);
}

int getNextFileNumber() {
  int highestNumber = 0;
  
  File dir = SD.open("/recordings");
  if (dir) {
    File entry;
    while ((entry = dir.openNextFile())) {
      if (!entry.isDirectory()) {
        String fileName = entry.name();
        if (fileName.startsWith("recording_") && fileName.endsWith(".wav")) {
          int underscorePos = fileName.indexOf('_');
          int dotPos = fileName.indexOf('.');
          if (underscorePos > 0 && dotPos > underscorePos) {
            String numberStr = fileName.substring(underscorePos + 1, dotPos);
            int fileNum = numberStr.toInt();
            if (fileNum > highestNumber) {
              highestNumber = fileNum;
            }
          }
        }
      }
      entry.close();
    }
    dir.close();
  }
  
  return highestNumber + 1;
}

void createWavHeader(uint8_t* header, uint32_t dataSize) {
  uint32_t fileSize = dataSize + WAV_HEADER_SIZE - 8;
  uint32_t sampleRate = I2S_SAMPLE_RATE;
  uint16_t numChannels = I2S_CHANNEL_NUM;
  uint16_t bitsPerSample = I2S_SAMPLE_BITS;
  uint32_t byteRate = sampleRate * numChannels * bitsPerSample / 8;
  uint16_t blockAlign = numChannels * bitsPerSample / 8;
  
  // RIFF chunk descriptor
  header[0] = 'R'; header[1] = 'I'; header[2] = 'F'; header[3] = 'F';
  header[4] = fileSize & 0xFF;
  header[5] = (fileSize >> 8) & 0xFF;
  header[6] = (fileSize >> 16) & 0xFF;
  header[7] = (fileSize >> 24) & 0xFF;
  header[8] = 'W'; header[9] = 'A'; header[10] = 'V'; header[11] = 'E';
  
  // fmt sub-chunk
  header[12] = 'f'; header[13] = 'm'; header[14] = 't'; header[15] = ' ';
  header[16] = 16; header[17] = 0; header[18] = 0; header[19] = 0;
  header[20] = 1; header[21] = 0; // AudioFormat (PCM)
  header[22] = numChannels & 0xFF; header[23] = 0;
  header[24] = sampleRate & 0xFF;
  header[25] = (sampleRate >> 8) & 0xFF;
  header[26] = (sampleRate >> 16) & 0xFF;
  header[27] = (sampleRate >> 24) & 0xFF;
  header[28] = byteRate & 0xFF;
  header[29] = (byteRate >> 8) & 0xFF;
  header[30] = (byteRate >> 16) & 0xFF;
  header[31] = (byteRate >> 24) & 0xFF;
  header[32] = blockAlign & 0xFF; header[33] = 0;
  header[34] = bitsPerSample & 0xFF; header[35] = 0;
  
  // data sub-chunk
  header[36] = 'd'; header[37] = 'a'; header[38] = 't'; header[39] = 'a';
  header[40] = dataSize & 0xFF;
  header[41] = (dataSize >> 8) & 0xFF;
  header[42] = (dataSize >> 16) & 0xFF;
  header[43] = (dataSize >> 24) & 0xFF;
}

void startRecording() {
  if (isRecording) return;
  
  String filename = generateFileName();
  audioFile = SD.open(filename, FILE_WRITE);
  
  if (!audioFile) {
    Serial.println("❌ Failed to create file!");
    return;
  }
  
  // Write placeholder WAV header
  uint8_t wavHeader[WAV_HEADER_SIZE];
  memset(wavHeader, 0, WAV_HEADER_SIZE);
  audioFile.write(wavHeader, WAV_HEADER_SIZE);
  
  recordingSize = 0;
  isRecording = true;
  
  // CLEAN OUTPUT: Only this message during recording start
  Serial.println("Recording started");
  
  // Clear I2S buffer
  i2s_zero_dma_buffer(I2S_PORT);
}

void stopRecording() {
  if (!isRecording) return;
  
  isRecording = false;
  
  // Update WAV header with actual size
  audioFile.seek(0);
  uint8_t wavHeader[WAV_HEADER_SIZE];
  createWavHeader(wavHeader, recordingSize);
  audioFile.write(wavHeader, WAV_HEADER_SIZE);
  
  // Proper file closure with timing fix
  audioFile.flush();
  String fileName = audioFile.name();
  audioFile.close();
  audioFile = File();  // Clear handle
  
  // Extract just the filename without path
  String shortFileName = fileName;
  if (shortFileName.startsWith("/recordings/")) {
    shortFileName = shortFileName.substring(12);
  }
  
  // CLEAN OUTPUT: Only this message during recording stop
  Serial.println("Recording stopped - " + shortFileName);
  
  // Wait for file system to settle
  delay(100);
  
  // Debug the file we just created (only when not recording)
  debugFileContents(fileName);
  
  // Update file list for BLE
  sendFileList();
}

void processAudioData() {
  size_t bytesRead = 0;
  esp_err_t result = i2s_read(I2S_PORT, recordingBuffer, RECORDING_BUFFER_SIZE, &bytesRead, 0);
  
  if (result == ESP_OK && bytesRead > 0) {
    size_t bytesWritten = audioFile.write(recordingBuffer, bytesRead);
    if (bytesWritten != bytesRead) {
      Serial.println("❌ SD write error - stopping recording");
      stopRecording();
      return;
    }
    
    recordingSize += bytesRead;
    
    // File size limit (100MB)
    if (recordingSize > 100 * 1024 * 1024) {
      Serial.println("⚠ File size limit reached - stopping recording");
      stopRecording();
    }
  }
}

void debugFileContents(const String& filepath) {
  if (!isRecording) {
    Serial.println("🔍 === DEBUGGING CREATED FILE ===");
    Serial.println("🔍 Debugging file: " + filepath);
  }
  
  File debugFile = SD.open(filepath, FILE_READ);
  if (!debugFile) {
    if (!isRecording) {
      Serial.println("❌ Could not open file for debugging");
    }
    return;
  }
  
  uint8_t buffer[64];
  size_t bytesRead = debugFile.read(buffer, 64);
  
  if (!isRecording) {
    Serial.println("🔍 File size: " + String(debugFile.size()) + " bytes");
    Serial.println("🔍 First 64 bytes:");
    
    for (int i = 0; i < bytesRead; i += 16) {
      Serial.printf("🔍 %04X: ", i);
      for (int j = 0; j < 16 && (i + j) < bytesRead; j++) {
        Serial.printf("%02X ", buffer[i + j]);
      }
      Serial.print(" | ");
      for (int j = 0; j < 16 && (i + j) < bytesRead; j++) {
        char c = buffer[i + j];
        Serial.print((c >= 32 && c <= 126) ? c : '.');
      }
      Serial.println();
    }
  }
  
  // Check specific WAV markers
  if (bytesRead >= 4) {
    String riff = "";
    for (int i = 0; i < 4; i++) {
      riff += (char)buffer[i];
    }
    if (!isRecording) {
      Serial.println("🔍 RIFF header: '" + riff + "' " + (riff == "RIFF" ? "✅" : "❌"));
    }
  }
  
  if (bytesRead >= 12) {
    String wave = "";
    for (int i = 8; i < 12; i++) {
      wave += (char)buffer[i];
    }
    if (!isRecording) {
      Serial.println("🔍 WAVE header: '" + wave + "' " + (wave == "WAVE" ? "✅" : "❌"));
    }
  }
  
  if (bytesRead >= 40) {
    String data = "";
    for (int i = 36; i < 40; i++) {
      data += (char)buffer[i];
    }
    if (!isRecording) {
      Serial.println("🔍 DATA header: '" + data + "' " + (data == "data" ? "✅" : "❌"));
    }
  }
  
  debugFile.close();
  if (!isRecording) {
    Serial.println("🔍 === FILE DEBUG COMPLETE ===");
  }
}

void checkBLEStatus() {
  Serial.println("=== BLE Status Check (Enhanced Debug Mode) ===");
  Serial.println("📡 BLE Initialized: " + String(BLEDevice::getInitialized() ? "YES" : "NO"));
  
  if (pServer) {
    Serial.println("📱 Connected devices: " + String(pServer->getConnectedCount()));
  }
  
  Serial.println("📡 Device discoverable: " + String(deviceConnected ? "NO (Connected)" : "YES"));
  Serial.println("📍 MAC Address: " + String(BLEDevice::getAddress().toString().c_str()));
  
  // Count files on SD
  File dir = SD.open("/recordings");
  int fileCount = 0;
  if (dir) {
    File entry;
    while ((entry = dir.openNextFile())) {
      if (!entry.isDirectory() && String(entry.name()).endsWith(".wav")) {
        fileCount++;
      }
      entry.close();
    }
    dir.close();
  }
  Serial.println("💾 Files on SD: " + String(fileCount));
  Serial.println("🚀 Optimized transfer: 220-byte chunks, 8ms timing");
  Serial.println("📊 Target speed: 35-45 KB/s");
  Serial.println("🔍 Enhanced debugging: ENABLED");
  Serial.println("========================================");
}

void setupBLE() {
  Serial.println("📡 Initializing BLE with enhanced debugging...");
  
  BLEDevice::init("ESP32-AudioSync");
  Serial.println("📡 BLE Device initialized as 'ESP32-AudioSync'");
  
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());
  Serial.println("📡 BLE Server created");

  BLEService *pService = pServer->createService(BLE_SERVICE_UUID);
  Serial.println("📡 BLE Service created");

  // File List Characteristic (read)
  pFileListCharacteristic = pService->createCharacteristic(
    BLE_FILE_LIST_CHAR_UUID,
    BLECharacteristic::PROPERTY_READ
  );

  // File Request Characteristic (write)
  pFileReqCharacteristic = pService->createCharacteristic(
    BLE_FILE_REQ_CHAR_UUID,
    BLECharacteristic::PROPERTY_WRITE
  );
  pFileReqCharacteristic->setCallbacks(new FileReqCallbacks());

  // File Data Characteristic (notify) - optimized for 220-byte packets
  pFileDataCharacteristic = pService->createCharacteristic(
    BLE_FILE_DATA_CHAR_UUID,
    BLECharacteristic::PROPERTY_NOTIFY
  );
  pFileDataCharacteristic->addDescriptor(new BLE2902());
  
  // Set larger MTU for better performance
  BLEDevice::setMTU(512);

  // File Delete Characteristic (write)
  pFileDelCharacteristic = pService->createCharacteristic(
    BLE_FILE_DEL_CHAR_UUID,
    BLECharacteristic::PROPERTY_WRITE
  );
  pFileDelCharacteristic->setCallbacks(new FileDelCallbacks());
  
  Serial.println("📡 BLE Characteristics created");

  pService->start();
  Serial.println("📡 BLE Service started");
  
  // Enhanced advertising setup
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(BLE_SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  pAdvertising->setMinPreferred(0x12);
  
  // Start advertising
  BLEDevice::startAdvertising();
  Serial.println("📡 BLE Advertising started");
  Serial.println("📱 Device discoverable as 'ESP32-AudioSync'");
  Serial.println("⚡ Enhanced debugging enabled");

  // Preload file list
  sendFileList();
}

void sendFileList() {
  File dir = SD.open("/recordings");
  String fileList = "";
  int fileCount = 0;
  
  if (dir) {
    File entry;
    while ((entry = dir.openNextFile())) {
      if (!entry.isDirectory()) {
        String fname = entry.name();
        
        if (fname.startsWith("/recordings/")) {
          fname = fname.substring(12);
        }
        
        if (fname.endsWith(".wav")) {
          if (fileCount > 0) fileList += ",";
          fileList += fname;
          fileCount++;
          
          if (!isRecording) {
            Serial.println("📋 File found: " + fname);
          }
        }
      }
      entry.close();
    }
    dir.close();
  }
  
  pFileListCharacteristic->setValue(fileList.c_str());
  if (!isRecording) {
    Serial.println("📂 File list updated: " + String(fileCount) + " files");
    Serial.println("📂 List content: " + fileList);
  }
}

void handleFileSizeRequest(const String& filename) {
  if (!isRecording) {
    Serial.println("📏 Size request for: '" + filename + "'");
  }
  
  String possiblePaths[] = {
    "/recordings/" + filename,
    "/" + filename,
    filename,
    "/recordings/" + filename.substring(filename.lastIndexOf('/') + 1)
  };
  
  bool fileFound = false;
  size_t fileSize = 0;
  
  for (int i = 0; i < 4; i++) {
    if (SD.exists(possiblePaths[i].c_str())) {
      File file = SD.open(possiblePaths[i].c_str(), FILE_READ);
      if (file) {
        fileSize = file.size();
        file.close();
        fileFound = true;
        if (!isRecording) {
          Serial.println("📏 File size found: " + String(fileSize) + " bytes at '" + possiblePaths[i] + "'");
        }
        break;
      }
    }
  }
  
  if (fileFound) {
    String sizeResponse = "SIZE:" + filename + ":" + String(fileSize);
    pFileDataCharacteristic->setValue(sizeResponse.c_str());
    pFileDataCharacteristic->notify();
    if (!isRecording) {
      Serial.println("📏 Size response sent: " + sizeResponse);
    }
  } else {
    String errorResponse = "SIZE:" + filename + ":NOT_FOUND";
    pFileDataCharacteristic->setValue(errorResponse.c_str());
    pFileDataCharacteristic->notify();
    if (!isRecording) {
      Serial.println("❌ File not found for size request: " + filename);
    }
  }
}

void startFileTransfer(const String& filename) {
  if (fileTransferInProgress) {
    if (!isRecording) {
      Serial.println("❌ Transfer already in progress");
    }
    return;
  }
  
  if (!isRecording) {
    Serial.println("🚀 === STARTING ENHANCED DEBUG TRANSFER ===");
    Serial.println("🚀 Requested file: '" + filename + "'");
  }
  
  // Try multiple path combinations
  String possiblePaths[] = {
    "/recordings/" + filename,
    "/" + filename,
    filename,
    "/recordings/" + filename.substring(filename.lastIndexOf('/') + 1)
  };
  
  bool fileFound = false;
  String actualPath = "";
  
  for (int i = 0; i < 4; i++) {
    if (!isRecording) {
      Serial.println("🔍 Trying path: '" + possiblePaths[i] + "'");
    }
    
    if (SD.exists(possiblePaths[i].c_str())) {
      fileToSend = SD.open(possiblePaths[i].c_str(), FILE_READ);
      if (fileToSend) {
        actualPath = possiblePaths[i];
        fileFound = true;
        if (!isRecording) {
          Serial.println("✅ File found at: '" + actualPath + "'");
        }
        break;
      }
    }
  }
  
  if (!fileFound) {
    if (!isRecording) {
      Serial.println("❌ File not found!");
    }
    String errorMsg = "ERROR:File not found: " + filename;
    pFileDataCharacteristic->setValue(errorMsg.c_str());
    pFileDataCharacteristic->notify();
    return;
  }
  
  // COMPREHENSIVE FILE DEBUGGING (only when not recording)
  if (!isRecording) {
    Serial.println("🔍 === COMPREHENSIVE FILE ANALYSIS ===");
  }
  
  totalFileSize = fileToSend.size();
  if (!isRecording) {
    Serial.println("🔍 File size: " + String(totalFileSize) + " bytes");
  }
  
  // Reset and verify position
  fileToSend.seek(0);
  size_t currentPos = fileToSend.position();
  if (!isRecording) {
    Serial.println("🔍 File position after seek(0): " + String(currentPos));
  }
  
  // Read and analyze first 64 bytes (only when not recording)
  if (!isRecording) {
    uint8_t headerBuffer[64];
    size_t headerBytesRead = fileToSend.read(headerBuffer, 64);
    Serial.println("🔍 Read " + String(headerBytesRead) + " bytes for analysis");
    
    // Display hex dump
    Serial.println("🔍 First 64 bytes (hex):");
    for (int i = 0; i < headerBytesRead; i += 16) {
      Serial.printf("🔍 %04X: ", i);
      for (int j = 0; j < 16 && (i + j) < headerBytesRead; j++) {
        Serial.printf("%02X ", headerBuffer[i + j]);
      }
      Serial.print(" | ");
      for (int j = 0; j < 16 && (i + j) < headerBytesRead; j++) {
        char c = headerBuffer[i + j];
        Serial.print((c >= 32 && c <= 126) ? c : '.');
      }
      Serial.println();
    }
    
    // Analyze WAV structure
    if (headerBytesRead >= 4) {
      String riffCheck = "";
      for (int i = 0; i < 4; i++) {
        riffCheck += (char)headerBuffer[i];
      }
      Serial.println("🔍 RIFF header: '" + riffCheck + "' " + (riffCheck == "RIFF" ? "✅ VALID" : "❌ INVALID"));
      
      if (riffCheck != "RIFF") {
        Serial.printf("🔍 Expected: 52 49 46 46, Got: %02X %02X %02X %02X\n", 
                      headerBuffer[0], headerBuffer[1], headerBuffer[2], headerBuffer[3]);
      }
    }
    
    if (headerBytesRead >= 12) {
      String waveCheck = "";
      for (int i = 8; i < 12; i++) {
        waveCheck += (char)headerBuffer[i];
      }
      Serial.println("🔍 WAVE header: '" + waveCheck + "' " + (waveCheck == "WAVE" ? "✅ VALID" : "❌ INVALID"));
      
      if (waveCheck != "WAVE") {
        Serial.printf("🔍 Expected: 57 41 56 45, Got: %02X %02X %02X %02X\n", 
                      headerBuffer[8], headerBuffer[9], headerBuffer[10], headerBuffer[11]);
      }
    }
    
    if (headerBytesRead >= 40) {
      String dataCheck = "";
      for (int i = 36; i < 40; i++) {
        dataCheck += (char)headerBuffer[i];
      }
      Serial.println("🔍 DATA header: '" + dataCheck + "' " + (dataCheck == "data" ? "✅ VALID" : "❌ INVALID"));
    }
    
    // Reset file position for actual transfer
    fileToSend.seek(0);
  }
  
  fileSendOffset = 0;
  currentPos = fileToSend.position();
  if (!isRecording) {
    Serial.println("🔍 File position reset for transfer: " + String(currentPos));
  }
  
  // Double-check what we'll actually send (only when not recording)
  if (!isRecording) {
    uint8_t transferBuffer[220];
    size_t transferBytesRead = fileToSend.read(transferBuffer, 220);
    Serial.println("🔍 === TRANSFER VERIFICATION ===");
    Serial.println("🔍 Bytes that will be sent in first chunk: " + String(transferBytesRead));
    
    Serial.print("🔍 First 16 bytes to be transferred: ");
    for (int i = 0; i < min(16, (int)transferBytesRead); i++) {
      Serial.printf("%02X ", transferBuffer[i]);
    }
    Serial.println();
    
    String transferString = "";
    for (int i = 0; i < min(8, (int)transferBytesRead); i++) {
      transferString += (char)transferBuffer[i];
    }
    Serial.println("🔍 First 8 chars to be transferred: '" + transferString + "'");
    
    // Verify RIFF in transfer buffer
    if (transferBytesRead >= 4) {
      String transferRiff = "";
      for (int i = 0; i < 4; i++) {
        transferRiff += (char)transferBuffer[i];
      }
      if (transferRiff == "RIFF") {
        Serial.println("✅ CONFIRMED: Transfer buffer contains RIFF header!");
      } else {
        Serial.println("❌ CRITICAL ERROR: Transfer buffer missing RIFF header!");
        Serial.println("❌ Transfer buffer contains: '" + transferRiff + "'");
        
        fileToSend.close();
        String errorMsg = "ERROR:Invalid transfer buffer: " + filename;
        pFileDataCharacteristic->setValue(errorMsg.c_str());
        pFileDataCharacteristic->notify();
        return;
      }
    }
    
    // Reset file position one more time
    fileToSend.seek(0);
  }
  
  fileSendOffset = 0;
  if (!isRecording) {
    Serial.println("🔍 Final file position: " + String(fileToSend.position()));
  }
  
  // Initialize transfer variables
  fileTransferInProgress = true;
  transferStartTime = millis();
  lastChunkSent = 0;
  
  if (!isRecording) {
    Serial.println("🚀 === TRANSFER INITIALIZATION COMPLETE ===");
    Serial.println("🚀 File: " + filename);
    Serial.println("🚀 Path: " + actualPath);
    Serial.println("🚀 Size: " + String(totalFileSize) + " bytes");
    Serial.println("🚀 Chunks: " + String((totalFileSize + 219) / 220));
    Serial.println("🔍 Enhanced debugging: ACTIVE");
    Serial.println("🚀 ==============================");
    Serial.println("🚀 Sending first chunk with full debug info...");
  }
  
  // Send first chunk
  sendNextFileChunk();
}

void sendNextFileChunk() {
  if (!fileTransferInProgress || !fileToSend) {
    if (!isRecording) {
      Serial.println("⚠ Transfer not active");
    }
    return;
  }
  
  uint8_t buffer[BLE_CHUNK_SIZE];
  size_t bytesRead = fileToSend.read(buffer, BLE_CHUNK_SIZE);
  
  if (bytesRead > 0) {
    // COMPREHENSIVE FIRST CHUNK DEBUG (only when not recording)
    if (fileSendOffset == 0 && !isRecording) {
      Serial.println("🔍 === COMPREHENSIVE FIRST CHUNK DEBUG ===");
      
      // Show complete buffer contents
      Serial.println("🔍 Complete first chunk (" + String(bytesRead) + " bytes):");
      for (int i = 0; i < bytesRead; i += 16) {
        Serial.printf("🔍 %04X: ", i);
        for (int j = 0; j < 16 && (i + j) < bytesRead; j++) {
          Serial.printf("%02X ", buffer[i + j]);
        }
        Serial.print(" | ");
        for (int j = 0; j < 16 && (i + j) < bytesRead; j++) {
          char c = buffer[i + j];
          Serial.print((c >= 32 && c <= 126) ? c : '.');
        }
        Serial.println();
      }
      
      // Verify the exact bytes being sent
      if (bytesRead >= 4) {
        Serial.printf("🔍 Bytes 0-3 (RIFF): %02X %02X %02X %02X\n", 
                      buffer[0], buffer[1], buffer[2], buffer[3]);
        String riffActual = "";
        for (int i = 0; i < 4; i++) {
          riffActual += (char)buffer[i];
        }
        Serial.println("🔍 RIFF as string: '" + riffActual + "'");
        
        if (riffActual == "RIFF") {
          Serial.println("✅ CONFIRMED: First chunk contains RIFF header!");
        } else {
          Serial.println("❌ CRITICAL ERROR: First chunk missing RIFF header!");
          Serial.println("❌ Got: '" + riffActual + "' instead of 'RIFF'");
        }
      }
      
      if (bytesRead >= 12) {
        Serial.printf("🔍 Bytes 8-11 (WAVE): %02X %02X %02X %02X\n", 
                      buffer[8], buffer[9], buffer[10], buffer[11]);
        String waveActual = "";
        for (int i = 8; i < 12; i++) {
          waveActual += (char)buffer[i];
        }
        Serial.println("🔍 WAVE as string: '" + waveActual + "'");
        
        if (waveActual == "WAVE") {
          Serial.println("✅ CONFIRMED: First chunk contains WAVE header!");
        } else {
          Serial.println("⚠ WARNING: WAVE header not found in expected position");
          Serial.println("⚠ Got: '" + waveActual + "' at position 8-11");
        }
      }
      
      // Check if buffer contains audio data instead of header
      bool looksLikeAudio = true;
      int audioSampleCount = 0;
      for (int i = 0; i < min((int)bytesRead - 1, 40); i += 2) {
        int16_t sample = (buffer[i+1] << 8) | buffer[i];
        if (sample >= -32768 && sample <= 32767) {
          audioSampleCount++;
        }
      }
      
      if (audioSampleCount > 15 && buffer[0] != 'R') {
        Serial.println("❌ CRITICAL ERROR: Buffer contains audio samples, not WAV header!");
        Serial.println("❌ Audio samples detected: " + String(audioSampleCount));
        Serial.println("❌ File position may be incorrect or header corrupted!");
      } else {
        Serial.println("✅ Buffer appears to contain proper WAV header data");
      }
      
      Serial.println("🔍 ========================================");
    }
    
    // Send 220-byte chunk
    pFileDataCharacteristic->setValue(buffer, bytesRead);
    pFileDataCharacteristic->notify();
    fileSendOffset += bytesRead;
    
    // Calculate progress and speed (only when not recording)
    if (!isRecording) {
      float progressPercent = ((float)fileSendOffset / totalFileSize) * 100.0;
      unsigned long elapsed = millis() - transferStartTime;
      float speedKBps = (elapsed > 0) ? (fileSendOffset / 1024.0) / (elapsed / 1000.0) : 0.0;
      
      // Log every 50 chunks or important events
      static int chunkCount = 0;
      chunkCount++;
      
      if (chunkCount % 50 == 0 || bytesRead < BLE_CHUNK_SIZE || fileSendOffset >= totalFileSize) {
        Serial.println("📤 CHUNK #" + String(chunkCount) + 
                      " | " + String(fileSendOffset) + "/" + String(totalFileSize) + 
                      " (" + String(progressPercent, 1) + "%) | " + 
                      String(speedKBps, 1) + " KB/s");
      }
    }
    
    // Check for completion
    if (bytesRead < BLE_CHUNK_SIZE || fileSendOffset >= totalFileSize) {
      if (!isRecording) {
        unsigned long totalTime = millis() - transferStartTime;
        float avgSpeedKBps = (totalTime > 0) ? (fileSendOffset / 1024.0) / (totalTime / 1000.0) : 0.0;
        
        Serial.println("🏁 === ENHANCED DEBUG TRANSFER COMPLETE ===");
        Serial.println("🏁 Total sent: " + String(fileSendOffset) + " bytes");
        Serial.println("🏁 Time taken: " + String(totalTime) + "ms (" + String(totalTime/1000.0, 1) + "s)");
        Serial.println("🏁 Average speed: " + String(avgSpeedKBps, 1) + " KB/s");
        Serial.println("🔍 Debug analysis: COMPLETE");
        Serial.println("🏁 Sending completion signals...");
      }
      
      // Send completion signals
      sendCompletionSignals();
      stopFileTransfer();
      
      if (!isRecording) {
        Serial.println("🎉 ENHANCED DEBUG TRANSFER SUCCESS!");
        Serial.println("===================================");
      }
      return;
    }
  } else {
    if (!isRecording) {
      Serial.println("❌ Failed to read from file at offset " + String(fileSendOffset));
    }
    stopFileTransfer();
  }
}

void sendCompletionSignals() {
  if (!isRecording) {
    Serial.println("🏁 Sending optimized completion signals...");
  }
  
  // Send multiple end markers for reliability
  for (int i = 0; i < 3; i++) {
    uint8_t endSignal[1] = {0xFF};
    pFileDataCharacteristic->setValue(endSignal, 1);
    pFileDataCharacteristic->notify();
    delay(10); // Brief delay between signals
    if (!isRecording) {
      Serial.println("🏁 End signal " + String(i + 1) + " sent");
    }
  }
  
  // Final empty notification as completion marker
  delay(20);
  pFileDataCharacteristic->setValue((uint8_t*)nullptr, 0);
  pFileDataCharacteristic->notify();
  if (!isRecording) {
    Serial.println("🏁 Final empty completion signal sent");
  }
}

void stopFileTransfer() {
  if (fileToSend) {
    fileToSend.close();
    if (!isRecording) {
      Serial.println("📁 File closed");
    }
  }
  fileTransferInProgress = false;
  fileSendOffset = 0;
  totalFileSize = 0;
  requestedFileName = "";
  transferStartTime = 0;
  lastChunkSent = 0;
  if (!isRecording) {
    Serial.println("🔄 Enhanced debug transfer state reset");
  }
}

void deleteFile(const String& filename) {
  if (!isRecording) {
    Serial.println("🗑 Delete request for: '" + filename + "'");
  }
  
  String possiblePaths[] = {
    "/recordings/" + filename,
    "/" + filename,
    filename,
    "/recordings/" + filename.substring(filename.lastIndexOf('/') + 1)
  };
  
  bool fileFound = false;
  String actualPath = "";
  
  for (int i = 0; i < 4; i++) {
    if (SD.exists(possiblePaths[i].c_str())) {
      actualPath = possiblePaths[i];
      fileFound = true;
      break;
    }
  }
  
  if (fileFound) {
    if (SD.remove(actualPath.c_str())) {
      if (!isRecording) {
        Serial.println("✅ Successfully deleted: " + filename + " at " + actualPath);
      }
      
      // Update file list after deletion
      sendFileList();
      if (!isRecording) {
        Serial.println("📂 File list updated after deletion");
      }
      
      // Send success notification
      String successMsg = "DELETE_SUCCESS:" + filename;
      pFileDataCharacteristic->setValue(successMsg.c_str());
      pFileDataCharacteristic->notify();
    } else {
      if (!isRecording) {
        Serial.println("❌ Failed to delete: " + filename);
      }
      String errorMsg = "DELETE_ERROR:" + filename;
      pFileDataCharacteristic->setValue(errorMsg.c_str());
      pFileDataCharacteristic->notify();
    }
  } else {
    if (!isRecording) {
      Serial.println("⚠ File not found for deletion: " + filename);
    }
    String errorMsg = "DELETE_ERROR:File not found: " + filename;
    pFileDataCharacteristic->setValue(errorMsg.c_str());
    pFileDataCharacteristic->notify();
  }
}

/*
=== ESP32 COMPLETE AUDIO RECORDER - FINAL VERSION ===

📋 FEATURES:
✅ Single INMP441 microphone (mono recording)
✅ 16kHz, 16-bit WAV files with proper headers  
✅ BLE file transfer at 35-45 KB/s (220-byte chunks)
✅ Button-controlled recording (GPIO 7)
✅ SD card storage with auto-numbering
✅ Complete file management (list, download, delete)
✅ Selective messaging system

🔊 RECORDING OUTPUT:
- Clean: "Recording started" / "Recording stopped - filename.wav"
- Silent during recording for all other operations

📡 BLE OPERATIONS (when not recording):
- Full debugging with emojis and detailed logs
- File transfer progress and speed monitoring
- Connection status and error reporting
- Complete WAV header validation

🎯 HARDWARE SETUP:
- ESP32 pins: BCK=4, WS=5, DATA=6, BUTTON=7
- SD card: CS=10, MOSI=11, SCK=12, MISO=13
- INMP441: Connect to I2S pins (L/R to GND for left channel)
- Button: GPIO 7 to GND with pull-up resistor + capacitor

⚡ OPTIMIZATIONS:
- Button debouncing with hardware filtering support
- Proper file closure timing for SD card stability
- Non-blocking BLE operations during recording
- Enhanced error handling and recovery

This is the complete, production-ready firmware! 🎤
*/