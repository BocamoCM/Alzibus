import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Pila tipo Google Wallet de hasta 2 tarjetas.
///
/// La seleccionada cubre casi por completo a la otra, que solo asoma por
/// la parte superior ([peekHeight]). Para cambiar:
///   * **Tap** en la tira superior (la franja visible de la trasera).
///   * **Drag** vertical hacia abajo sobre la frontal.
///
/// La animación usa `SpringSimulation` (física real) y NO tiene "salto
/// al final" — el cambio de roles se hace cuando las dos tarjetas ya
/// están exactamente en la posición de reposo del nuevo estado, así que
/// el reset del controller a 0 es visualmente idéntico al final de la
/// transición.
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
  late AnimationController _ctrl;
  double _dragDy = 0;

  // Spring suave, casi sin rebote: la transición entera dura ~600 ms y
  // el "settle" final es prácticamente plano. Damping alto = más fluido,
  // stiffness moderada = no se siente lenta.
  static const SpringDescription _spring = SpringDescription(
    mass: 1.0,
    stiffness: 130,
    damping: 18,
  );

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
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

  Future<void> _animateTo(double target, {double velocity = 0}) {
    final sim = SpringSimulation(_spring, _ctrl.value, target, velocity);
    return _ctrl.animateWith(sim);
  }

  void _completeSwap(double velocity) {
    _animateTo(1.0, velocity: velocity).then((_) {
      if (!mounted) return;
      // Cuando t=1, la "saliente" ya está en posición de TRASERA y la
      // "entrante" ya está en posición de FRONTAL. Intercambiamos los
      // índices Y reseteamos _ctrl a 0 — visualmente no se nota porque
      // las posiciones de cada tarjeta son las correctas en ambos lados.
      final next = widget.selectedIndex == 0 ? 1 : 0;
      widget.onSelected(next);
      _dragDy = 0;
      _ctrl.value = 0;
    });
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (widget.cards.length < 2) return;
    _dragDy += details.delta.dy;
    if (_dragDy < 0) _dragDy = 0;
    final progress = (_dragDy / (widget.cardHeight * 0.55)).clamp(0.0, 1.0);
    _ctrl.value = progress;
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (widget.cards.length < 2) {
      _dragDy = 0;
      return;
    }
    final vy = details.velocity.pixelsPerSecond.dy;
    final normalizedVel =
        (vy / (widget.cardHeight * 0.55)).clamp(-8.0, 8.0);
    final shouldSwap = _ctrl.value > 0.32 || vy > 700;

    if (shouldSwap) {
      _completeSwap(normalizedVel.toDouble().clamp(0.0, 8.0));
    } else {
      _animateTo(0.0, velocity: normalizedVel.toDouble().clamp(-8.0, 0.0));
      _dragDy = 0;
    }
  }

  void _onTapBack() {
    if (widget.cards.length < 2) return;
    _completeSwap(0);
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
    final totalHeight = h + peek;

    return SizedBox(
      height: totalHeight,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = _ctrl.value;

          // En t=0  (reposo): saliente está en posición FRONTAL (Y=peek, scale=1),
          //                   entrante en posición TRASERA (Y=0, scale=0.96).
          // En t=1  (swap completo): se intercambian — saliente en TRASERA,
          //                   entrante en FRONTAL. Sin saltos.
          //
          // Animar simultáneamente ambos parámetros (Y + scale) da el "baile"
          // típico de Wallet donde las dos cartas se cruzan suavemente.

          // Carta SALIENTE (frontIdx): pasa de frontal → trasera.
          final goingY = peek - peek * t;
          final goingScale = 1.0 - 0.04 * t;

          // Carta ENTRANTE (backIdx): pasa de trasera → frontal.
          final comingY = peek * t;
          final comingScale = 0.96 + 0.04 * t;

          // Z-order: hasta el punto medio (t=0.5) la SALIENTE está encima
          // (es la que el usuario "agarra"); a partir de ahí la ENTRANTE
          // pasa al frente. Ese cruce se nota como un "hand-off" natural
          // sin que ninguna se vea cortada.
          final entranteOnTop = t >= 0.5;

          // Función auxiliar: devuelve un Positioned para meter en el Stack.
          // Si `withGestures` es true le inyectamos el GestureDetector
          // DENTRO del Positioned (no fuera, lo cual rompía el layout y
          // dejaba un overlay invisible flotando sobre la pila).
          Positioned buildLayer({
            required double top,
            required double scale,
            required Widget child,
            required bool withGestures,
          }) {
            final visual = Transform.scale(
              scale: scale,
              alignment: Alignment.topCenter,
              child: SizedBox(height: h, child: child),
            );
            return Positioned(
              left: 0,
              right: 0,
              top: top,
              child: withGestures
                  ? GestureDetector(
                      behavior: HitTestBehavior.deferToChild,
                      onVerticalDragUpdate: _onVerticalDragUpdate,
                      onVerticalDragEnd: _onVerticalDragEnd,
                      child: visual,
                    )
                  : visual,
            );
          }

          final goingLayer = buildLayer(
            top: goingY,
            scale: goingScale,
            child: cards[frontIdx],
            withGestures: !entranteOnTop, // la saliente capta los gestos hasta t=0.5
          );
          final comingLayer = buildLayer(
            top: comingY,
            scale: comingScale,
            child: cards[backIdx],
            withGestures: entranteOnTop, // a partir de t=0.5 los gestos pasan a la entrante
          );

          // Las sombras visuales las pinta cada NfcCardVisual con su
          // propio boxShadow en su Container — aquí solo controlamos
          // posición, escala y z-order.

          return Stack(
            children: [
              // Capa invisible que captura el TAP en la franja superior
              // (la zona "peek") cuando la pila está en reposo.
              if (t < 0.05)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: peek,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _onTapBack,
                  ),
                ),
              // Orden visual: la que va detrás primero, la que va delante después.
              entranteOnTop ? goingLayer : comingLayer,
              entranteOnTop ? comingLayer : goingLayer,
            ],
          );
        },
      ),
    );
  }
}

