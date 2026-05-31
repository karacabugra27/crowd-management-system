import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/app_theme.dart';
import 'providers/location_provider.dart';
import 'screens/dashboard_screen.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ApiService'i başlat (kayıtlı URL ve listenerId'yi yükle)
  await ApiService.instance.init();

  // Lock orientation to portrait for this admin panel
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style for dark theme
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0A0A0F),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const BluetoothOccupancyApp());
}

/// Root widget wrapping the app in the Provider and MaterialApp.
class BluetoothOccupancyApp extends StatelessWidget {
  const BluetoothOccupancyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LocationProvider()..loadLocations(),
      child: MaterialApp(
        title: 'BT Occupancy Admin',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const DashboardScreen(),
      ),
    );
  }
}
