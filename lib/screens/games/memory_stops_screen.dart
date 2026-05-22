import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/ad_provider.dart';
import '../../core/providers/game_currency_provider.dart';
import '../../core/providers/stops_provider.dart';
import '../../models/bus_stop.dart';
import '../../theme/app_theme.dart';

/// Mini-juego "Memoria de paradas" — Simon Says con paradas reales de Alzira.
///
/// Mecánica:
/// - 9 paradas se muestran en una cuadrícula 3x3 (elegidas al azar de las 57
///   reales que carga la app).
/// - Albus muestra una secuencia: cada parada se ilumina por turnos.
/// - El jugador debe tocar las paradas en el MISMO orden.
/// - Si lo logra, siguiente ronda con +1 parada en la secuencia.
/// - Empieza con 3 paradas. No hay vidas — un fallo = game over.
/// - Récord: ronda más alta alcanzada.
/// - Rewarded ad disponible 1 vez para "Repetir secuencia" si fallas.
class MemoryStopsScreen extends ConsumerStatefulWidget {
  const MemoryStopsScreen({super.key});

  @override
  ConsumerState<MemoryStopsScreen> createState() => _MemoryStopsScreenState();
}

class _MemoryStopsScreenState extends ConsumerState<MemoryStopsScreen> {
  static const int _gridSize = 9; // 3x3
  static const int _startLength = 3;

  List<BusStop> _gridStops = [];
  List<int> _sequence = []; // índices en _gridStops
  int _playerStep = 0;
  int _round = 0;
  int _highlightIndex = -1; // -1 = ninguno destacado
  bool _showingSequence = false;
  bool _gameOver = false;
  bool _retryUsed = false;

  @override
  void initState() {
    super.initState();
    // Esperar a que stops esté cargado; el build inicial lo gestiona.
  }

  void _startNewGame(List<BusStop> allStops) {
    final rnd = math.Random();
    final shuffled = List<BusStop>.from(allStops)..shuffle(rnd);
    setState(() {
      _gridStops = shuffled.take(_gridSize).toList();
      _sequence = [];
      _round = 0;
      _playerStep = 0;
      _gameOver = false;
      _retryUsed = false;
    });
    _nextRound();
  }

  void _nextRound() {
    final rnd = math.Random();
    setState(() {
      _round++;
      // Para la 1ª ronda: longitud = _startLength. Cada nueva ronda
      // añade una parada más a la secuencia.
      _sequence = List.generate(
        _startLength + (_round - 1),
        (_) => rnd.nextInt(_gridSize),
      );
      _playerStep = 0;
    });
    _showSequence();
  }

  Future<void> _showSequence() async {
    setState(() => _showingSequence = true);
    // Pequeña pausa antes de empezar.
    await Future.delayed(const Duration(milliseconds: 600));
    for (var i = 0; i < _sequence.length; i++) {
      if (!mounted) return;
      setState(() => _highlightIndex = _sequence[i]);
      // Cuanto más alta la ronda, más rápido — hasta un mínimo razonable.
      final ms = math.max(280, 700 - _round * 30);
      await Future.delayed(Duration(milliseconds: ms));
      if (!mounted) return;
      setState(() => _highlightIndex = -1);
      await Future.delayed(const Duration(milliseconds: 150));
    }
    if (!mounted) return;
    setState(() => _showingSequence = false);
  }

