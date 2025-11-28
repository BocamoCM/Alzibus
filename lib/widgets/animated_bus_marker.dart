import 'package:flutter/material.dart';
import 'dart:math' as math;

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
    this.size = 48,
  });

  @override
  State<AnimatedBusMarker> createState() => _AnimatedBusMarkerState();
}

class _AnimatedBusMarkerState extends State<AnimatedBusMarker>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _bounceController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _bounceAnimation = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );

    if (!widget.isAtStop) {
      _bounceController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AnimatedBusMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAtStop != oldWidget.isAtStop) {
      if (widget.isAtStop) {
        _bounceController.stop();
        _bounceController.reset();
      } else {
        _bounceController.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  Color _getLineColor() {
    switch (widget.lineId) {
      case 'L1':
        return const Color(0xFF2E7D32); // Verde oscuro
      case 'L2':
        return const Color(0xFF1565C0); // Azul
      case 'L3':
        return const Color(0xFFE65100); // Naranja
      default:
        return const Color(0xFF6B2D5B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getLineColor();

    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _bounceAnimation]),
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _bounceAnimation.value),
          child: Transform.scale(
            scale: _pulseAnimation.value,
            child: Transform.rotate(
              angle: (widget.heading - 90) * math.pi / 180,
              child: _buildBus3D(color),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBus3D(Color color) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Sombra
          Positioned(
            bottom: 0,
            child: Container(
              width: widget.size * 0.7,
              height: widget.size * 0.15,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(widget.size * 0.1),
              ),
            ),
          ),
          // Cuerpo del autobus
          Container(
            width: widget.size * 0.8,
            height: widget.size * 0.45,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withOpacity(0.9),
                  color,
                  color.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(widget.size * 0.1),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Ventanas
                Positioned(
                  top: widget.size * 0.08,
                  left: widget.size * 0.08,
                  right: widget.size * 0.08,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(
                      3,
                      (i) => Container(
                        width: widget.size * 0.15,
                        height: widget.size * 0.12,
                        decoration: BoxDecoration(
                          color: Colors.lightBlue.shade100,
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Frente del autobus
                Positioned(
                  right: 0,
                  top: widget.size * 0.1,
                  bottom: widget.size * 0.1,
                  child: Container(
                    width: widget.size * 0.12,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(4),
                        bottomRight: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
                // Numero de linea
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      widget.lineId,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: widget.size * 0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Ruedas
          Positioned(
            bottom: widget.size * 0.12,
            left: widget.size * 0.15,
            child: _buildWheel(),
          ),
          Positioned(
            bottom: widget.size * 0.12,
            right: widget.size * 0.15,
            child: _buildWheel(),
          ),
          // Indicador de parada
          if (widget.isAtStop)
            Positioned(
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.stop,
                  size: widget.size * 0.2,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWheel() {
    return Container(
      width: widget.size * 0.12,
      height: widget.size * 0.12,
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade600, width: 2),
      ),
    );
  }
}
