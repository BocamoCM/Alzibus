import 'package:flutter/material.dart';

class AdminTheme {
  // Colores principales (mismos que la app móvil)
  static const Color burgundy = Color(0xFF6B1B3D);
  static const Color wine = Color(0xFF8B2252);
  static const Color coral = Color(0xFFE85A4F);
  
  // Colores de líneas
  static const Color lineL1 = Color(0xFF1565C0);
  static const Color lineL2 = Color(0xFF2E7D32);
  static const Color lineL3 = Color(0xFFE65100);
  
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: burgundy,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: burgundy,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.white,
        selectedIconTheme: const IconThemeData(color: burgundy),
        unselectedIconTheme: IconThemeData(color: Colors.grey[600]),
        selectedLabelTextStyle: const TextStyle(
          color: burgundy,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: burgundy,
        brightness: Brightness.dark,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
