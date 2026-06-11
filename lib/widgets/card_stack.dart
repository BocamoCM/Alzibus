import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Pila tipo Google Wallet: hasta 2 tarjetas apiladas verticalmente. La
/// seleccionada queda al frente cubriendo casi por completo a la otra,
/// que solo asoma por la parte superior ([peekHeight] píxeles).
///
/// Gestos:
///   * Tap en la tarjeta de atrás → la trae al frente.
///   * Drag vertical hacia abajo sobre la del frente → la "echa" abajo y
///     deja subir a la otra. Si supera el umbral o el fling es rápido,
///     se completa el swap; si no, vuelve a su sitio.
///
/// La animación usa **SpringSimulation** (física real, no curvas Bezier),
/// igual que iOS/Wallet, para que el resultado sea fluido y con rebote
/// natural cuando llega a destino.
class CardStack extends StatefulWidget {
  final List<Widget> cards;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final double cardHeight;
  final double peekHeight;

  const CardStack({
    super.key,
    required this.cards,
    required this.selectedIndex,
    required this.onSelected,
    this.cardHeight = 220,
    this.peekHeight = 38,
  });

  @override
  State<CardStack> createState() => _CardStackState();
}

class _CardStackState extends State<CardStack>
    with SingleTickerProviderStateMixin {
  /// 0 → reposo (frontal arriba en su sitio).
  /// 1 → swap completado (frontal "fuera" abajo, trasera ocupa su sitio).
  late AnimationController _ctrl;
  double _dragDy = 0;

  // Spring usado para todas las transiciones automáticas (return + swap).
  static const SpringDescription _spring = SpringDescription(
    mass: 1.0,
    stiffness: 200,
    damping: 22,
  );

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: 0,
      upperBound: 1.0,
      lowerBound: 0.0,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _animateTo(double target, {double velocity = 0, VoidCallback? onDone}) {
    final sim = SpringSimulation(_spring, _ctrl.value, target, velocity);
    _ctrl.animateWith(sim).then((_) {
      if (onDone != null) onDone();
    });
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (widget.cards.length < 2) return;
    _dragDy += details.delta.dy;
    if (_dragDy < 0) _dragDy = 0; // solo hacia abajo
    final progress = (_dragDy / (widget.cardHeight * 0.6)).clamp(0.0, 1.0);
    _ctrl.value = progress;
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (widget.cards.length < 2) {
      _dragDy = 0;
      return;
    }
    final vy = details.velocity.pixelsPerSecond.dy;
    // Normalizamos la velocidad al rango 0..1 del controller.
    final normalizedVel = vy / (widget.cardHeight * 0.6);
    final shouldSwap = _ctrl.value > 0.35 || vy > 800;

    if (shouldSwap) {
      _animateTo(1.0, velocity: normalizedVel.clamp(0, 6), onDone: () {
        if (!mounted) return;
        final next = widget.selectedIndex == 0 ? 1 : 0;
        widget.onSelected(next);
        _dragDy = 0;
        _ctrl.value = 0.0;
      });
    } else {
      _animateTo(0.0, velocity: normalizedVel.clamp(-6, 0));
      _dragDy = 0;
    }
  }

  void _onTapBack() {
    if (widget.cards.length < 2) return;
    // Tap en la trasera: la traemos al frente con un swap animado.
    _animateTo(1.0, onDone: () {
      if (!mounted) return;
      final next = widget.selectedIndex == 0 ? 1 : 0;
      widget.onSelected(next);
      _ctrl.value = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.cards;
    if (cards.isEmpty) return SizedBox(height: widget.cardHeight);
    if (cards.length == 1) {
      return SizedBox(height: widget.cardHeight, child: cards.first);
    }

    final frontIdx = widget.selectedIndex;
    final backIdx = frontIdx == 0 ? 1 : 0;
    final h = widget.cardHeight;
    final peek = widget.peekHeight;
    // Altura del Stack: la frontal ocupa todo y la trasera solo asoma
    // el `peek` por arriba, así que el contenedor tiene que medir
    // h + peek para que ambas quepan sin recortes.
    final totalHeight = h + peek;

    return SizedBox(
      height: totalHeight,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = _ctrl.value;

          // Trasera: en reposo está pegada arriba (Y=0) y un pelín
          // pequeña; al swappear baja hasta la posición de la frontal
          // (Y=peek) y recupera su tamaño 1.0.
          final backTop = peek * t;
          final backScale = 0.96 + 0.04 * t;

          // Frontal: en reposo está en Y=peek (cubre a la trasera);
          // al swappear se desplaza hacia abajo hasta salir por completo
          // (Y = h + peek). Pierde un poco de opacidad para reforzar la
          // sensación de "está saliendo".
          final frontTop = peek + (h + peek) * t;
          final frontOpacity = 1.0 - 0.4 * t;

          return Stack(
            children: [
              // Trasera (debajo en z-order).
              Positioned(
                left: 0,
                right: 0,
                top: backTop,
                child: IgnorePointer(
                  ignoring: t < 0.05, // mientras está oculta, no captura taps
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: t < 0.05 ? _onTapBack : null,
                    child: Transform.scale(
                      scale: backScale,
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        height: h,
                        child: cards[backIdx],
                      ),
                    ),
                  ),
                ),
              ),
              // Frontal (encima en z-order).
              Positioned(
                left: 0,
                right: 0,
                top: frontTop,
                child: GestureDetector(
                  onVerticalDragUpdate: _onVerticalDragUpdate,
                  onVerticalDragEnd: _onVerticalDragEnd,
                  child: Opacity(
                    opacity: frontOpacity,
                    child: SizedBox(
                      height: h,
                      child: cards[frontIdx],
                    ),
                  ),
                ),
              ),
              // Zona "asomada" de la trasera donde queremos que el tap
              // funcione también aunque la frontal esté completamente
              // a su sitio (t=0). Es una franja invisible de altura
              // `peek` arriba del todo.
              if (t < 0.05)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: peek,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _onTapBack,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