  void _onStopTap(int index) {
    if (_showingSequence || _gameOver) return;
    setState(() => _highlightIndex = index);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _highlightIndex = -1);
    });

    if (_sequence[_playerStep] == index) {
      _playerStep++;
      if (_playerStep >= _sequence.length) {
        // Ronda completada.
        Future.delayed(const Duration(milliseconds: 350), _nextRound);
      }
    } else {
      _onMistake();
    }
  }

  Future<void> _onMistake() async {
    setState(() => _gameOver = true);
    // Monedas: 1 por ronda completada.
    final earned = math.max(0, _round - 1);
    if (earned > 0) {
      ref.read(gameCurrencyProvider.notifier).add(earned);
    }
    await ref.read(memoryStopsHighScoreProvider.notifier).reportScore(_round - 1);
  }

  Future<void> _retryWithAd() async {
    if (_retryUsed) return;
    final adService = ref.read(adServiceProvider);
    // Completer para esperar al callback de AdMob (antes polling 6s,
    // demasiado corto para ads de 30s — el reward no llegaba).
    final completer = Completer<bool>();
    try {
      adService.showRewardedAd(onRewarded: () {
        if (!completer.isCompleted) completer.complete(true);
      });
    } catch (_) {
      if (!completer.isCompleted) completer.complete(false);
    }
    final rewarded = await completer.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () => false,
    );
    if (!mounted) return;
    if (rewarded) {
      setState(() {
        _retryUsed = true;
        _gameOver = false;
        _playerStep = 0;
      });
      _showSequence();
    }
  }

  @override
  Widget build(BuildContext context) {
    final stopsAsync = ref.watch(stopsProvider);
    return Scaffold(
      backgroundColor: AlzitransColors.background,
      appBar: AppBar(
        title: const Text('Memoria de paradas'),
        backgroundColor: AlzitransColors.burgundy,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: stopsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error cargando paradas: $e')),
          data: (allStops) {
            if (_gridStops.isEmpty && !_gameOver) {
              // Primera vez — arranca la partida en cuanto tengamos paradas.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _gridStops.isEmpty) _startNewGame(allStops);
              });
              return const Center(child: CircularProgressIndicator());
            }
            return _buildBody(allStops);
          },
        ),
      ),
    );
  }

  Widget _buildBody(List<BusStop> allStops) {
    return Column(
      children: [
        _buildHud(),
        Expanded(child: _gameOver ? _buildGameOver(allStops) : _buildGrid()),
      ],
    );
  }

  Widget _buildHud() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _Chip(icon: Icons.layers, color: AlzitransColors.burgundy, label: 'Ronda $_round'),
          const SizedBox(width: 10),
          _Chip(icon: Icons.timeline, color: Colors.orange, label: 'Secuencia: ${_sequence.length}'),
          const Spacer(),
          if (_showingSequence)
            const Row(
              children: [
                Icon(Icons.visibility, color: AlzitransColors.burgundy, size: 16),
                SizedBox(width: 4),
                Text('Albus muestra', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            )
          else if (!_gameOver)
            const Row(
              children: [
                Icon(Icons.touch_app, color: Colors.green, size: 16),
                SizedBox(width: 4),
                Text('Tu turno', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.0,
        ),
        itemCount: _gridStops.length,
        itemBuilder: (_, i) => _buildStopCell(i),
      ),
    );
  }

  Widget _buildStopCell(int index) {
    final stop = _gridStops[index];
    final highlighted = _highlightIndex == index;
    return GestureDetector(
      onTap: () => _onStopTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: highlighted ? Colors.amber.shade300 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: highlighted ? Colors.amber.shade700 : AlzitransColors.burgundy,
            width: highlighted ? 3 : 1.5,
          ),
          boxShadow: highlighted
              ? [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.5),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        padding: const EdgeInsets.all(8),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.directions_bus,
                color: highlighted ? Colors.brown.shade800 : AlzitransColors.burgundy,
                size: 26,
              ),
              const SizedBox(height: 4),
              Text(
                _shortName(stop.name),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Acorta el nombre de la parada para que quepa en la celda 3x3 sin
  /// quedar ilegible. Quita prefijos largos y mete el primer trozo útil.
  String _shortName(String name) {
    final clean = name
        .replaceAll(RegExp(r'^(AV\.|CARRER|PLAÇA|PERE|GV\.|RONDA) '), '')
        .replaceAll(' (A HOSPITAL)', '')
        .replaceAll(' (A ESTACIO)', '');
    return clean.length > 28 ? '${clean.substring(0, 28)}…' : clean;
  }

  Widget _buildGameOver(List<BusStop> allStops) {
    final highScore = ref.watch(memoryStopsHighScoreProvider);
    final reached = _round - 1; // rondas COMPLETADAS, no la actual fallida
    final newRecord = reached > 0 && reached >= highScore;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.psychology, size: 80, color: AlzitransColors.burgundy),
            const SizedBox(height: 16),
            const Text(
              '¡Game Over!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(
              'Llegaste a la ronda $reached',
              style: const TextStyle(fontSize: 18),
            ),
            Text(
              newRecord ? '🏆 ¡Nuevo récord!' : 'Récord: $highScore rondas',
              style: TextStyle(
                color: newRecord ? Colors.amber.shade800 : Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '+${math.max(0, reached)} 🪙 al monedero',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            if (!_retryUsed)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _retryWithAd,
                  icon: const Icon(Icons.play_circle),
                  label: const Text('Repetir secuencia (anuncio)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _startNewGame(allStops),
                icon: const Icon(Icons.refresh),
                label: const Text('Jugar otra vez'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AlzitransColors.burgundy,
                  side: const BorderSide(color: AlzitransColors.burgundy, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

class _Chip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _Chip({required this.icon, required this.color, required this.label});

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
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 13)),
        ],
      ),
    );
  }
}
