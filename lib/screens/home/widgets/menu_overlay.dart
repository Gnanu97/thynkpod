// lib/screens/home/widgets/menu_overlay.dart - UPDATED WITH DIARY
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/ble_provider.dart';
import '../../recordings/recordings_screen.dart';
import '../../notes/notes_screen.dart';
import '../../../finance_tracking/screens/finance_dashboard_screen.dart';
import '../../../diary_tracking/screens/diary_main_screen.dart';  // ADD THIS IMPORT

class MenuOverlay extends StatelessWidget {
  const MenuOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.transparent,
          child: Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () {}, // Prevent menu from closing when tapping inside
              child: Container(
                width: MediaQuery.of(context).size.width * 0.75,
                height: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x4D000000),
                      blurRadius: 20,
                      offset: Offset(5, 0),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Connection status
                        Consumer<BleProvider>(
                          builder: (context, bleProvider, child) {
                            final isConnected = bleProvider.connectionState.isConnected;

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isConnected
                                    ? const Color(0xFFF0F8F0)
                                    : const Color(0xFFFFF8E1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isConnected
                                      ? const Color(0xFFE8F5E8)
                                      : const Color(0xFFFFECB3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: isConnected ? Colors.green : Colors.orange,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isConnected ? 'Connected' : 'Disconnected',
                                    style: TextStyle(
                                      color: isConnected ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 30),

                        // Menu section
                        const Text(
                          'Menu',
                          style: TextStyle(
                            color: Color(0xFF737373),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),

                        const SizedBox(height: 15),

                        // Recordings menu item
                        _buildMenuItem(
                          context,
                          icon: Icons.mic,
                          title: 'Recordings',
                          onTap: () {
                            Navigator.of(context).pop();
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const RecordingsScreen()),
                            );
                          },
                        ),

                        const SizedBox(height: 12),
                        _buildMenuItem(
                          context,
                          icon: Icons.note_alt,
                          title: 'Notes',
                          onTap: () {
                            Navigator.of(context).pop();
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const NotesScreen()),
                            );
                          },
                        ),

                        const SizedBox(height: 12),
                        // ADD DIARY MENU ITEM HERE
                        _buildMenuItem(
                          context,
                          icon: Icons.book,
                          title: 'Diary',
                          onTap: () {
                            Navigator.of(context).pop();
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const DiaryMainScreen()),
                            );
                          },
                        ),

                        const SizedBox(height: 12),
                        _buildMenuItem(
                          context,
                          icon: Icons.account_balance_wallet,
                          title: 'Finance Tracker',
                          onTap: () {
                            Navigator.of(context).pop();
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const FinanceDashboardScreen()),
                            );
                          },
                        ),

                        // About menu item
                        _buildMenuItem(
                          context,
                          icon: Icons.info_outline,
                          title: 'About ThynkPod',
                          onTap: () {
                            Navigator.of(context).pop();
                            _showAboutDialog(context);
                          },
                        ),

                        const Spacer(),

                        // Connection actions (if connected)
                        Consumer<BleProvider>(
                          builder: (context, bleProvider, child) {
                            if (!bleProvider.connectionState.isConnected) {
                              return const SizedBox.shrink();
                            }

                            return Column(
                              children: [
                                Container(
                                  height: 1,
                                  color: Colors.grey[300],
                                  margin: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                _buildMenuItem(
                                  context,
                                  icon: Icons.bluetooth_disabled,
                                  title: 'Disconnect',
                                  isDestructive: true,
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    bleProvider.disconnect();
                                  },
                                ),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // FIXED: Properly aligned menu items with consistent spacing
  Widget _buildMenuItem(
      BuildContext context, {
        required IconData icon,
        required String title,
        required VoidCallback onTap,
        bool isDestructive = false,
      }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity, // Ensure full width
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              // Icon container with fixed width for alignment
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDestructive
                        ? [Colors.red[400]!, Colors.red[600]!]
                        : [const Color(0xFFA0A0A0), const Color(0xFF737373)],
                  ),
                  borderRadius: BorderRadius.circular(12), // More rounded for modern look
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 16), // Consistent spacing

              // Text section
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isDestructive ? Colors.red[600] : Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              // Arrow icon with fixed positioning
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                child: Icon(
                  Icons.arrow_forward_ios,
                  color: isDestructive ? Colors.red[400] : const Color(0xFF737373),
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFA0A0A0), Color(0xFF737373)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.mic, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'About ThynkPod',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ThynkPod ESP32 Audio Recorder',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Version 1.0.0',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF737373),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Connect to your ESP32 device to record, download, and analyze audio with AI-powered transcription and analysis.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF737373),
                height: 1.4,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Features:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '• ESP32 Bluetooth connectivity\n'
                  '• Audio file downloads\n'
                  '• Speech-to-text transcription\n'
                  '• AI-powered analysis\n'
                  '• Audio playback controls\n'
                  '• Emotional journey tracking',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF737373),
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFA0A0A0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              'OK',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}