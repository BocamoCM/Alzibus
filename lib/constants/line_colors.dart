import 'package:flutter/material.dart';

class LineColors {
  static const Map<String, Color> colors = {
    'L1': Colors.blue,
    'L2': Colors.green,
    'L3': Colors.orange,
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
}
