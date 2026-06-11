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

  // Spring crítico-amortiguado: no rebota nada, baja exponencialmente
  // hasta el target. Es lo que da la sensación de "deslizar suave hasta
  // pararse" sin micro-oscilaciones cuando sueltas a mitad de drag.
  // damping² = 4*mass*stiffness → critical damping. Con mass=1 y
  // stiffness=160 el critical es damping≈25.3, redondeamos a 26 para
  // estar ligeramente sobre-amortiguado (cero rebote garantizado).
  static const SpringDescription _spring = SpringDescription(
    mass: 1.0,
    stiffness: 160,
    damping: 26,
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
  void didUpdateWidget(covariant CardStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    // El padre acaba de aplicar el swap (cambio de selectedIndex). Si en
    // ese momento _ctrl estaba al final de la animación de swap (t≈1),
    // ahora podemos resetearlo a 0 SIN flicker — porque con el nuevo
    // selectedIndex el estado visual de "_ctrl=0" coincide pixel a pixel
    // con el de "_ctrl=1 + selectedIndex viejo".
    if (oldWidget.selectedIndex != widget.selectedIndex && _ctrl.value > 0.9) {
      _ctrl.value = 0;
      _dragDy = 0;
    }
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
    // Solo aceptamos velocidad positiva (hacia el target 1.0) — si el
    // usuario soltó "frenando" o moviéndose hacia arriba, la convertimos
    // a 0 para que el spring no haga un rebote raro hacia atrás antes
    // de avanzar.
    final v = velocity > 0 ? velocity : 0.0;
    _animateTo(1.0, velocity: v).then((_) {
      if (!mounted) return;
      // Notificamos al padre del cambio de slot pero NO reseteamos
      // _ctrl aquí. El reset (a 0) ocurre dentro de didUpdateWidget,
      // que se dispara solo cuando el rebuild del padre llega con el
      // nuevo selectedIndex. Si reseteamos antes había un frame en el
      // que widget.selectedIndex aún era el viejo + _ctrl=0 → pintaba
      // el estado pre-swap durante un instante (flicker).
      final next = widget.selectedIndex == 0 ? 1 : 0;
      widget.onSelected(next);
    });
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (widget.cards.length < 2) return;
    // Si había una animación en curso (p. ej. el usuario empieza un nuevo
    // drag mientras la pila aún estaba rebotando), la paramos para que
    // el seguimiento del dedo sea inmediato.
    if (_ctrl.isAnimating) _ctrl.stop();
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
    // Convertimos la velocidad en píxeles a la escala 0..1 del controller
    // para que el spring "herede" el momento del usuario.
    final normalizedVel = vy / (widget.cardHeight * 0.55);
    final shouldSwap = _ctrl.value > 0.32 || vy > 700;

    if (shouldSwap) {
      _completeSwap(normalizedVel.clamp(0.0, 10.0));
    } else {
      // Volver a 0: la velocidad útil es negativa (o cero si el dedo se
      // frenó). Una velocidad positiva aquí provocaría un overshoot
      // descendente antes de subir, que es lo que se notaba como salto.
      final retVel = normalizedVel < 0 ? normalizedVel : 0.0;
      _animateTo(0.0, velocity: retVel.clamp(-10.0, 0.0));
      _dragDy = 0;
    }
  }

  void _onTapBack() {
    if (widget.cards.length < 2) return;
    if (_ctrl.isAnimating) _ctrl.stop();
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

