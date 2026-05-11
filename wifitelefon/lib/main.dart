import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Benzersiz Cihaz (Alan) kimliðini oluþtur veya getir
  final prefs = await SharedPreferences.getInstance();
  String? areaId = prefs.getString('area_id');
  
  if (areaId == null) {
    const uuid = Uuid();
    areaId = uuid.v4();
    await prefs.setString('area_id', areaId);
  }

  runApp(WifiTelefonApp(areaId: areaId));
}

class WifiTelefonApp extends StatelessWidget {
  final String areaId;

  const WifiTelefonApp({super.key, required this.areaId});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'CampusPulse Dinleyici',
      theme: const CupertinoThemeData(
        primaryColor: CupertinoColors.activeBlue,
        brightness: Brightness.light,
      ),
      home: HomeScreen(areaId: areaId),
      debugShowCheckedModeBanner: false,
    );
  }
}
