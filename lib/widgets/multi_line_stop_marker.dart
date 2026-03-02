import 'dart:math' as math;
import 'package:flutter/material.dart';

class MultiLineStopMarker extends StatelessWidget {
  final List<Color> colors;
  final VoidCallback onTap;
  final double size;

  const MultiLineStopMarker({
    super.key,
    required this.colors,
    required this.onTap,
    this.size = 50,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: colors.length > 1
              ? ShaderMask(
                  shaderCallback: (Rect bounds) {
                    final List<Color> segmentedColors = [];
                    final List<double> stops = [];
                    
                    for (int i = 0; i < colors.length; i++) {
                      segmentedColors.add(colors[i]);
                      segmentedColors.add(colors[i]);
                      
                      final start = i / colors.length;
                      final end = (i + 1) / colors.length;
                      
                      stops.add(start);
                      stops.add(end);
                    }

                    return SweepGradient(
                      colors: segmentedColors,
                      stops: stops,
                      transform: const GradientRotation(-math.pi / 2),
                    ).createShader(bounds);
                  },
                  child: Icon(
                    Icons.directions_bus_rounded,
                    color: Colors.white,
                    size: size * 0.56,
                  ),
                )
              : Icon(
                  Icons.directions_bus_rounded,
                  color: colors.first,
                  size: size * 0.56,
                ),
        ),
      ),
    );
  }
}
