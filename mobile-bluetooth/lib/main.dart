import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/api_config.dart';
import 'core/app_theme.dart';
import 'providers/location_provider.dart';
import 'screens/dashboard_screen.dart';
import 'services/scan_uploader.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0A0A0F),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Load persisted config before building the widget tree so settings are
  // available synchronously to the providers below.
  final config = ApiConfig();
  await config.load();

  final locationProvider = LocationProvider();
  final uploader = ScanUploader(
    config: config,
    macSnapshot: () => locationProvider.currentMacAddresses,
  );
  locationProvider.attachUploader(uploader);

  runApp(CrowdlyScannerApp(
    config: config,
    locationProvider: locationProvider,
    uploader: uploader,
  ));
}

/// Root widget — exposes the three long-lived providers and starts at the
/// dashboard. Naming reflects the merged Crowdly project.
class CrowdlyScannerApp extends StatelessWidget {
  const CrowdlyScannerApp({
    super.key,
    required this.config,
    required this.locationProvider,
    required this.uploader,
  });

  final ApiConfig config;
  final LocationProvider locationProvider;
  final ScanUploader uploader;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ApiConfig>.value(value: config),
        ChangeNotifierProvider<LocationProvider>.value(
          value: locationProvider..loadLocations(),
        ),
        ChangeNotifierProvider<ScanUploader>.value(value: uploader),
      ],
      child: MaterialApp(
        title: 'Crowdly · Tarayıcı',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const DashboardScreen(),
      ),
    );
  }
}
