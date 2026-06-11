import 'package:flutter/material.dart';

/// Pila de hasta 2 tarjetas con la seleccionada al frente y la otra
/// detrás (más pequeña, desplazada hacia abajo y semitransparente).
///
/// Al **arrastrar horizontalmente** la tarjeta de delante, la de atrás
/// "sube" al frente proporcionalmente a la distancia arrastrada. Si se
/// suelta pasado el umbral (30 % del ancho) o con velocidad suficiente,
/// completa el swap y notifica al padre vía [onSelected]. Si no, vuelve
/// a su sitio.
///
/// El widget no decide qué tarjeta es qué — recibe la lista ya en orden
/// estable. El padre solo le dice cuál es la seleccionada y reacciona al
/// callback.
class CardStack extends StatefulWidget {
  final List<Widget> cards;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final double height;

  const CardStack({
    super.key,
    required this.cards,
    required this.selectedIndex,
    required this.onSelected,
    this.height = 220,
  });

  @override
  State<CardStack> createState() => _CardStackState();
}

class _CardStackState extends State<CardStack>
    with SingleTickerProviderStateMixin {
  /// Animación 0..1 donde:
  ///   * 1.0 → la tarjeta seleccionada está plenamente delante (reposo).
  ///   * 0.0 → la tarjeta seleccionada está totalmente "echada hacia
  ///           atrás" y la otra al frente. Cuando esto se alcanza tras
  ///           un swipe, disparamos onSelected y reseteamos a 1.0.
  late AnimationController _ctrl;
  double _dragDx = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (widget.cards.length < 2) return;
    _dragDx += details.delta.dx;
    final width = MediaQuery.of(context).size.width;
    // Cuanto más se arrastra, más cerca de 0. 60 % del ancho = "echada".
    final progress = (1.0 - (_dragDx.abs() / (width * 0.6))).clamp(0.0, 1.0);
    _ctrl.value = progress;
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (widget.cards.length < 2) {
      _dragDx = 0;
      return;
    }
    final width = MediaQuery.of(context).size.width;
    final pastThreshold = _dragDx.abs() > width * 0.3;
    final fastFling = details.velocity.pixelsPerSecond.dx.abs() > 700;

    if (pastThreshold || fastFling) {
      // Completa la animación hasta 0 (tarjeta echada atrás) y al acabar
      // notifica al padre del cambio de slot; el padre re-renderizará con
      // la otra tarjeta al frente y aquí volvemos a 1.0 de inmediato.
      _ctrl.animateTo(0.0, curve: Curves.easeOut).then((_) {
        if (!mounted) return;
        final next = widget.selectedIndex == 0 ? 1 : 0;
        widget.onSelected(next);
        _dragDx = 0;
        _ctrl.value = 1.0;
      });
    } else {
      // No alcanza el umbral: vuelve a su sitio.
      _ctrl.animateTo(1.0, curve: Curves.easeOut);
      _dragDx = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.cards;
    if (cards.isEmpty) return SizedBox(height: widget.height);
    if (cards.length == 1) {
      return SizedBox(height: widget.height, child: cards.first);
    }

    final frontIdx = widget.selectedIndex;
    final backIdx = frontIdx == 0 ? 1 : 0;

    return SizedBox(
      height: widget.height + 24, // espacio para que el "back" no se corte
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = _ctrl.value;
          // Front pasa de (1.0, 0, 1.0) → (0.93, +12, 0.65) según t baja.
          final frontScale = 0.93 + 0.07 * t;
          final frontTranslateY = 12.0 * (1 - t);
          final frontOpacity = 0.65 + 0.35 * t;
          final frontTranslateX = _dragDx;

          // Back se mueve al inverso.
          final backScale = 1.0 - 0.07 * t;
          final backTranslateY = 12.0 * t;
          final backOpacity = 1.0 - 0.35 * t;

          return Stack(
            alignment: Alignment.center,
            children: [
              // Tarjeta de atrás. Solo capta el tap si está visible (t<1)
              // para no entorpecer el drag de la de delante.
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: IgnorePointer(
                  ignoring: t > 0.85,
                  child: GestureDetector(
                    onTap: () => widget.onSelected(backIdx),
                    child: Transform.translate(
                      offset: Offset(0, backTranslateY),
                      child: Transform.scale(
                        scale: backScale,
                        child: Opacity(
                          opacity: backOpacity,
                          child: SizedBox(
                            height: widget.height,
                            child: cards[backIdx],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Tarjeta de delante con el drag.
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: GestureDetector(
                  onHorizontalDragUpdate: _onHorizontalDragUpdate,
                  onHorizontalDragEnd: _onHorizontalDragEnd,
                  child: Transform.translate(
                    offset: Offset(frontTranslateX, frontTranslateY),
                    child: Transform.scale(
                      scale: frontScale,
                      child: Opacity(
                        opacity: frontOpacity,
                        child: SizedBox(
                          height: widget.height,
                          child: cards[frontIdx],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
