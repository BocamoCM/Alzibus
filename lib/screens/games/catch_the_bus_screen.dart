import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibration/vibration.dart';

import '../../core/providers/ad_provider.dart';
import '../../core/providers/game_currency_provider.dart';
import '../../theme/app_theme.dart';

/// Mini-juego "Caza el Bus" — buses cruzan la pantalla, tócalos para puntuar.
///
/// Mecánica simple:
/// - 3 carriles horizontales (alto / medio / bajo).
/// - Buses verdes 🚌 = +10 puntos al tocarlos.
/// - Buses rojos averiados 🚒 = -1 vida si los tocas.
/// - Si un bus VERDE escapa sin que lo toques, -1 vida.
/// - Empiezas con 3 vidas. Game over a 0.
/// - Dificultad sube: spawn más rápido + buses más rápidos.
///
/// Game over: ver anuncio rewarded para +1 vida y continuar, o volver al menú.
///
/// Implementación: cada bus es un widget con su propio AnimationController
/// que lo mueve de derecha a izquierda. Cuando llega al borde, se elimina
/// y, si era verde y no se tocó, descuenta una vida.
class CatchTheBusScreen extends ConsumerStatefulWidget {
  const CatchTheBusScreen({super.key});

  @override
  ConsumerState<CatchTheBusScreen> createState() => _CatchTheBusScreenState();
}

