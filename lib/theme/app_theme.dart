import 'package:flutter/material.dart';

/// Colores basados en la Targeta Transport d'Alzira
class AlzitransColors {
  // Colores principales de la tarjeta
  static const Color burgundy = Color(0xFF6B1B3D);      // Granate/Burdeos oscuro
  static const Color wine = Color(0xFF8B2252);          // Vino/Granate medio
  static const Color crimson = Color(0xFFB22234);       // Rojo carmesí
  static const Color coral = Color(0xFFE85A4F);         // Coral/Rojo claro
  
  // Colores secundarios
  static const Color purple = Color(0xFF4A1942);        // Morado oscuro
  static const Color lightPurple = Color(0xFF7B4B6E);   // Morado claro
  
  // Colores de fondo
  static const Color background = Color(0xFFF8F5F6);    // Fondo claro rosado
  static const Color surface = Colors.white;
  static const Color cardBackground = Colors.white;
  
  // Colores de texto
  static const Color textPrimary = Color(0xFF2D1B25);   // Casi negro con tinte
  static const Color textSecondary = Color(0xFF6B5B63); // Gris con tinte
  static const Color textOnPrimary = Colors.white;
  
  // Colores de acento
  static const Color accent = Color(0xFFE85A4F);        // Coral para acentos
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFE53935);
  
  // Colores de líneas de bus (distintivos para diferenciar)
  static const Color lineL1 = Color(0xFF1565C0);        // Azul
  static const Color lineL2 = Color(0xFF2E7D32);        // Verde
  static const Color lineL3 = Color(0xFFE65100);        // Naranja
  
  // Gradientes
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [coral, crimson, wine, burgundy],
  );
  
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE85A4F), Color(0xFFB22234)],
  );
  
  static const LinearGradient appBarGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [burgundy, wine],
  );
}

class AlzitransTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      
      // Esquema de colores
      colorScheme: ColorScheme.light(
        primary: AlzitransColors.burgundy,
        primaryContainer: AlzitransColors.wine,
        secondary: AlzitransColors.coral,
        secondaryContainer: AlzitransColors.crimson,
        tertiary: AlzitransColors.purple,
        surface: AlzitransColors.surface,
        error: AlzitransColors.error,
        onPrimary: AlzitransColors.textOnPrimary,
        onSecondary: AlzitransColors.textOnPrimary,
        onSurface: AlzitransColors.textPrimary,
      ),
      
      // Scaffold
      scaffoldBackgroundColor: AlzitransColors.background,
      
      // AppBar - Estilo limpio con fondo blanco
      appBarTheme: const AppBarTheme(
        elevation: 1,
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AlzitransColors.burgundy,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: AlzitransColors.burgundy,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: AlzitransColors.burgundy),
      ),
      
      // Cards
      cardTheme: CardThemeData(
        elevation: 2,
        shadowColor: AlzitransColors.burgundy.withOpacity(0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: AlzitransColors.cardBackground,
      ),
      
      // Botones elevados
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AlzitransColors.burgundy,
          foregroundColor: AlzitransColors.textOnPrimary,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      
      // Botones de texto
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AlzitransColors.burgundy,
        ),
      ),
      
      // FAB
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AlzitransColors.coral,
        foregroundColor: AlzitransColors.textOnPrimary,
        elevation: 4,
      ),
      
      // Bottom Navigation (Legacy)
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AlzitransColors.burgundy,
        unselectedItemColor: Colors.grey[400],
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      
      // NavigationBar (Material 3)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AlzitransColors.burgundy.withOpacity(0.15),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AlzitransColors.burgundy, size: 26);
          }
          return IconThemeData(color: Colors.grey[600], size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: AlzitransColors.burgundy, fontWeight: FontWeight.bold, fontSize: 13);
          }
          return TextStyle(color: Colors.grey[600], fontWeight: FontWeight.normal, fontSize: 12);
        }),
        elevation: 1,
      ),
      
      // TabBar - Para AppBars con fondo blanco
      tabBarTheme: const TabBarThemeData(
        labelColor: AlzitransColors.burgundy,
        unselectedLabelColor: AlzitransColors.textSecondary,
        indicatorColor: AlzitransColors.burgundy,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      
      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: AlzitransColors.burgundy.withOpacity(0.1),
        labelStyle: const TextStyle(color: AlzitransColors.burgundy),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      
      // Sliders
      sliderTheme: SliderThemeData(
        activeTrackColor: AlzitransColors.burgundy,
        inactiveTrackColor: AlzitransColors.burgundy.withOpacity(0.3),
        thumbColor: AlzitransColors.burgundy,
        overlayColor: AlzitransColors.burgundy.withOpacity(0.2),
      ),
      
      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AlzitransColors.burgundy;
          }
          return Colors.grey;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AlzitransColors.burgundy.withOpacity(0.5);
          }
          return Colors.grey.withOpacity(0.3);
        }),
      ),
      
      // Divider
      dividerTheme: DividerThemeData(
        color: AlzitransColors.burgundy.withOpacity(0.1),
        thickness: 1,
      ),
      
      // ListTile
      listTileTheme: const ListTileThemeData(
        iconColor: AlzitransColors.burgundy,
      ),
      
      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AlzitransColors.burgundy,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      
      // Dialog
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      
      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AlzitransColors.burgundy.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AlzitransColors.burgundy.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AlzitransColors.burgundy, width: 2),
        ),
        prefixIconColor: AlzitransColors.burgundy,
      ),
    );
  }
  
  /// Obtiene el color de una línea de bus
  static Color getLineColor(String line) {
    switch (line.toUpperCase()) {
      case 'L1':
        return AlzitransColors.lineL1;
      case 'L2':
        return AlzitransColors.lineL2;
      case 'L3':
        return AlzitransColors.lineL3;
      default:
        return AlzitransColors.burgundy;
    }
  }
}

/// Widget para crear un AppBar con gradiente
class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool showBackButton;
  
  const GradientAppBar({
    super.key,
    required this.title,
    this.actions,
    this.bottom,
    this.showBackButton = true,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AlzitransColors.appBarGradient,
      ),
      child: AppBar(
        title: Text(title),
        actions: actions,
        bottom: bottom,
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: showBackButton,
      ),
    );
  }
  
  @override
  Size get preferredSize => Size.fromHeight(
    kToolbarHeight + (bottom?.preferredSize.height ?? 0),
  );
}

/// Widget decorativo con el patrón de la tarjeta
class AlzitransCardDecoration extends StatelessWidget {
  final Widget child;
  final bool showPattern;
  
  const AlzitransCardDecoration({
    super.key,
    required this.child,
    this.showPattern = true,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AlzitransColors.cardGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          if (showPattern)
            Positioned(
              top: -20,
              right: -20,
              child: Opacity(
                opacity: 0.1,
                child: Icon(
                  Icons.directions_bus,
                  size: 100,
                  color: Colors.white,
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}
