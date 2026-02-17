// lib/screens/home/home_screen.dart - SIMPLIFIED VERSION
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/ble_provider.dart';
import 'widgets/bottom_navigation_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFA0A0A0),
              Color(0xFF3A3A3A),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x3F000000),
              blurRadius: 4,
              offset: Offset(0, 4),
              spreadRadius: 0,
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const SizedBox(height: 60),

                        // ThynkPod Logo/Avatar
                        Container(
                          width: 120,
                          height: 120,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0xFFD9D9D9),
                                Color(0xFF737373),
                              ],
                            ),
                          ),
                          child: ClipOval(
                            child: Image.network(
                              "https://placehold.co/120x120",
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: const Color(0xFFD9D9D9),
                                  child: Icon(
                                    Icons.person,
                                    size: 60,
                                    color: Colors.grey[600],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),
                        const Text(
                          'Welcome to ThynkPod!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Connection Status Card
                        Consumer<BleProvider>(
                          builder: (context, bleProvider, child) {
                            final isConnected = bleProvider.connectionState.isConnected;
                            final deviceName = bleProvider.connectionState.deviceName;
                            final statusMessage = bleProvider.connectionState.message;

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              decoration: BoxDecoration(
                                color: isConnected
                                    ? const Color(0xFFF0F8F0).withOpacity(0.15)
                                    : const Color(0xFFFFF8E1).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isConnected
                                      ? const Color(0xFF4CAF50).withOpacity(0.3)
                                      : const Color(0xFFFFB74D).withOpacity(0.25),
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: isConnected ? const Color(0xFF4CAF50) : const Color(0xFFFFB74D),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Flexible(
                                        child: Text(
                                          isConnected
                                              ? 'Connected to ${deviceName ?? "ESP32"}'
                                              : 'Not Connected',
                                          style: TextStyle(
                                            color: isConnected ? const Color(
                                                0xFF3EE742) : const Color(0xFFFFB74D),
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (statusMessage != null && statusMessage.isNotEmpty && statusMessage != 'Connected')
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        statusMessage,
                                        style: TextStyle(
                                          color: isConnected
                                              ? const Color(0xFF4CAF50).withOpacity(0.8)
                                              : const Color(0xFFFFB74D).withOpacity(0.8),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 30),

                        // Simple Stats Card (if connected)
                        Consumer<BleProvider>(
                          builder: (context, bleProvider, child) {
                            if (!bleProvider.connectionState.isConnected) {
                              return const SizedBox.shrink();
                            }

                            final fileCount = bleProvider.availableFiles.length;
                            final supportsAudio = bleProvider.connectedDeviceSupportsAudio;

                            return Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withOpacity(0.2)),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildStatItem(
                                        icon: Icons.audiotrack,
                                        label: 'Files Available',
                                        value: '$fileCount',
                                      ),
                                      Container(
                                        width: 1,
                                        height: 50,
                                        color: Colors.white.withOpacity(0.3),
                                      ),
                                      _buildStatItem(
                                        icon: supportsAudio ? Icons.check_circle : Icons.warning,
                                        label: 'Audio Support',
                                        value: supportsAudio ? 'Yes' : 'Limited',
                                      ),
                                    ],
                                  ),
                                  if (fileCount > 0) ...[
                                    const SizedBox(height: 20),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4CAF50).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.info_outline, color: Color(0xFF4CAF50), size: 16),
                                          const SizedBox(width: 8),
                                          const Flexible(
                                            child: Text(
                                              'Ready to download recordings',
                                              style: TextStyle(
                                                color: Color(0xFF4CAF50),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 60),

                        // Simple welcome message - REMOVED navigation text
                      ],
                    ),
                  ),
                ),
              ),

              const BottomNavigationWidget(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Handle app lifecycle if needed
  }
}