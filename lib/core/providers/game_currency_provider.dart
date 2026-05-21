import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/albus_skin.dart';

/// Monedas acumuladas por el jugador en los mini-juegos. Persistido en
/// SharedPreferences.
///
/// **Importante**: el `build()` de Riverpod NO puede ser async, así que el
/// estado inicial es 0 mientras `_load()` resuelve. Para evitar la race
/// condition (terminar una partida ANTES de que load termine = monedas
/// machacadas al cargar), usamos un Completer que `add()` espera siempre.
class GameCurrencyNotifier extends Notifier<int> {
  static const String _key = 'game_coins_v1';

  /// Se completa cuando el `_load()` inicial termina. Cualquier modificación
  /// del estado vía `add()` espera a este Future ANTES de leer/escribir,
  /// para no machacar el valor persistido si el usuario interactúa muy rápido.
  final Completer<void> _loadCompleter = Completer<void>();

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
    if (!_loadCompleter.isCompleted) _loadCompleter.complete();
  }

  /// Suma monedas al saldo persistente. Si la primera carga aún no terminó,
  /// espera a que termine antes de modificar (evita race condition).
  Future<void> add(int amount) async {
    await _loadCompleter.future;
    state = state + amount;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key, state);
    } catch (_) {}
  }

  /// Resta monedas si hay suficientes. Devuelve `true` si la operación se
  /// pudo completar, `false` si el saldo era insuficiente.
  Future<bool> spend(int amount) async {
    await _loadCompleter.future;
    if (state < amount) return false;
    state = state - amount;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key, state);
    } catch (_) {}
    return true;
  }
}

final gameCurrencyProvider =
    NotifierProvider<GameCurrencyNotifier, int>(GameCurrencyNotifier.new);

// ─── HIGH SCORES de juegos (sin cambios respecto a antes, ahora con
//     mismo patrón de loadCompleter por consistencia) ──────────────────

class CatchTheBusHighScoreNotifier extends Notifier<int> {
  static const String _key = 'catch_the_bus_highscore_v1';
  final Completer<void> _loadCompleter = Completer<void>();

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
    if (!_loadCompleter.isCompleted) _loadCompleter.complete();
  }

  Future<bool> reportScore(int score) async {
    await _loadCompleter.future;
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

class TriviaHighScoreNotifier extends Notifier<int> {
  static const String _key = 'trivia_alzira_highscore_v1';
  final Completer<void> _loadCompleter = Completer<void>();

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
    if (!_loadCompleter.isCompleted) _loadCompleter.complete();
  }

  Future<bool> reportScore(int score) async {
    await _loadCompleter.future;
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

class MemoryStopsHighScoreNotifier extends Notifier<int> {
  static const String _key = 'memory_stops_highscore_v1';
  final Completer<void> _loadCompleter = Completer<void>();

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
    if (!_loadCompleter.isCompleted) _loadCompleter.complete();
  }

  Future<bool> reportScore(int score) async {
    await _loadCompleter.future;
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

// ─── SKINS de Albus: cuáles tiene el usuario y cuál tiene equipado ────

/// Set de IDs de skins desbloqueados (incluye 'default' siempre).
/// Persistido en SharedPreferences como CSV.
class OwnedSkinsNotifier extends Notifier<Set<String>> {
  static const String _key = 'albus_owned_skins_v1';
  final Completer<void> _loadCompleter = Completer<void>();

  @override
  Set<String> build() {
    _load();
    // De salida, garantizamos que 'default' siempre está poseído.
    return {'default'};
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        state = {...raw.split(','), 'default'};
      }
    } catch (_) {}
    if (!_loadCompleter.isCompleted) _loadCompleter.complete();
  }

  Future<void> unlock(String skinId) async {
    await _loadCompleter.future;
    state = {...state, skinId};
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, state.join(','));
    } catch (_) {}
  }

  bool owns(String skinId) => state.contains(skinId);
}

final ownedSkinsProvider =
    NotifierProvider<OwnedSkinsNotifier, Set<String>>(OwnedSkinsNotifier.new);

/// ID del skin actualmente equipado. Por defecto 'default'.
class EquippedSkinNotifier extends Notifier<String> {
  static const String _key = 'albus_equipped_skin_v1';
  final Completer<void> _loadCompleter = Completer<void>();

  @override
  String build() {
    _load();
    return 'default';
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getString(_key) ?? 'default';
    } catch (_) {}
    if (!_loadCompleter.isCompleted) _loadCompleter.complete();
  }

  Future<void> equip(String skinId) async {
    await _loadCompleter.future;
    state = skinId;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, skinId);
    } catch (_) {}
  }
}

final equippedSkinProvider =
    NotifierProvider<EquippedSkinNotifier, String>(EquippedSkinNotifier.new);

/// Provider derivado que devuelve el AlbusSkin equipado completo (con todos
/// sus campos). Útil para el widget AlbusMascot.
final equippedAlbusSkinProvider = Provider<AlbusSkin>((ref) {
  final equippedId = ref.watch(equippedSkinProvider);
  return AlbusSkin.findById(equippedId);
});
