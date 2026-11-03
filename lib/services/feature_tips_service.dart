import 'package:shared_preferences/shared_preferences.dart';

/// Consejos para descubrir funciones de Alzitrans ("¿te aburres? juega",
/// "¿algún problema? abre un ticket", "has ahorrado X de CO₂"…).
enum FeatureTip { games, support, co2, alerts, planner, shop, share }

/// Decide qué consejo enseñar y cuándo, sin agobiar:
/// - como mucho uno cada [minInterval];
/// - van rotando y no se repite ninguno de los últimos [_recentToAvoid];
/// - el del CO₂ solo si el usuario ya tiene viajes;
/// - el usuario puede desactivarlos para siempre.
class FeatureTipsService {
  FeatureTipsService(this._prefs);

  final SharedPreferences _prefs;

  static const Duration minInterval = Duration(hours: 6);
  static const int _recentToAvoid = 3;

  static const _kLastShown = 'feature_tip_last_shown';
  static const _kRecent = 'feature_tip_recent';
  static const _kDisabled = 'feature_tips_disabled';

  bool get disabled => _prefs.getBool(_kDisabled) ?? false;

  /// Consejo que toca ahora, o null si no hay que enseñar ninguno.
  FeatureTip? pick({required DateTime now, int? totalTrips}) {
    if (disabled) return null;
    final last = _prefs.getInt(_kLastShown);
    if (last != null && now.difference(DateTime.fromMillisecondsSinceEpoch(last)) < minInterval) return null;

    final recent = (_prefs.getStringList(_kRecent) ?? const []).toList();
    final candidates = FeatureTip.values.where((t) => t != FeatureTip.co2 || (totalTrips ?? 0) > 0).toList();
    if (candidates.isEmpty) return null;

    // Siguiente en orden tras el último enseñado, saltando los recientes.
    final lastTip = recent.isEmpty ? null : FeatureTip.values.where((t) => t.name == recent.last).firstOrNull;
    var start = lastTip == null ? 0 : (candidates.indexOf(lastTip) + 1) % candidates.length;
    if (start < 0) start = 0;
    for (var i = 0; i < candidates.length; i++) {
      final tip = candidates[(start + i) % candidates.length];
      if (!recent.reversed.take(_recentToAvoid).contains(tip.name)) return tip;
    }
    return candidates[start];
  }

  /// Apunta que se ha enseñado [tip] (para el intervalo y la rotación).
  Future<void> markShown(FeatureTip tip, DateTime now) async {
    final recent = (_prefs.getStringList(_kRecent) ?? const []).toList()..add(tip.name);
    while (recent.length > FeatureTip.values.length) {
      recent.removeAt(0);
    }
    await _prefs.setStringList(_kRecent, recent);
    await _prefs.setInt(_kLastShown, now.millisecondsSinceEpoch);
  }

  Future<void> disableForever() => _prefs.setBool(_kDisabled, true);
}
