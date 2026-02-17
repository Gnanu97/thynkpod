// lib/models/connection_state.dart
enum ConnectionStatus {
  disconnected,
  scanning,
  connecting,
  connected,
  error,
}

class ConnectionState {
  final ConnectionStatus status;
  final String? deviceName;
  final String? message;

  ConnectionState({
    required this.status,
    this.deviceName,
    this.message,
  });

  bool get isConnected => status == ConnectionStatus.connected;
  bool get isConnecting => status == ConnectionStatus.connecting;
  bool get isScanning => status == ConnectionStatus.scanning;
  bool get hasError => status == ConnectionStatus.error;
}
