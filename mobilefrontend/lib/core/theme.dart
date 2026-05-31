import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Background colors
  static const bg = Color(0xFF0A0A14);
  static const bgCard = Color(0xFF12121E);
  static const bgCardHover = Color(0xFF181830);
  static const bgSidebar = Color(0xFF0E0E1A);
  static const bgInput = Color(0xFF16162A);

  // Border colors
  static const border = Color(0x12FFFFFF);
  static const borderHover = Color(0x24FFFFFF);

  // Text colors
  static const text = Color(0xFFE2E8F0);
  static const textDim = Color(0xFF8892A4);
  static const textMuted = Color(0xFF5A6278);

  // Accent colors
  static const purple = Color(0xFF818CF8);
  static const purpleDim = Color(0x1F818CF8);
  static const blue = Color(0xFF60A5FA);
  static const blueDim = Color(0x1F60A5FA);
  static const amber = Color(0xFFFBBF24);
  static const amberDim = Color(0x1FFBBF24);
  static const rose = Color(0xFFFB7185);
  static const roseDim = Color(0x1FFB7185);
  static const green = Color(0xFF34D399);
  static const red = Color(0xFFF87171);

  // Gradient colors
  static const gradientStart = Color(0xFF6366F1);
  static const gradientEnd = Color(0xFF818CF8);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.purple,
        secondary: AppColors.blue,
        surface: AppColors.bgCard,
        error: AppColors.red,
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.dark().textTheme,
      ).apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgSidebar,
        foregroundColor: AppColors.text,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.purple, width: 2),
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted),
        labelStyle: const TextStyle(color: AppColors.textDim),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gradientStart,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.bgSidebar,
        selectedItemColor: AppColors.purple,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerColor: AppColors.border,
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}