class _CatchTheBusScreenState extends ConsumerState<CatchTheBusScreen>
    with TickerProviderStateMixin {
  // Estado del juego
  int _score = 0;
  int _lives = 3;
  bool _isGameOver = false;
  bool _isPaused = false;
  bool _adRewardedUsed = false; // solo permitimos revivir una vez por partida

  // Lista de buses activos en pantalla
  final List<_BusEntity> _buses = [];
  Timer? _spawnTimer;
  int _nextBusId = 0;

  // Tiempo transcurrido — para subir dificultad.
  Duration _elapsed = Duration.zero;
  Timer? _elapsedTimer;

  // Velocidad y frecuencia de spawn (se ajustan con la dificultad)
  Duration get _spawnInterval {
    final secs = _elapsed.inSeconds;
    if (secs < 15) return const Duration(milliseconds: 1800);
    if (secs < 30) return const Duration(milliseconds: 1400);
    if (secs < 60) return const Duration(milliseconds: 1100);
    return const Duration(milliseconds: 850);
  }

  /// Duración que tarda un bus en cruzar la pantalla.
  Duration get _busDuration {
    final secs = _elapsed.inSeconds;
    if (secs < 15) return const Duration(milliseconds: 4500);
    if (secs < 30) return const Duration(milliseconds: 3800);
    if (secs < 60) return const Duration(milliseconds: 3100);
    return const Duration(milliseconds: 2500);
  }

  /// Probabilidad de spawn un bus "malo" (rojo) — sube con el tiempo.
  double get _badBusProbability {
    final secs = _elapsed.inSeconds;
    if (secs < 10) return 0.0;
    if (secs < 25) return 0.15;
    if (secs < 50) return 0.25;
    return 0.35;
  }

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _spawnTimer?.cancel();
    _elapsedTimer?.cancel();
    for (final b in _buses) {
      b.controller.dispose();
    }
    super.dispose();
  }

  void _start() {
    _spawnTimer?.cancel();
    _elapsedTimer?.cancel();

    // Antes de limpiar la lista, dispose los controllers que sigan vivos —
    // si no, la partida anterior dejaba leaks y los whenComplete podían
    // disparar setState fantasma en la nueva partida.
    for (final b in _buses) {
      try { b.controller.dispose(); } catch (_) {/* ya dispuesto */}
    }

    setState(() {
      _score = 0;
      _lives = 3;
      _isGameOver = false;
      _isPaused = false;
      _adRewardedUsed = false;
      _elapsed = Duration.zero;
      _buses.clear();
    });

    _scheduleSpawn();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _isGameOver || _isPaused) return;
      setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  void _scheduleSpawn() {
    _spawnTimer?.cancel();
    if (_isGameOver || _isPaused) return;
    _spawnTimer = Timer(_spawnInterval, () {
      if (!mounted || _isGameOver || _isPaused) return;
      _spawnBus();
      _scheduleSpawn();
    });
  }

  void _spawnBus() {
    final rnd = math.Random();
    final lane = rnd.nextInt(3); // 0=top, 1=middle, 2=bottom
    final isBad = rnd.nextDouble() < _badBusProbability;
    final id = _nextBusId++;

    final controller = AnimationController(
      vsync: this,
      duration: _busDuration,
    );

    final bus = _BusEntity(
      id: id,
      lane: lane,
      isBad: isBad,
      controller: controller,
    );

    setState(() => _buses.add(bus));

    controller.forward().whenComplete(() {
      // `whenComplete` se dispara tanto al COMPLETAR como al DISPONER el
      // controller (ej: cuando empezamos partida nueva). Si ya está marcado
      // como removido, salimos para no contar vidas fantasma.
      if (!mounted || bus.removed) return;
      // Si llegó al final sin que lo tocaran:
      // - Verde escapado → -1 vida
      // - Rojo escapado → +0 (era trampa, está bien evitarlo)
      if (!bus.tapped && !bus.isBad) {
        _loseLife('Se te escapó un bus verde');
      }
      _removeBus(bus);
    });
  }

  void _removeBus(_BusEntity bus) {
    if (bus.removed) return;
    bus.removed = true;
    // 1. Quitar del Stack ya, para que en el siguiente frame el
    //    AnimatedBuilder ya no esté en el árbol.
    if (mounted) setState(() => _buses.remove(bus));
    // 2. Disponer el controller TRAS el frame committed — así
    //    AnimatedBuilder no recibe un tick de un controller disposed
    //    (era una causa probable del "parpadeo" antes de desaparecer).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try { bus.controller.dispose(); } catch (_) {/* ya disposed */}
    });
  }

  Future<void> _onBusTap(_BusEntity bus) async {
    if (bus.tapped || bus.removed || _isGameOver) return;
    bus.tapped = true;

    if (bus.isBad) {
      _loseLife('Has tocado un bus averiado 🚒');
      _flashRed();
    } else {
      setState(() => _score += 10);
      try {
        // En versiones recientes de `vibration`, hasVibrator() devuelve bool
        // (no bool?), por eso no usamos null-aware aquí.
        if (await Vibration.hasVibrator()) {
          await Vibration.vibrate(duration: 30);
        }
      } catch (_) {}
    }

    // Tras 250ms (lo que tarda el fade-out), retiramos el bus del Stack en
    // lugar de esperar a que cruce media pantalla más. Así no se queda
    // "fantasma" recibiendo taps invisibles ni gastando frames.
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _removeBus(bus);
    });
  }

  void _flashRed() {
    // Vibración + flash de color (visual feedback)
    try {
      Vibration.vibrate(duration: 120);
    } catch (_) {}
  }

  void _loseLife(String reason) {
    if (_isGameOver) return;
    setState(() => _lives -= 1);
    if (_lives <= 0) {
      _gameOver();
    }
  }

  Future<void> _gameOver() async {
    setState(() => _isGameOver = true);
    _spawnTimer?.cancel();
    _elapsedTimer?.cancel();

    // Guardar puntuación y monedas.
    ref.read(gameCurrencyProvider.notifier).add(_score ~/ 10);
    final newRecord =
        await ref.read(catchTheBusHighScoreProvider.notifier).reportScore(_score);
    if (newRecord && mounted) {
      // Pequeño feedback visual — un SnackBar al volver al menú lo verá igual.
    }
  }

  /// Muestra el rewarded ad. Si el usuario lo ve completo, le damos +1 vida
  /// y reanudamos el juego desde donde estaba (mismo score).
  Future<void> _watchAdToRevive() async {
    if (_adRewardedUsed) return;
    setState(() => _isPaused = true);

    final adService = ref.read(adServiceProvider);
    bool rewarded = false;
    try {
      adService.showRewardedAd(onRewarded: () {
        rewarded = true;
      });
    } catch (_) {/* silencioso */}

    // Esperamos un instante para que el callback del ad llegue.
    // No es perfecto pero funciona en la mayoría de OEMs.
    await Future.delayed(const Duration(milliseconds: 500));
    // Polling cortito por si el ad tarda en cerrar.
    for (var i = 0; i < 40; i++) {
      if (rewarded) break;
      await Future.delayed(const Duration(milliseconds: 150));
    }

    if (!mounted) return;
    if (rewarded) {
      setState(() {
        _adRewardedUsed = true;
        _lives = 1; // revivimos con 1 vida
        _isGameOver = false;
        _isPaused = false;
      });
      _scheduleSpawn();
    } else {
      setState(() => _isPaused = false);
    }
  }

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
    if (!_isPaused && !_isGameOver) {
      _scheduleSpawn();
    } else {
      _spawnTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E7), // crema cálido
      appBar: AppBar(
        title: const Text('Caza el Bus'),
        backgroundColor: AlzitransColors.burgundy,
        foregroundColor: Colors.white,
        actions: [
          if (!_isGameOver)
            IconButton(
              icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
              onPressed: _togglePause,
              tooltip: _isPaused ? 'Reanudar' : 'Pausa',
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHud(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) =>
                    _buildGameField(constraints),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHud() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: Row(
        children: [
          _HudChip(icon: Icons.star, color: Colors.amber, label: '$_score'),
          const SizedBox(width: 12),
          _HudChip(
            icon: Icons.favorite,
            color: AlzitransColors.error,
            label: '$_lives',
          ),
          const Spacer(),
          _HudChip(
            icon: Icons.timer,
            color: Colors.grey,
            label: '${_elapsed.inSeconds}s',
          ),
        ],
      ),
    );
  }

  Widget _buildGameField(BoxConstraints constraints) {
    if (_isGameOver) {
      return _buildGameOverOverlay();
    }
    final height = constraints.maxHeight;
    final width = constraints.maxWidth;
    final laneHeight = height / 3;

    return Stack(
      children: [
        // Líneas guía de los carriles (sutiles).
        for (var i = 1; i < 3; i++)
          Positioned(
            top: laneHeight * i,
            left: 0,
            right: 0,
            child: Container(
              height: 1,
              color: Colors.grey.shade300,
            ),
          ),

        // Buses activos. Cada uno con su `ValueKey(bus.id)` para que Flutter
        // los identifique unívocamente entre rebuilds y NO los confunda entre
        // sí (era la causa de que parecieran "aparecer/desaparecer" cuando
        // el Stack se reconstruía).
        for (final bus in _buses)
          AnimatedBuilder(
            key: ValueKey('bus-${bus.id}'),
            animation: bus.controller,
            builder: (_, __) {
              // De x=width (fuera derecha) a x=-80 (fuera izquierda).
              final startX = width;
              final endX = -80.0;
              final x = startX + (endX - startX) * bus.controller.value;
              final y = laneHeight * bus.lane + (laneHeight - 60) / 2;

              return Positioned(
                key: ValueKey('pos-${bus.id}'),
                left: x,
                top: y,
                child: GestureDetector(
                  onTap: () => _onBusTap(bus),
                  child: AnimatedOpacity(
                    opacity: bus.tapped ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: AnimatedScale(
                      scale: bus.tapped ? 1.3 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: _BusSprite(isBad: bus.isBad),
                    ),
                  ),
                ),
              );
            },
          ),

        if (_isPaused)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Text(
                'PAUSA',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGameOverOverlay() {
    final highScore = ref.watch(catchTheBusHighScoreProvider);
    final newRecord = _score > 0 && _score >= highScore;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '¡Game Over!',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            Text(
              'Puntuación: $_score',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              newRecord ? '🏆 ¡Nuevo récord!' : 'Récord: $highScore',
              style: TextStyle(
                color: newRecord ? Colors.amber.shade800 : Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '+${_score ~/ 10} 🪙 al monedero',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),

            if (!_adRewardedUsed) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _watchAdToRevive,
                  icon: const Icon(Icons.play_circle),
                  label: const Text('Revivir viendo un anuncio'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.refresh),
                label: const Text('Jugar otra vez'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AlzitransColors.burgundy,
                  side: const BorderSide(color: AlzitransColors.burgundy, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Volver al menú'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Datos de un bus en pantalla.
class _BusEntity {
  final int id;
  final int lane;
  final bool isBad;
  final AnimationController controller;
  bool tapped = false;
  /// True una vez que llamamos a `_removeBus`. Previene doble-dispose del
  /// controller y vidas fantasma desde `whenComplete` tras la limpieza.
  bool removed = false;

  _BusEntity({
    required this.id,
    required this.lane,
    required this.isBad,
    required this.controller,
  });
}

class _BusSprite extends StatelessWidget {
  final bool isBad;
  const _BusSprite({required this.isBad});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      height: 60,
      decoration: BoxDecoration(
        color: isBad ? Colors.red.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isBad ? Colors.red : AlzitransColors.burgundy,
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          isBad ? '🚒' : '🚌',
          style: const TextStyle(fontSize: 36),
        ),
      ),
    );
  }
}

class _HudChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _HudChip({required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: color,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
