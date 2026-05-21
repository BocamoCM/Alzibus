import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/albus_skin.dart';
import '../../services/game_service.dart';

/// Monedas acumuladas por el jugador en los mini-juegos.
///
/// **Modelo offline-first con sync al servidor**:
///   1. Al arrancar: lee local (rápido, instantáneo).
///   2. En background, intenta GET /game/state.
///      - Si servidor > local → adopta el del servidor (gana el más alto).
///      - Si local > servidor → POST /game/coins/sync para subir el local.
///   3. En cada `add` / `spend`: actualiza local + POST debounced (1.5s).
///
/// Esto es resistente a:
///   - Sin red: las operaciones funcionan locales, el sync se reintenta.
///   - Reinstalar la app: el primer GET trae las monedas del servidor.
///   - Multi-dispositivo: el más alto gana en cada sync (tradeoff: si
///     juegas en 2 sin red, al sincronizar te quedas con el máximo, no
///     con la suma. Aceptable para monedas decorativas).
class GameCurrencyNotifier extends Notifier<int> {
  static const String _key = 'game_coins_v1';
  /// Debounce del POST tras cada add/spend. Evita martillear el server
  /// cuando el usuario hace cosas en cadena (10 puntos seguidos en un
  /// minijuego = 1 sync al final, no 10).
  static const Duration _syncDebounce = Duration(seconds: 2);

  final Completer<void> _loadCompleter = Completer<void>();
  Timer? _syncDebounceTimer;

  @override
  int build() {
    _load();
    // Cancelar el timer cuando el provider se invalide.
    ref.onDispose(() => _syncDebounceTimer?.cancel());
    return 0;
  }

  Future<void> _load() async {
    // 1) Local (rápido, instantáneo)
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getInt(_key) ?? 0;
    } catch (_) {}
    if (!_loadCompleter.isCompleted) _loadCompleter.complete();

    // 2) Async: reconciliar con servidor. Errores silenciosos.
    unawaited(_reconcileWithServer());
  }

  Future<void> _reconcileWithServer() async {
    try {
      final serverState = await GameService().getState();
      final localCoins = state;

      if (serverState.coins > localCoins) {
        // El servidor tiene más → adoptar (ej. usuario en otro móvil).
        state = serverState.coins;
        await _persistLocal(serverState.coins);
      } else if (localCoins > serverState.coins) {
        // Local tiene más → subir al servidor.
        final updated = await GameService().syncCoins(localCoins);
        if (updated != localCoins) {
          // Posible carrera (servidor cambió mientras tanto). Adoptar
          // el devuelto, que es el max según el servicio.
          state = updated;
          await _persistLocal(updated);
        }
      }
    } catch (e) {
      // Sin red o error temporal — ignorar, reintenta en siguiente sync.
      if (kDebugMode) debugPrint('[Coins] reconcile error (no bloqueante): $e');
    }
  }

  Future<void> _persistLocal(int value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key, value);
    } catch (_) {}
  }

  /// Suma monedas al saldo local + dispara sync debounced al servidor.
  Future<void> add(int amount) async {
    await _loadCompleter.future;
    state = state + amount;
    await _persistLocal(state);
    _scheduleSync();
  }

  /// Resta monedas si hay suficientes (en LOCAL). Devuelve `true` si la
  /// operación se pudo completar, `false` si el saldo era insuficiente.
  /// Dispara sync debounced al servidor.
  Future<bool> spend(int amount) async {
    await _loadCompleter.future;
    if (state < amount) return false;
    state = state - amount;
    await _persistLocal(state);
    _scheduleSync();
    return true;
  }

  /// Debounce del POST al servidor: si se llama varias veces seguidas,
  /// solo se hace UNA petición tras 2s sin actividad.
  void _scheduleSync() {
    _syncDebounceTimer?.cancel();
    _syncDebounceTimer = Timer(_syncDebounce, () {
      unawaited(_pushSyncNow());
    });
  }

  Future<void> _pushSyncNow() async {
    try {
      final updated = await GameService().syncCoins(state);
      if (updated != state) {
        state = updated;
        await _persistLocal(updated);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Coins] push sync error (reintenta luego): $e');
    }
  }
}

final gameCurrencyProvider =
    NotifierProvider<GameCurrencyNotifier, int>(GameCurrencyNotifier.new);

// ─── HIGH SCORES (sin cambios de sync por ahora, solo local) ──────────

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

// ─── SKINS — set de poseídos + equipado, AHORA con sync al servidor ───

class OwnedSkinsNotifier extends Notifier<Set<String>> {
  static const String _key = 'albus_owned_skins_v1';
  static const Duration _syncDebounce = Duration(seconds: 2);

  final Completer<void> _loadCompleter = Completer<void>();
  Timer? _syncDebounceTimer;

  @override
  Set<String> build() {
    _load();
    ref.onDispose(() => _syncDebounceTimer?.cancel());
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

    // Reconciliar con servidor en background.
    unawaited(_reconcileWithServer());
  }

  Future<void> _reconcileWithServer() async {
    try {
      final serverState = await GameService().getState();
      final union = {...state, ...serverState.ownedSkins, 'default'};
      if (union.length != state.length) {
        state = union;
        await _persistLocal();
      }
      // Si tenemos algún skin que el server no tiene, lo subimos.
      if (state.length > serverState.ownedSkins.length) {
        await GameService().syncOwnedSkins(state.toList());
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Skins] reconcile error: $e');
    }
  }

  Future<void> _persistLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, state.join(','));
    } catch (_) {}
  }

  Future<void> unlock(String skinId) async {
    await _loadCompleter.future;
    state = {...state, skinId};
    await _persistLocal();
    _scheduleSync();
  }

  bool owns(String skinId) => state.contains(skinId);

  void _scheduleSync() {
    _syncDebounceTimer?.cancel();
    _syncDebounceTimer = Timer(_syncDebounce, () {
      unawaited(_pushSyncNow());
    });
  }

  Future<void> _pushSyncNow() async {
    try {
      final updated = await GameService().syncOwnedSkins(state.toList());
      final union = {...updated, 'default'};
      if (union.length != state.length) {
        state = union;
        await _persistLocal();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Skins] push sync error: $e');
    }
  }
}

final ownedSkinsProvider =
    NotifierProvider<OwnedSkinsNotifier, Set<String>>(OwnedSkinsNotifier.new);

/// ID del skin actualmente equipado. Solo local (preferencia visual).
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

final equippedAlbusSkinProvider = Provider<AlbusSkin>((ref) {
  final equippedId = ref.watch(equippedSkinProvider);
  return AlbusSkin.findById(equippedId);
});
