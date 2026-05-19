import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Monedas acumuladas por el jugador en los mini-juegos. Persistido en
/// SharedPreferences. Por ahora solo decorativo — futuro: comprar skins
/// para Albus, packs de vidas, etc.
///
/// Usa la nueva API de Riverpod 3 (Notifier + NotifierProvider). El valor
/// inicial es 0 y al construir dispara una carga async desde prefs.
class GameCurrencyNotifier extends Notifier<int> {
  static const String _key = 'game_coins_v1';

  @override
  int build() {
    _load();
    return 0;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getInt(_key) ?? 0;
    } catch (_) {/* default 0 */}
  }

  Future<void> add(int amount) async {
    state = state + amount;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key, state);
    } catch (_) {}
  }
}

final gameCurrencyProvider =
    NotifierProvider<GameCurrencyNotifier, int>(GameCurrencyNotifier.new);

/// Mejor puntuación en "Caza el Bus" — persistente en SharedPreferences.
class CatchTheBusHighScoreNotifier extends Notifier<int> {
  static const String _key = 'catch_the_bus_highscore_v1';

  @override
  int build() {
    _load();
    return 0;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getInt(_key) ?? 0;
    } catch (_) {/* default 0 */}
  }

  /// Reporta una puntuación. Si supera el récord actual, lo actualiza y
  /// devuelve true. Si no, devuelve false y el estado no cambia.
  Future<bool> reportScore(int score) async {
    if (score <= state) return false;
    state = score;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key, score);
    } catch (_) {}
    return true;
  }
}

final catchTheBusHighScoreProvider =
    NotifierProvider<CatchTheBusHighScoreNotifier, int>(
  CatchTheBusHighScoreNotifier.new,
);

/// Mejor puntuación en "Trivia de Alzira" (suma de puntos en una partida
/// de 10 preguntas).
class TriviaHighScoreNotifier extends Notifier<int> {
  static const String _key = 'trivia_alzira_highscore_v1';

  @override
  int build() {
    _load();
    return 0;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getInt(_key) ?? 0;
    } catch (_) {}
  }

  Future<bool> reportScore(int score) async {
    if (score <= state) return false;
    state = score;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key, score);
    } catch (_) {}
    return true;
  }
}

final triviaHighScoreProvider =
    NotifierProvider<TriviaHighScoreNotifier, int>(TriviaHighScoreNotifier.new);

/// Mejor puntuación en "Memoria de paradas" (ronda más alta alcanzada).
class MemoryStopsHighScoreNotifier extends Notifier<int> {
  static const String _key = 'memory_stops_highscore_v1';

  @override
  int build() {
    _load();
    return 0;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getInt(_key) ?? 0;
    } catch (_) {}
  }

  Future<bool> reportScore(int score) async {
    if (score <= state) return false;
    state = score;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key, score);
    } catch (_) {}
    return true;
  }
}

final memoryStopsHighScoreProvider =
    NotifierProvider<MemoryStopsHighScoreNotifier, int>(
  MemoryStopsHighScoreNotifier.new,
);
