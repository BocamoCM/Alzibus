import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class GamificationService extends ChangeNotifier {
  static final GamificationService _instance = GamificationService._internal();
  factory GamificationService() => _instance;
  GamificationService._internal();

  static const String _joinCountKey = 'gamification_join_count';
  static const String _badgesKey = 'gamification_badges';
  static const String _joinTimesKey = 'gamification_last_join_times';

  int _joinCount = 0;
  Set<String> _badges = {};
  Map<String, int> _lastJoinTimes = {};

  int get joinCount => _joinCount;
  List<String> get badges => _badges.toList();

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _joinCount = prefs.getInt(_joinCountKey) ?? 0;
    _badges = (prefs.getStringList(_badgesKey) ?? []).toSet();
    
    final joinTimesJson = prefs.getString(_joinTimesKey);
    if (joinTimesJson != null) {
      try {
        _lastJoinTimes = Map<String, int>.from(jsonDecode(joinTimesJson));
      } catch (_) {
        _lastJoinTimes = {};
      }
    }
    
    notifyListeners();
  }

  bool canJoinLine(String line) {
    if (!_lastJoinTimes.containsKey(line)) return true;
    final lastJoin = _lastJoinTimes[line]!;
    final now = DateTime.now().millisecondsSinceEpoch;
    // 30 minutos = 30 * 60 * 1000 ms
    return (now - lastJoin) > (30 * 60 * 1000);
  }

  /// Registra que el usuario se ha unido a un bus.
  /// personasEnBus: número de personas que se han unido a ese bus (mínimo 1).
  Future<void> recordBusJoin({required String line, int personasEnBus = 1}) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Actualizar tiempo del último viaje para esta línea
    _lastJoinTimes[line] = DateTime.now().millisecondsSinceEpoch;
    await prefs.setString(_joinTimesKey, jsonEncode(_lastJoinTimes));
    
    _joinCount += 1;
    await prefs.setInt(_joinCountKey, _joinCount);
    
    _checkBadges();
    await _saveBadges();
    notifyListeners();
  }

  void _checkBadges() {
    if (_joinCount >= 1 && !_badges.contains('primer_viaje')) {
      _badges.add('primer_viaje');
    }
    if (_joinCount >= 5 && !_badges.contains('viajero_frecuente')) {
      _badges.add('viajero_frecuente');
    }
    if (_joinCount >= 20 && !_badges.contains('viajero_experto')) {
      _badges.add('viajero_experto');
    }
  }

  Future<void> _saveBadges() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_badgesKey, _badges.toList());
  }

  String getBadgeTitle(String badgeId) {
    switch (badgeId) {
      case 'primer_viaje': return '🌱 Primer Viaje';
      case 'viajero_frecuente': return '🚌 Viajero Frecuente';
      case 'viajero_experto': return '🎖️ Maestro Alzitrans';
      default: return '🏅 Logro';
    }
  }
}
