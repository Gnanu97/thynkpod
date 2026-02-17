// lib/screens/home/widgets/devices_overlay.dart - EXPANDED & SLEEK design
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/ble_provider.dart';
import '../../../models/connection_state.dart';
import '../../../models/ble_device_info.dart';

class DevicesOverlay extends StatelessWidget {
  const DevicesOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Container(
          width: 380,        // EXPANDED: Increased from 340
          height: 580,       // EXPANDED: Increased from 450 to show more devices
          clipBehavior: Clip.antiAlias,
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            shadows: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Consumer<BleProvider>(
            builder: (context, bleProvider, child) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  children: [
                    // Header with ThynkPod gradient styling
                    Container(
                      width: 380,
                      height: 70,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFFA0A0A0),
                            Color(0xFF737373),
                          ],
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Text(
                              'Devices',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Positioned(
                            right: 15,
                            top: 20,
                            child: GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // EXPANDED Content area - now 440px height instead of 310px
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: _buildDeviceContent(context, bleProvider),
                      ),
                    ),

                    // Bottom section with scan button
                    Container(
                      width: 380,
                      height: 70,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFF737373),
                            Color(0xFF3A3A3A),
                          ],
                        ),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                      child: Center(
                        child: GestureDetector(
                          onTap: () => _handleRefresh(bleProvider),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.refresh,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  bleProvider.connectionState.isConnected
                                      ? 'Refresh Files'
                                      : 'Scan Devices',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceContent(BuildContext context, BleProvider bleProvider) {
    // Connected state
    if (bleProvider.connectionState.isConnected) {
      return _buildConnectedState(context, bleProvider);
    }

    // Error state
    if (bleProvider.connectionState.status == ConnectionStatus.error) {
      return _buildErrorState(context, bleProvider);
    }

    // Device list - SLEEK VERSION
    if (bleProvider.discoveredDevices.isNotEmpty) {
      return _buildSleekDeviceList(context, bleProvider);
    }

    // Scanning state
    if (bleProvider.isScanning) {
      return _buildScanningState(context);
    }

    // No devices found
    return _buildNoDevicesState(context);
  }

  // SLEEK: Minimal device list - STATIC positioning (no re-sorting)
  Widget _buildSleekDeviceList(BuildContext context, BleProvider bleProvider) {
    // Filter devices but maintain discovery order for stable positioning
    final devices = List<BleDeviceInfo>.from(bleProvider.discoveredDevices)
        .where((device) => device.displayName.toLowerCase() != 'unknown device')
        .toList();

    // FIXED: Sort only ONCE by discovery order + ESP32 priority, then keep static
    // Create a stable sort that doesn't change based on signal fluctuations
    final Map<String, int> deviceDiscoveryOrder = {};

    // Assign discovery order index to each device (by device ID)
    for (int i = 0; i < devices.length; i++) {
      final deviceId = devices[i].id;
      if (!deviceDiscoveryOrder.containsKey(deviceId)) {
        deviceDiscoveryOrder[deviceId] = i;
      }
    }

    // Sort ONLY by: 1) ESP32 first, 2) then by discovery order (STATIC)
    devices.sort((a, b) {
      final aIsEsp32 = a.displayName.toLowerCase().contains('esp32');
      final bIsEsp32 = b.displayName.toLowerCase().contains('esp32');

      // ESP32 devices always come first
      if (aIsEsp32 && !bIsEsp32) return -1;
      if (!aIsEsp32 && bIsEsp32) return 1;

      // Within same type (ESP32 or regular), maintain discovery order
      final aOrder = deviceDiscoveryOrder[a.id] ?? 999;
      final bOrder = deviceDiscoveryOrder[b.id] ?? 999;
      return aOrder.compareTo(bOrder);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Scanning indicator (if scanning)
        if (bleProvider.isScanning)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: EdgeInsets.only(bottom: 15),
            decoration: BoxDecoration(
              color: Color(0xFFA0A0A0).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Color(0xFFA0A0A0).withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    color: Color(0xFFA0A0A0),
                    strokeWidth: 2,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Scanning...',
                  style: TextStyle(
                    color: Color(0xFFA0A0A0),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

        // Header
        Row(
          children: [
            Text(
              'Available Devices',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Colors.black,
              ),
            ),
            Spacer(),
            Text(
              '${devices.length} found',
              style: TextStyle(
                color: Color(0xFF737373),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),

        SizedBox(height: 15),

        // SLEEK Device List - No scrolling needed now!
        Expanded(
          child: ListView.builder(
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              final isEsp32 = device.displayName.toLowerCase().contains('esp32');

              return _buildSleekDeviceItem(context, device, bleProvider, isEsp32);
            },
          ),
        ),
      ],
    );
  }

  // SLEEK: Minimal device item - just name, clickable, no icons/buttons
  Widget _buildSleekDeviceItem(BuildContext context, BleDeviceInfo device, BleProvider bleProvider, bool isEsp32) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _connectToDevice(context, device, bleProvider),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          margin: EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            // SLEEK: Clean background with subtle ESP32 highlighting
            color: isEsp32
                ? Color(0xFFF0F8FF) // Light blue tint for ESP32
                : Color(0xFFFAFAFA), // Light gray for others
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isEsp32
                  ? Color(0xFFA0A0A0).withOpacity(0.4) // Subtle border for ESP32
                  : Color(0xFFE0E0E0).withOpacity(0.3), // Very light border for others
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // SLEEK: Just the device name, no icons
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: isEsp32 ? Color(0xFF2E7D32) : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),

              // SLEEK: Optional ESP32 badge only
              if (isEsp32)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'ESP32',
                    style: TextStyle(
                      color: Colors.green[800],
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectedState(BuildContext context, BleProvider bleProvider) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Connected icon with ThynkPod colors
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFA0A0A0),
                Color(0xFF3A3A3A),
              ],
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.bluetooth_connected,
            size: 40,
            color: Colors.white,
          ),
        ),

        SizedBox(height: 25),

        Text(
          'Connected',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),

        SizedBox(height: 8),

        Text(
          bleProvider.connectionState.deviceName ?? 'ESP32 Device',
          style: TextStyle(
            color: Color(0xFF737373),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),

        SizedBox(height: 25),

        // Disconnect button
        GestureDetector(
          onTap: () => bleProvider.disconnect(),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.red.shade400,
                  Colors.red.shade600,
                ],
              ),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Text(
              'Disconnect',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScanningState(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFA0A0A0),
                Color(0xFF3A3A3A),
              ],
            ),
            shape: BoxShape.circle,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 35,
                height: 35,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
              Icon(
                Icons.bluetooth_searching,
                size: 20,
                color: Colors.white,
              ),
            ],
          ),
        ),

        SizedBox(height: 25),

        Text(
          'Scanning for devices...',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),

        SizedBox(height: 10),

        Text(
          'Devices will appear here when found',
          style: TextStyle(
            color: Color(0xFF737373),
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildNoDevicesState(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFE0E0E0),
                Color(0xFFBDBDBD),
              ],
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.bluetooth_disabled,
            size: 40,
            color: Colors.white,
          ),
        ),

        SizedBox(height: 25),

        Text(
          'No devices found',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),

        SizedBox(height: 10),

        Text(
          'Make sure your ESP32 is:\n• Powered on and recording\n• Running the audio recorder firmware\n• Within Bluetooth range (10m)',
          style: TextStyle(
            color: Color(0xFF737373),
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context, BleProvider bleProvider) {
    final errorMessage = bleProvider.connectionState.message ?? 'Unknown error occurred';
    final isBluetoothOff = errorMessage.toLowerCase().contains('bluetooth must be turned on') ||
        errorMessage.toLowerCase().contains('bluetooth is not enabled') ||
        errorMessage.toLowerCase().contains('bluetooth adapter not available');

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isBluetoothOff ? [
                Color(0xFFFF9800),
                Color(0xFFE65100),
              ] : [
                Colors.red.shade400,
                Colors.red.shade600,
              ],
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isBluetoothOff ? Icons.bluetooth_disabled : Icons.error_outline,
            size: 40,
            color: Colors.white,
          ),
        ),

        SizedBox(height: 25),

        Text(
          isBluetoothOff ? 'Bluetooth Required' : 'Connection Error',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),

        SizedBox(height: 15),

        Text(
          isBluetoothOff
              ? 'Please turn on Bluetooth to scan for devices'
              : errorMessage,
          style: TextStyle(
            color: Color(0xFF737373),
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _handleRefresh(BleProvider bleProvider) {
    if (bleProvider.connectionState.isConnected) {
      bleProvider.refreshFileList();
    } else {
      bleProvider.startScan();
    }
  }

  Future<void> _connectToDevice(BuildContext context, BleDeviceInfo device, BleProvider bleProvider) async {
    // Show loading state immediately
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 10),
            Text(
              'Connecting to ${device.displayName}...',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        backgroundColor: Color(0xFFA0A0A0),
        duration: Duration(seconds: 10),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    try {
      // Attempt connection
      await bleProvider.connectToDevice(device);

      // Hide any existing snackbars
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Connected to ${device.displayName}',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

    } catch (e) {
      // Hide loading snackbar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Failed to connect: ${e.toString()}',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _connectToDevice(context, device, bleProvider),
          ),
        ),
      );
    }
  }
}