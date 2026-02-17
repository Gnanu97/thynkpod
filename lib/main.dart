// lib/main.dart - UPDATED WITH DIARY PROVIDER
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/ble_provider.dart';
import 'services/audio_player_service.dart';
import 'services/ble_service.dart';
import 'services/file_download_service.dart';
import 'screens/home/home_screen.dart';
import 'finance_tracking/providers/finance_provider.dart';
import 'diary_tracking/providers/diary_provider.dart';  // ADD THIS IMPORT

void main() {
  runApp(const ThynkPodApp());
}

class ThynkPodApp extends StatelessWidget {
  const ThynkPodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<BleService>(
          create: (_) => BleService(),
        ),

        Provider<FileDownloadService>(
          create: (context) => FileDownloadService(
            Provider.of<BleService>(context, listen: false),
          ),
        ),

        ChangeNotifierProvider<BleProvider>(
          create: (context) {
            final provider = BleProvider();

            WidgetsBinding.instance.addPostFrameCallback((_) {
              final bleService = Provider.of<BleService>(context, listen: false);
              final downloadService = Provider.of<FileDownloadService>(context, listen: false);

              provider.injectServices(bleService, downloadService);
            });

            return provider;
          },
        ),

        ChangeNotifierProvider<AudioPlayerService>(
          create: (context) => AudioPlayerService(),
        ),

        ChangeNotifierProvider<FinanceProvider>(
          create: (context) => FinanceProvider()..initialize(),
        ),

        // ADD DIARY PROVIDER
        ChangeNotifierProvider<DiaryProvider>(
          create: (context) => DiaryProvider()..initialize(),
        ),
      ],
      child: MaterialApp(
        title: 'ThynkPod',
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF2A2A2A),
          primaryColor: const Color(0xFFA0A0A0),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFA0A0A0),
            secondary: Color(0xFF3A3A3A),
            surface: Colors.white,
            onSurface: Colors.black,
          ),
        ),
        home: const AppInitializer(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF3A3A3A),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    try {
      await Future.delayed(const Duration(milliseconds: 1000));

      if (!mounted) return;

      final bleProvider = Provider.of<BleProvider>(context, listen: false);
      final bleService = Provider.of<BleService>(context, listen: false);
      final downloadService = Provider.of<FileDownloadService>(context, listen: false);

      bleProvider.injectServices(bleService, downloadService);

      debugPrint('🔧 MAIN: Services injected successfully');
      debugPrint('🔗 MAIN: BLE Provider initialized');

      await bleProvider.initialize();

      debugPrint('✅ MAIN: App initialization completed successfully');

    } catch (e) {
      debugPrint('❌ MAIN: App initialization failed: $e');

      if (mounted) {
        _showErrorDialog(e.toString());
      }
    }
  }

  void _showErrorDialog(String error) {
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
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.error_outline, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              'Initialization Error',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'App failed to initialize:',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: Text(
                error,
                style: const TextStyle(
                  color: Color(0xFF737373),
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Please restart the app. If the problem persists, check your device compatibility.',
              style: TextStyle(
                color: Color(0xFF737373),
                fontSize: 13,
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

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}