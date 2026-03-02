import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class LineColors {
  // Colores de líneas basados en el tema de Alzira
  static const Map<String, Color> colors = {
    'L1': AlzitransColors.lineL1,  // Vino
    'L2': AlzitransColors.lineL2,  // Carmesí
    'L3': AlzitransColors.lineL3,  // Burdeos
  };

  static Color getColor(String line) {
    return colors[line] ?? Colors.grey;
  }

  static Color getStopColor(List<String> lines, Set<String> selectedLines) {
    for (final line in lines) {
      if (selectedLines.contains(line) && colors.containsKey(line)) {
        return colors[line]!;
      }
    }
    return Colors.grey;
  }

  static List<Color> getStopColors(List<String> lines, Set<String> selectedLines) {
    final List<Color> activeColors = [];
    for (final line in lines) {
      if (selectedLines.contains(line) && colors.containsKey(line)) {
        activeColors.add(colors[line]!);
      }
    }
    return activeColors.isEmpty ? [Colors.grey] : activeColors;
  }
}
