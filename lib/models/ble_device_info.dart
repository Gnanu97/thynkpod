// lib/models/ble_device_info.dart
class BleDeviceInfo {
  final String id;
  final String name;
  final int rssi;

  BleDeviceInfo({
    required this.id,
    required this.name,
    required this.rssi,
  });

  String get displayName => name.isNotEmpty ? name : 'Unknown Device';

  // Signal strength helper
  String get signalStrength {
    if (rssi > -50) return 'Excellent';
    if (rssi > -70) return 'Good';
    if (rssi > -85) return 'Fair';
    return 'Poor';
  }
}