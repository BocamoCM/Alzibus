import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Marcador de autobús en el mapa.
/// Diseño: círculo de color + icono bus + badge de línea.
class AnimatedBusMarker extends StatefulWidget {
  final double heading;
  final String lineId;
  final bool isAtStop;
  final double size;

  const AnimatedBusMarker({
    super.key,
    required this.heading,
    required this.lineId,
    this.isAtStop = false,
    this.size = 56,
  });

  @override
  State<AnimatedBusMarker> createState() => _AnimatedBusMarkerState();
}

class _AnimatedBusMarkerState extends State<AnimatedBusMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isAtStop) _pulseController.stop();
  }

  @override
  void didUpdateWidget(AnimatedBusMarker old) {
    super.didUpdateWidget(old);
    if (widget.isAtStop != old.isAtStop) {
      widget.isAtStop
          ? _pulseController.stop()
          : _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _lineColor() {
    switch (widget.lineId) {
      case 'L1':
        return const Color(0xFF1565C0);
      case 'L2':
        return const Color(0xFF2E7D32);
      case 'L3':
        return const Color(0xFFE65100);
      default:
        return const Color(0xFF6B1A3A);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _lineColor();
    final s = widget.size;

    // Ángulo de la flecha de dirección (apunta en la dirección del bus)
    final arrowAngle = widget.heading * math.pi / 180;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (_, __) => Transform.scale(
        scale: widget.isAtStop ? 1.0 : _pulseAnimation.value,
        child: SizedBox(
          width: s,
          height: s,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // ── Sombra ──────────────────────────────
              Container(
                width: s * 0.82,
                height: s * 0.82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),

              // ── Círculo principal ────────────────────
              Container(
                width: s * 0.82,
                height: s * 0.82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: Alignment(-0.3, -0.3),
                    radius: 0.85,
                    colors: [
                      Color.lerp(color, Colors.white, 0.25)!,
                      color,
                    ],
                  ),
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icono del bus
                      Icon(
                        Icons.directions_bus_rounded,
                        color: Colors.white,
                        size: s * 0.34,
                      ),
                      // Badge de línea
                      Container(
                        margin: EdgeInsets.only(top: s * 0.02),
                        padding: EdgeInsets.symmetric(
                          horizontal: s * 0.07,
                          vertical: s * 0.01,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.28),
                          borderRadius: BorderRadius.circular(s * 0.1),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            widget.lineId,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: s * 0.16,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Flecha de dirección ──────────────────
              Transform.rotate(
                angle: arrowAngle,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: CustomPaint(
                    size: Size(s * 0.2, s * 0.16),
                    painter: _DirectionArrow(color: color),
                  ),
                ),
              ),

              // ── Indicador de parada ──────────────────
              if (widget.isAtStop)
                Positioned(
                  top: -s * 0.05,
                  right: -s * 0.05,
                  child: Container(
                    width: s * 0.3,
                    height: s * 0.3,
                    decoration: BoxDecoration(
                      color: Colors.orange.shade700,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Icon(
                      Icons.pause_rounded,
                      size: s * 0.17,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DirectionArrow extends CustomPainter {
  final Color color;
  const _DirectionArrow({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(_DirectionArrow old) => old.color != color;
}
