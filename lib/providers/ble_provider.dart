// lib/providers/ble_provider.dart - SIMPLIFIED WITHOUT AUTO-DOWNLOAD
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/connection_state.dart';
import '../models/ble_device_info.dart';
import '../models/esp32_file_model.dart';
import '../services/ble_service.dart';
import '../services/file_download_service.dart';

class BleProvider extends ChangeNotifier {
  // 🔥 SIMPLIFIED: Only essential services
  BleService? _bleService;
  FileDownloadService? _downloadService;

  ConnectionState _connectionState = ConnectionState(status: ConnectionStatus.disconnected);
  List<BleDeviceInfo> _discoveredDevices = [];
  List<Esp32File> _availableFiles = [];
  bool _isScanning = false;

  bool _isDownloading = false;
  String? _downloadingFile;
  double _downloadProgress = 0.0;
  String _downloadSpeed = '';
  String _downloadTimeRemaining = '';

  StreamSubscription? _connectionStateSubscription;
  Timer? _connectionCheckTimer;
  String? _lastConnectedDeviceId;

  bool _servicesInjected = false;

  // 🔥 SIMPLIFIED: Simple constructor
  BleProvider() {
    debugPrint('🔧 BLE_PROVIDER: Created, waiting for service injection...');
  }

  // 🔥 SIMPLIFIED: Safe service injection without auto-download
  void injectServices(BleService bleService, FileDownloadService downloadService) {
    if (_servicesInjected) {
      debugPrint('⚠️ BLE_PROVIDER: Services already injected, skipping...');
      return;
    }

    _bleService = bleService;
    _downloadService = downloadService;
    _servicesInjected = true;

    _setupDownloadCallbacks();
    debugPrint('✅ BLE_PROVIDER: Services injected successfully');
  }

  // Getters with null safety
  ConnectionState get connectionState => _connectionState;
  List<BleDeviceInfo> get discoveredDevices => _discoveredDevices;
  List<Esp32File> get availableFiles => _availableFiles;
  bool get isScanning => _isScanning;
  bool get connectedDeviceSupportsAudio => _bleService?.supportsAudioFeatures ?? false;

  bool get isDownloading => _isDownloading;
  String? get downloadingFile => _downloadingFile;
  double get downloadProgress => _downloadProgress;
  String get downloadSpeed => _downloadSpeed;
  String get downloadTimeRemaining => _downloadTimeRemaining;

  // 🔥 SIMPLIFIED: Safe initialization
  Future<void> initialize() async {
    if (!_servicesInjected) {
      throw Exception('Services not injected - cannot initialize BLE provider');
    }

    debugPrint('🔧 BLE_PROVIDER: Starting initialization...');

    final bool isAvailable = await FlutterBluePlus.isAvailable;
    if (!isAvailable) {
      _setConnectionState(ConnectionState(
        status: ConnectionStatus.error,
        message: "Bluetooth not available on this device",
      ));
      return;
    }

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      _setConnectionState(ConnectionState(
        status: ConnectionStatus.error,
        message: "Please turn on Bluetooth in device settings",
      ));
      return;
    }

    final bool permissionsGranted = await _requestPermissions();
    if (!permissionsGranted) {
      _setConnectionState(ConnectionState(
        status: ConnectionStatus.error,
        message: "Bluetooth permissions required",
      ));
      return;
    }

