import 'package:flutter/material.dart';
import 'dart:math' as math;

class SimpleMapWidget extends StatelessWidget {
  final double latitude;
  final double longitude;
  final double width;
  final double height;

  const SimpleMapWidget({
    super.key,
    required this.latitude,
    required this.longitude,
    this.width = 600,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _MapPainter(latitude, longitude),
    );
  }
}

class _MapPainter extends CustomPainter {
  final double latitude;
  final double longitude;

  _MapPainter(this.latitude, this.longitude);

  @override
  void paint(Canvas canvas, Size size) {
    // Fondo del mapa (color de mapa claro)
    final backgroundPaint = Paint()
      ..color = const Color(0xFFF2EFE9);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    // Dibujar "calles" simuladas
    final streetPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // Crear un patrón de calles basado en las coordenadas
    final seed = (latitude * 1000 + longitude * 1000).toInt();
    final random = math.Random(seed);

    // Dibujar calles horizontales
    for (int i = 0; i < 5; i++) {
      final y = (i + 1) * size.height / 6 + random.nextDouble() * 20 - 10;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        streetPaint,
      );
    }

    // Dibujar calles verticales
    for (int i = 0; i < 6; i++) {
      final x = (i + 1) * size.width / 7 + random.nextDouble() * 20 - 10;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        streetPaint,
      );
    }

    // Dibujar algunas "manzanas" de edificios
    final buildingPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 8; i++) {
      final x = random.nextDouble() * (size.width - 40);
      final y = random.nextDouble() * (size.height - 40);
      canvas.drawRect(
        Rect.fromLTWH(x, y, 30 + random.nextDouble() * 20, 25 + random.nextDouble() * 15),
        buildingPaint,
      );
    }

    // Dibujar marcador en el centro
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Sombra del marcador
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    
    canvas.drawCircle(
      Offset(centerX + 2, centerY + 2),
      12,
      shadowPaint,
    );

    // Marcador rojo
    final markerPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    // Círculo del marcador
    canvas.drawCircle(
      Offset(centerX, centerY),
      12,
      markerPaint,
    );

    // Borde blanco del marcador
    final markerBorderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(
      Offset(centerX, centerY),
      12,
      markerBorderPaint,
    );

    // Centro del marcador
    final markerCenterPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(centerX, centerY),
      4,
      markerCenterPaint,
    );

    // Dibujar coordenadas
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}',
        style: const TextStyle(
          color: Colors.black54,
          fontSize: 10,
          backgroundColor: Colors.white70,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(5, size.height - 15));
  }

  @override
  bool shouldRepaint(_MapPainter oldDelegate) {
    return oldDelegate.latitude != latitude || oldDelegate.longitude != longitude;
  }
}
