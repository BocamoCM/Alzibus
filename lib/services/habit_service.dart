import 'package:shared_preferences/shared_preferences.dart';

import '../models/travel_habit.dart';
import '../models/trip_record.dart';
import 'notification_service.dart';

/// Aprende los trayectos habituales del usuario a partir del historial y
/// gestiona los avisos proactivos de Albus ("tu bus de siempre sale pronto").
///
/// Un hábito = mismo (parada + línea + día de la semana) repetido en al menos
/// [minOccurrences] días distintos. La hora típica es la mediana de las horas
/// a las que cogió ese trayecto.
class HabitService {
  /// Días distintos mínimos para considerar algo un hábito.
  static const int minOccurrences = 3;

  /// Minutos de antelación con los que avisamos antes de la hora típica.
  static const int reminderLeadMin = 10;

  /// Máximo de hábitos que mostramos/programamos (evita saturar).
  static const int maxHabits = 5;

  static const String _enabledKey = 'enabled_habits';

  final SharedPreferences _prefs;
  final NotificationService _notif;

  HabitService(this._prefs, this._notif);

  // ─────────────────────────────────────────────────────────────
  // DETECCIÓN (lógica pura sobre el historial)
  // ─────────────────────────────────────────────────────────────

  List<TravelHabit> detectHabits(List<TripRecord> records) {
    // group key -> datos agregados del grupo
    final groups = <String, _Agg>{};

    for (final r in records) {
      final key = '${r.stopId}|${r.line}|${r.timestamp.weekday}';
      final agg = groups.putIfAbsent(key, () => _Agg(r));
      agg.minutesOfDay.add(r.timestamp.hour * 60 + r.timestamp.minute);
      agg.dates.add(_dateKey(r.timestamp));
    }

    final habits = <TravelHabit>[];
    for (final agg in groups.values) {
      final occurrences = agg.dates.length; // días distintos
      if (occurrences < minOccurrences) continue;

      final median = _median(agg.minutesOfDay);
      habits.add(TravelHabit(
        line: agg.sample.line,
        stopName: agg.sample.stopName,
        stopId: agg.sample.stopId,
        weekday: agg.sample.timestamp.weekday,
        hour: median ~/ 60,
        minute: median % 60,
        occurrences: occurrences,
      ));
    }

    habits.sort((a, b) {
      final byOcc = b.occurrences.compareTo(a.occurrences);
      if (byOcc != 0) return byOcc;
      return a.weekday.compareTo(b.weekday);
    });

    return habits.take(maxHabits).toList();
  }

  // ─────────────────────────────────────────────────────────────
  // ESTADO (qué hábitos tienen aviso activado)
  // ─────────────────────────────────────────────────────────────

  Set<String> get _enabledIds =>
      _prefs.getStringList(_enabledKey)?.toSet() ?? <String>{};

  bool isEnabled(TravelHabit habit) => _enabledIds.contains(habit.id);

  Future<void> setEnabled(TravelHabit habit, bool enabled) async {
    final ids = _enabledIds;
    if (enabled) {
      ids.add(habit.id);
      await _scheduleReminder(habit);
    } else {
      ids.remove(habit.id);
      await _notif.cancelHabitReminder(habit.notificationId);
    }
    await _prefs.setStringList(_enabledKey, ids.toList());
  }

  /// Reprograma todos los avisos de los hábitos activados que siguen
  /// existiendo. Llamar al abrir la app (los alarms se pierden al reiniciar
  /// el móvil). Los hábitos activados que ya no se detectan se limpian.
  Future<void> rescheduleEnabled(List<TravelHabit> habits) async {
    final byId = {for (final h in habits) h.id: h};
    final ids = _enabledIds;
    final stillValid = <String>{};
    for (final id in ids) {
      final habit = byId[id];
      if (habit == null) continue; // ya no es hábito → se descarta
      await _scheduleReminder(habit);
      stillValid.add(id);
    }
    if (stillValid.length != ids.length) {
      await _prefs.setStringList(_enabledKey, stillValid.toList());
    }
  }

  Future<void> _scheduleReminder(TravelHabit habit) async {
    // Avisamos [reminderLeadMin] antes de la hora típica.
    var total = habit.minuteOfDay - reminderLeadMin;
    if (total < 0) total = 0;
    await _notif.scheduleHabitReminder(
      id: habit.notificationId,
      weekday: habit.weekday,
      hour: total ~/ 60,
      minute: total % 60,
      title: '🚌 Tu bus de siempre',
      body: '${habit.line} desde ${habit.stopName} suele salir sobre las '
          '${_hhmm(habit.hour, habit.minute)}. ¿Vas hoy?',
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  int _median(List<int> values) {
    final sorted = List<int>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return ((sorted[mid - 1] + sorted[mid]) / 2).round();
  }

  String _hhmm(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

class _Agg {
  final TripRecord sample;
  final List<int> minutesOfDay = [];
  final Set<String> dates = {};
  _Agg(this.sample);
}