    debugPrint('✅ BLE_PROVIDER: Initialization completed, starting scan');
    await startScan();
  }

  // 🔥 SIMPLIFIED: Safe scan
  Future<void> startScan() async {
    if (_bleService == null) {
      debugPrint('❌ BLE_PROVIDER: Cannot scan - BleService not injected');
      return;
    }

    _isScanning = true;
    _discoveredDevices.clear();
    _setConnectionState(ConnectionState(
      status: ConnectionStatus.scanning,
      message: "Scanning for ESP32 devices...",
    ));

    try {
      await _bleService!.startScan();

      _bleService!.scanForDevices().listen(
            (devices) {
          _discoveredDevices = devices;
          notifyListeners();
        },
        onError: (error) {
          _setConnectionState(ConnectionState(
            status: ConnectionStatus.error,
            message: "Scan error: $error",
          ));
          _isScanning = false;
        },
      );
    } catch (e) {
      _setConnectionState(ConnectionState(
        status: ConnectionStatus.error,
        message: "Failed to start scan: $e",
      ));
      _isScanning = false;
      notifyListeners();
    }
  }

  void _setupDownloadCallbacks() {
    if (_downloadService == null) return;

    _downloadService!.onProgress = (progress, speed, timeRemaining) {
      _downloadProgress = progress;
      _downloadSpeed = speed;
      _downloadTimeRemaining = timeRemaining;
      notifyListeners();
    };

    _downloadService!.onComplete = (filename, localPath) {
      _isDownloading = false;
      _downloadingFile = null;
      _downloadProgress = 0.0;
      _downloadSpeed = '';
      _downloadTimeRemaining = '';

      _updateFileAsDownloaded(filename, localPath);
      notifyListeners();
    };

    _downloadService!.onError = (error) {
      _isDownloading = false;
      _downloadingFile = null;
      _downloadProgress = 0.0;
      notifyListeners();
    };
  }

  Future<bool> _requestPermissions() async {
    final bluetoothScan = await Permission.bluetoothScan.request();
    final bluetoothConnect = await Permission.bluetoothConnect.request();
    final location = await Permission.locationWhenInUse.request();

    return bluetoothScan == PermissionStatus.granted &&
        bluetoothConnect == PermissionStatus.granted &&
        location == PermissionStatus.granted;
  }

  Future<void> stopScan() async {
    if (_bleService == null) return;

    try {
      await _bleService!.stopScan();
      _isScanning = false;

      if (!_connectionState.isConnected) {
        _setConnectionState(ConnectionState(
          status: ConnectionStatus.disconnected,
          message: "Scan stopped",
        ));
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error stopping scan: $e');
    }
  }

  // 🔥 SIMPLIFIED: Connect without auto-download triggers
  Future<void> connectToDevice(BleDeviceInfo deviceInfo) async {
    if (_bleService == null) {
      debugPrint('❌ BLE_PROVIDER: Cannot connect - BleService not injected');
      return;
    }

    try {
      await stopScan();

      _setConnectionState(ConnectionState(
        status: ConnectionStatus.connecting,
        deviceName: deviceInfo.displayName,
        message: "Connecting to ${deviceInfo.displayName}...",
      ));

      final device = BluetoothDevice.fromId(deviceInfo.id);
      await _bleService!.connectToDevice(device);

      _lastConnectedDeviceId = deviceInfo.id;
      _startConnectionMonitoring(device);

      final bool supportsAudio = _bleService!.supportsAudioFeatures;

      String message = "Connected";
      if (supportsAudio) {
        message += " - Audio features available";

        // 🔥 SIMPLIFIED: Just refresh files, no auto-download
        debugPrint('📄 BLE_PROVIDER: Refreshing file list after connection...');
        await refreshFileList();
      } else {
        message += " - Limited features";
      }

      _setConnectionState(ConnectionState(
        status: ConnectionStatus.connected,
        deviceName: deviceInfo.displayName,
        message: message,
      ));

    } catch (e) {
      _setConnectionState(ConnectionState(
        status: ConnectionStatus.error,
        deviceName: deviceInfo.displayName,
        message: "Connection failed: $e",
      ));
      _stopConnectionMonitoring();
    }
  }

  void _startConnectionMonitoring(BluetoothDevice device) {
    _connectionStateSubscription = device.connectionState.listen(
          (BluetoothConnectionState state) {
        if (state == BluetoothConnectionState.disconnected) {
          _handleUnexpectedDisconnection();
        }
      },
      onError: (error) {
        _handleUnexpectedDisconnection();
      },
    );

    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkConnectionHealth();
    });
  }

  void _stopConnectionMonitoring() {
    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = null;
  }

  Future<void> _checkConnectionHealth() async {
    if (!_connectionState.isConnected || _bleService?.connectedDevice == null) return;

    try {
      final connectionState = await _bleService!.connectedDevice!.connectionState.first
          .timeout(const Duration(seconds: 3));

      if (connectionState != BluetoothConnectionState.connected) {
        _handleUnexpectedDisconnection();
      }
    } catch (e) {
      _handleUnexpectedDisconnection();
    }
  }

  void _handleUnexpectedDisconnection() {
    if (_isDownloading) {
      cancelDownload();
    }

    _availableFiles.clear();
    _stopConnectionMonitoring();

    _setConnectionState(ConnectionState(
      status: ConnectionStatus.disconnected,
      message: "Device disconnected unexpectedly",
    ));

    debugPrint('📡 BLE_PROVIDER: Device disconnected');

    // Auto-reconnect after delay
    Future.delayed(const Duration(seconds: 2), () {
      if (!_connectionState.isConnected) {
        startScan();
      }
    });
  }

  // 🔥 SIMPLIFIED: Basic file refresh
  Future<void> refreshFileList() async {
    if (!_connectionState.isConnected || _bleService == null) {
      debugPrint('❌ REFRESH: Not connected, skipping file list refresh');
      return;
    }

    if (!_bleService!.supportsAudioFeatures) {
      debugPrint('❌ REFRESH: Device does not support audio features');
      return;
    }

    try {
      // Verify connection is still active
      if (_bleService!.connectedDevice != null) {
        final connectionState = await _bleService!.connectedDevice!.connectionState.first
            .timeout(const Duration(seconds: 5));

        if (connectionState != BluetoothConnectionState.connected) {
          _handleUnexpectedDisconnection();
          return;
        }
      }

      final fileNames = await _bleService!.getFileList();
      debugPrint('📋 REFRESH: Found ${fileNames.length} files: ${fileNames.join(", ")}');

      List<Esp32File> updatedFiles = [];

      for (String fileName in fileNames) {
        try {
          final fileSize = await _bleService!.getFileSize(fileName);
          final formattedSize = _formatFileSize(fileSize);

          updatedFiles.add(Esp32File(
            name: fileName,
            size: formattedSize,
            dateCreated: DateTime.now(),
            formatType: fileName.split('.').last.toLowerCase(),
          ));

        } catch (e) {
          debugPrint('⚠️ REFRESH: Failed to get size for $fileName: $e');
          updatedFiles.add(Esp32File(
            name: fileName,
            size: 'Unknown',
            dateCreated: DateTime.now(),
            formatType: fileName.split('.').last.toLowerCase(),
          ));
        }
      }

      _availableFiles = updatedFiles;
      notifyListeners();

      debugPrint('🎯 REFRESH: File list updated with ${_availableFiles.length} files');

    } catch (e) {
      debugPrint('❌ REFRESH: Failed to refresh file list: $e');
      if (e.toString().contains('device is not connected') ||
          e.toString().contains('fbp-code: 6')) {
        _handleUnexpectedDisconnection();
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  Future<void> downloadFile(Esp32File file) async {
    if (_isDownloading || _downloadService == null) {
      return;
    }

    if (!_connectionState.isConnected) {
      throw Exception('Device not connected. Please reconnect and try again.');
    }

    // Verify connection before download
    if (_bleService?.connectedDevice != null) {
      try {
        final connectionState = await _bleService!.connectedDevice!.connectionState.first
            .timeout(const Duration(seconds: 3));

        if (connectionState != BluetoothConnectionState.connected) {
          _handleUnexpectedDisconnection();
          throw Exception('Device disconnected. Please reconnect and try again.');
        }
      } catch (e) {
        _handleUnexpectedDisconnection();
        throw Exception('Connection lost. Please reconnect and try again.');
      }
    }

    try {
      _isDownloading = true;
      _downloadingFile = file.name;
      _downloadProgress = 0.0;
      notifyListeners();

      await _downloadService!.downloadFile(file);

    } catch (e) {
      _isDownloading = false;
      _downloadingFile = null;
      notifyListeners();

      if (e.toString().contains('device is not connected') ||
          e.toString().contains('fbp-code: 6')) {
        _handleUnexpectedDisconnection();
      }

      rethrow;
    }
  }

  Future<void> deleteFileFromEsp32(Esp32File file) async {
    if (_bleService?.supportsAudioFeatures != true) {
      throw Exception('Device does not support file operations');
    }

    if (!_connectionState.isConnected) {
      throw Exception('Device not connected. Please reconnect and try again.');
    }

    try {
      await _bleService!.deleteFile(file.name);
      _availableFiles.removeWhere((f) => f.name == file.name);
      notifyListeners();

    } catch (e) {
      if (e.toString().contains('device is not connected') ||
          e.toString().contains('fbp-code: 6')) {
        _handleUnexpectedDisconnection();
      }
      rethrow;
    }
  }

  void cancelDownload() {
    if (_isDownloading && _downloadService != null) {
      _downloadService!.cancelDownload();
      _isDownloading = false;
      _downloadingFile = null;
      _downloadProgress = 0.0;
      notifyListeners();
    }
  }

  void _updateFileAsDownloaded(String filename, String localPath) {
    final index = _availableFiles.indexWhere((f) => f.name == filename);
    if (index != -1) {
      _availableFiles[index] = _availableFiles[index].copyWith(
        isDownloaded: true,
        localPath: localPath,
      );
    }
  }

  Future<void> disconnect() async {
    try {
      if (_isDownloading) {
        cancelDownload();
      }

      _stopConnectionMonitoring();

      await _bleService?.disconnect();

      _setConnectionState(ConnectionState(status: ConnectionStatus.disconnected));
      _availableFiles.clear();
      _lastConnectedDeviceId = null;

      debugPrint('📡 BLE_PROVIDER: Manual disconnect completed');

      await startScan();

    } catch (e) {
      debugPrint('Error during disconnect: $e');
    }
  }

  void _setConnectionState(ConnectionState state) {
    _connectionState = state;
    notifyListeners();
  }

  @override
  Future<void> dispose() async {
    if (_isDownloading && _downloadService != null) {
      _downloadService!.cancelDownload();
    }

    _stopConnectionMonitoring();
    await _bleService?.stopScan();
    await _bleService?.disconnect();

    super.dispose();
  }
}