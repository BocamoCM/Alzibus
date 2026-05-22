import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/ad_provider.dart';
import '../../core/providers/game_currency_provider.dart';
import '../../theme/app_theme.dart';

/// Mini-juego "Trivia de Alzira" — 10 preguntas random sobre Alzira, los buses
/// y la app. 4 opciones cada una, 15s para responder.
///
/// Puntuación:
/// - +50 por acierto + bonus de tiempo (hasta +50 si respondes en <5s).
/// - 0 por fallo.
/// - 0 si se acaba el tiempo (cuenta como fallo).
///
/// Rewarded ad disponible 1 vez por partida para "Saltar pregunta sin penalización".
class TriviaAlziraScreen extends ConsumerStatefulWidget {
  const TriviaAlziraScreen({super.key});

  @override
  ConsumerState<TriviaAlziraScreen> createState() => _TriviaAlziraScreenState();
}

class _TriviaAlziraScreenState extends ConsumerState<TriviaAlziraScreen> {
  static const int _questionsPerGame = 10;
  static const Duration _timePerQuestion = Duration(seconds: 15);

  late List<_Question> _questions;
  int _currentIndex = 0;
  int _score = 0;
  int? _selectedAnswer;
  bool _answered = false;
  bool _gameOver = false;
  bool _skipUsed = false;
  Timer? _timer;
  int _msRemaining = 15000;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    final all = List<_Question>.from(_allQuestions);
    all.shuffle();
    setState(() {
      _questions = all.take(_questionsPerGame).toList();
      _currentIndex = 0;
      _score = 0;
      _selectedAnswer = null;
      _answered = false;
      _gameOver = false;
      _skipUsed = false;
      _msRemaining = _timePerQuestion.inMilliseconds;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _msRemaining = _timePerQuestion.inMilliseconds;
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || _answered) return;
      setState(() => _msRemaining -= 100);
      if (_msRemaining <= 0) {
        _onTimeout();
      }
    });
  }

  void _onTimeout() {
    _timer?.cancel();
    setState(() {
      _answered = true;
      _selectedAnswer = -1; // marcador "se acabó el tiempo"
    });
    Future.delayed(const Duration(milliseconds: 1500), _next);
  }

  void _onAnswer(int idx) {
    if (_answered) return;
    _timer?.cancel();
    final correct = idx == _questions[_currentIndex].correctIndex;
    final timeBonus = correct ? (50 * _msRemaining ~/ _timePerQuestion.inMilliseconds) : 0;
    final delta = correct ? 50 + timeBonus : 0;

    setState(() {
      _answered = true;
      _selectedAnswer = idx;
      _score += delta;
    });

    Future.delayed(const Duration(milliseconds: 1500), _next);
  }

  void _next() {
    if (!mounted) return;
    if (_currentIndex + 1 >= _questions.length) {
      _finish();
      return;
    }
    setState(() {
      _currentIndex++;
      _answered = false;
      _selectedAnswer = null;
    });
    _startTimer();
  }

  Future<void> _finish() async {
    _timer?.cancel();
    setState(() => _gameOver = true);

    // Monedas: 1 por cada 50 puntos.
    ref.read(gameCurrencyProvider.notifier).add(_score ~/ 75);
    await ref.read(triviaHighScoreProvider.notifier).reportScore(_score);
  }

  /// Salta la pregunta actual viendo un anuncio rewarded. Solo 1 vez por
  /// partida — pensado como salvavidas cuando la pregunta es difícil.
  Future<void> _skipWithAd() async {
    if (_skipUsed || _answered) return;
    _timer?.cancel();

    final adService = ref.read(adServiceProvider);
    // Completer para esperar al callback de AdMob (antes polling 6s era
    // demasiado corto para ads de 30s).
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
      setState(() => _skipUsed = true);
      _next();
    } else {
      _startTimer(); // recupera timer si no llegó la recompensa
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AlzitransColors.background,
      appBar: AppBar(
        title: const Text('Trivia de Alzira'),
        backgroundColor: AlzitransColors.burgundy,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: _gameOver ? _buildGameOver() : _buildPlaying(),
      ),
    );
  }

  Widget _buildPlaying() {
    final q = _questions[_currentIndex];
    final timeProgress = _msRemaining / _timePerQuestion.inMilliseconds;
    final timeColor = _msRemaining < 5000 ? AlzitransColors.error : AlzitransColors.burgundy;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Chip(
                icon: Icons.help_outline,
                color: AlzitransColors.burgundy,
                label: 'Pregunta ${_currentIndex + 1}/${_questions.length}',
              ),
              const Spacer(),
              _Chip(
                icon: Icons.star,
                color: Colors.amber,
                label: '$_score',
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Barra de tiempo
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: timeProgress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation(timeColor),
            ),
          ),
          const SizedBox(height: 24),
          // Pregunta
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                q.question,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Opciones
          Expanded(
            child: ListView.builder(
              itemCount: q.options.length,
              itemBuilder: (_, i) => _buildOption(q, i),
            ),
          ),
          if (!_skipUsed && !_answered)
            TextButton.icon(
              onPressed: _skipWithAd,
              icon: const Icon(Icons.skip_next),
              label: const Text('Saltar pregunta (ver anuncio)'),
              style: TextButton.styleFrom(foregroundColor: AlzitransColors.burgundy),
            ),
        ],
      ),
    );
  }

  Widget _buildOption(_Question q, int i) {
    final isSelected = _selectedAnswer == i;
    final isCorrect = i == q.correctIndex;
    Color? bg;
    Color? border;
    IconData? trailing;

    if (_answered) {
      if (isCorrect) {
        bg = Colors.green.shade50;
        border = Colors.green;
        trailing = Icons.check_circle;
      } else if (isSelected) {
        bg = Colors.red.shade50;
        border = Colors.red;
        trailing = Icons.cancel;
      } else {
        bg = Colors.grey.shade100;
        border = Colors.grey.shade300;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: bg ?? Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 1,
        child: InkWell(
          onTap: _answered ? null : () => _onAnswer(i),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: border ?? Colors.grey.shade300,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AlzitransColors.burgundy.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    String.fromCharCode(65 + i), // A, B, C, D
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AlzitransColors.burgundy,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    q.options[i],
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                if (trailing != null) Icon(trailing, color: border),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGameOver() {
    final highScore = ref.watch(triviaHighScoreProvider);
    final newRecord = _score > 0 && _score >= highScore;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, size: 80, color: Colors.amber),
            const SizedBox(height: 16),
            const Text(
              'Trivia completada',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(
              'Puntuación: $_score',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            Text(
              newRecord ? '🏆 ¡Nuevo récord!' : 'Récord: $highScore',
              style: TextStyle(
                color: newRecord ? Colors.amber.shade800 : Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '+${_score ~/ 75} 🪙 al monedero',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.refresh),
                label: const Text('Jugar otra vez'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AlzitransColors.burgundy,
                  foregroundColor: Colors.white,
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

class _Question {
  final String question;
  final List<String> options;
  final int correctIndex;
  const _Question(this.question, this.options, this.correctIndex);
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

// ─── Banco de preguntas ────────────────────────────────────────────────────
const List<_Question> _allQuestions = [
  // Alzira ciudad
  _Question(
    '¿En qué provincia está Alzira?',
    ['Valencia', 'Castellón', 'Alicante', 'Murcia'],
    0,
  ),
  _Question(
    '¿A qué comarca pertenece Alzira?',
    ['La Safor', 'Ribera Alta', 'Ribera Baixa', 'La Costera'],
    1,
  ),
  _Question(
    '¿Qué río atraviesa Alzira?',
    ['Túria', 'Xúquer (Júcar)', 'Segura', 'Mijares'],
    1,
  ),
  _Question(
    '¿Cuál es el gentilicio de Alzira?',
    ['Alzirense', 'Alzireño/a', 'Alcireño/a', 'Las dos últimas son válidas'],
    3,
  ),
  _Question(
    '¿En qué mes son las fiestas mayores de Alzira (San Bernat)?',
    ['Mayo', 'Julio', 'Agosto', 'Octubre'],
    1,
  ),
  _Question(
    '¿Qué edificio histórico defensivo se conserva en Alzira?',
    ['Castillo de Mola', 'Torre de la Vila', 'Muralles del Casc Antic', 'Catedral'],
    2,
  ),

  // Bus / transporte
  _Question(
    '¿Cuántas líneas de bus urbano tiene Alzira?',
    ['2', '3', '4', '5'],
    1,
  ),
  _Question(
    '¿Cómo se llama la mascota oficial de Alzitrans?',
    ['Alzi', 'Buster', 'Albus', 'Trans'],
    2,
  ),
  _Question(
    '¿En qué parada coinciden las tres líneas L1, L2 y L3?',
    ['Plaça Major', 'Hospital', 'Estació RENFE', 'Plaça del Regne'],
    2,
  ),
  _Question(
    '¿Qué color identifica habitualmente a la Línea 2 en la app?',
    ['Azul', 'Verde', 'Naranja', 'Rojo'],
    1,
  ),
  _Question(
    '¿Cuántas paradas tiene aproximadamente la red urbana de Alzira?',
    ['Unas 20', 'Unas 40', 'Unas 57', 'Más de 100'],
    2,
  ),
  _Question(
    '¿Cuál es uno de los principales destinos sanitarios servidos por todas las líneas?',
    ['Hospital de la Ribera', 'Hospital de Sueca', 'Hospital Clínic', 'Hospital General'],
    0,
  ),
  _Question(
    'En la app, ¿qué función te permite ver tu posición en directo y compartirla?',
    [
      'Histórico de viajes',
      'Compartir mi viaje en vivo',
      'Tarjeta NFC',
      'Avisos del servicio',
    ],
    1,
  ),

  // Valencia / general
  _Question(
    '¿Cuál es la capital de la Comunidad Valenciana?',
    ['Castellón', 'Valencia', 'Alicante', 'Elche'],
    1,
  ),
  _Question(
    '¿Qué nombre recibe la bandera tradicional valenciana?',
    ['Estelada', 'Senyera', 'Quatribarrada', 'Diada'],
    1,
  ),
  _Question(
    '¿Qué fruta es típica de la Ribera del Xúquer?',
    ['Manzana', 'Naranja', 'Plátano', 'Uva'],
    1,
  ),
  _Question(
    '¿Cómo se dice "autobús" en valenciano?',
    ['Autobús', 'Autocar', 'Autobús (igual)', 'Vehicle'],
    2,
  ),
  _Question(
    '¿Qué tren de cercanías conecta Alzira con Valencia?',
    ['Cercanías C-3', 'Cercanías C-1', 'AVE', 'Talgo'],
    0,
  ),
  _Question(
    '¿Qué fiesta valenciana tiene "ninots" como protagonistas en marzo?',
    ['Magdalena', 'Hogueras', 'Fallas', 'Sant Joan'],
    2,
  ),

  // App-specific (interactivo)
  _Question(
    '¿Para qué sirve el botón "Planifica con Albus"?',
    [
      'Te calcula la ruta de bus entre dos paradas',
      'Te pide un café',
      'Llama a un Uber',
      'Te enseña valenciano',
    ],
    0,
  ),
  _Question(
    '¿Cuánto tarda en caducar un enlace de "Compartir mi viaje en vivo"?',
    ['1 hora', '3 horas', '6 horas', '24 horas'],
    2,
  ),
  _Question(
    '¿Qué tarjeta es compatible con la lectura NFC de la app?',
    ['Visa contactless', 'Tarjeta Transport (MIFARE)', 'Carnet DNI', 'Tarjeta sanitaria'],
    1,
  ),
];
