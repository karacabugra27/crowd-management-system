import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const CampusPulseApp());
}

class CampusPulseApp extends StatelessWidget {
  const CampusPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CampusPulse',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary:   const Color(0xFF3b82f6),
          secondary: const Color(0xFF06b6d4),
          surface:   const Color(0xFF0d1526),
          error:     const Color(0xFFef4444),
        ),
        scaffoldBackgroundColor: const Color(0xFF060b14),
        fontFamily: 'SF Pro Display',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0d1526),
          foregroundColor: Color(0xFFe8f0fe),
          elevation: 0,
        ),
        textTheme: const TextTheme(
          bodyLarge:  TextStyle(color: Color(0xFFe8f0fe)),
          bodyMedium: TextStyle(color: Color(0xFF8ba3c7)),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
