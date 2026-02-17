// lib/utils/constants.dart
class BleConstants {
  // ESP32-AudioSync BLE Service UUIDs
  static const String serviceUuid = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
  static const String fileListUuid = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';
  static const String fileReqUuid = '6e400003-b5a3-f393-e0a9-e50e24dcca9e';
  static const String fileDataUuid = '6e400004-b5a3-f393-e0a9-e50e24dcca9e';
  static const String fileDelUuid = '6e400005-b5a3-f393-e0a9-e50e24dcca9e';
  static const String syncUuid = '6e400006-b5a3-f393-e0a9-e50e24dcca9e';

  // Auto-sync settings
  static const int autoSyncDelaySeconds = 3;

  // ThynkPod Color Scheme
  static const int primaryGray = 0xFFA0A0A0;
  static const int secondaryGray = 0xFF3A3A3A;
  static const int lightGray = 0xFF737373;
  static const int backgroundDark = 0xFF122030; // Your dark background
}