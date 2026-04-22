import 'trip_record.dart';

/// Franja horaria dominante del usuario.
///
/// La capa de presentación se encarga de traducir esto a texto localizado.
enum TimeRange { morning, afternoon, evening, night }

/// Estadísticas calculadas a partir de una lista de [TripRecord].
///
/// Lógica pura de dominio — sin I/O, sin Flutter, sin dependencias externas.
class TripStats {
  final Map<String, int> lineUsage;
  final Map<String, int> stopUsage;
  final Map<int, int> hourUsage;
  final Map<int, int> weekdayUsage;
  final int totalTrips;

  const TripStats({
    required this.lineUsage,
    required this.stopUsage,
    required this.hourUsage,
    required this.weekdayUsage,
    required this.totalTrips,
  });

  factory TripStats.fromRecords(List<TripRecord> records) {
    final lineUsage = <String, int>{};
    final stopUsage = <String, int>{};
    final hourUsage = <int, int>{};
    final weekdayUsage = <int, int>{};

    for (final record in records) {
      lineUsage[record.line] = (lineUsage[record.line] ?? 0) + 1;
      stopUsage[record.stopName] = (stopUsage[record.stopName] ?? 0) + 1;
      final hour = record.timestamp.hour;
      hourUsage[hour] = (hourUsage[hour] ?? 0) + 1;
      final weekday = record.timestamp.weekday;
      weekdayUsage[weekday] = (weekdayUsage[weekday] ?? 0) + 1;
    }

    return TripStats(
      lineUsage: lineUsage,
      stopUsage: stopUsage,
      hourUsage: hourUsage,
      weekdayUsage: weekdayUsage,
      totalTrips: records.length,
    );
  }

  // ── Getters de conveniencia ──

  String? get mostUsedLine {
    if (lineUsage.isEmpty) return null;
    return lineUsage.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  String? get mostUsedStop {
    if (stopUsage.isEmpty) return null;
    return stopUsage.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  /// Devuelve la franja horaria más frecuente como [TimeRange].
  TimeRange? get peakTimeRange {
    if (hourUsage.isEmpty) return null;
    final peakHour = hourUsage.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    if (peakHour >= 6 && peakHour < 12) return TimeRange.morning;
    if (peakHour >= 12 && peakHour < 18) return TimeRange.afternoon;
    if (peakHour >= 18 && peakHour < 22) return TimeRange.evening;
    return TimeRange.night;
  }

  /// Compatibilidad legacy — devuelve emoji + texto en español.
  /// TODO(migration): eliminar cuando la UI migre a i18n con [peakTimeRange].
  String get mostFrequentTimeRange {
    if (hourUsage.isEmpty) return 'Sin datos';
    final peakHour = hourUsage.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    if (peakHour >= 6 && peakHour < 12) return '🌅 Mañana';
    if (peakHour >= 12 && peakHour < 18) return '☀️ Tarde';
    if (peakHour >= 18 && peakHour < 22) return '🌆 Noche';
    return '🌙 Madrugada';
  }

  List<MapEntry<String, int>> get topLines {
    final sorted = lineUsage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(3).toList();
  }

  List<MapEntry<String, int>> get topStops {
    final sorted = stopUsage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(3).toList();
  }

  String? get mostFrequentWeekday {
    if (weekdayUsage.isEmpty) return null;
    final peakDay = weekdayUsage.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
    const days = [
      '', 'Lunes', 'Martes', 'Miércoles', 'Jueves',
      'Viernes', 'Sábado', 'Domingo',
    ];
    return days[peakDay];
  }

  double get averageTripsPerDay {
    if (totalTrips == 0) return 0;
    return totalTrips / 7;
  }

  Map<int, int> getDayOfWeekStats() => weekdayUsage;

  // ── Helpers estáticos para cálculos de rachas e historial ──

  static int calculateCurrentStreak(List<TripRecord> records) {
    if (records.isEmpty) return 0;
    int streak = 0;
    DateTime? lastDate;
    final sorted = List<TripRecord>.from(records)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    
    for (final record in sorted) {
      final recordDate = DateTime(record.timestamp.year, record.timestamp.month, record.timestamp.day);
      if (lastDate == null) {
        if (today.difference(recordDate).inDays <= 1) {
          streak = 1;
          lastDate = recordDate;
        } else {
          break;
        }
      } else {
        final diff = lastDate.difference(recordDate).inDays;
        if (diff == 0) {
          continue;
        } else if (diff == 1) {
          streak++;
          lastDate = recordDate;
        } else {
          break;
        }
      }
    }
    return streak;
  }

  static int calculateBestStreak(List<TripRecord> records) {
    if (records.isEmpty) return 0;
    final sorted = List<TripRecord>.from(records)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    int bestStreak = 1, currentStreak = 1;
    DateTime? lastDate;
    for (final record in sorted) {
      final recordDate = DateTime(record.timestamp.year, record.timestamp.month, record.timestamp.day);
      if (lastDate == null) { lastDate = recordDate; continue; }
      final diff = recordDate.difference(lastDate).inDays;
      if (diff == 0) { continue; }
      else if (diff == 1) { currentStreak++; if (currentStreak > bestStreak) bestStreak = currentStreak; }
      else { currentStreak = 1; }
      lastDate = recordDate;
    }
    return bestStreak;
  }

  static Map<String, dynamic> calculateMonthComparison(List<TripRecord> records) {
    final now = DateTime.now();
    final thisMonthStart = DateTime(now.year, now.month, 1);
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);
    final thisMonthTrips = records.where((r) => r.timestamp.isAfter(thisMonthStart.subtract(const Duration(days: 1)))).length;
    final lastMonthTrips = records.where((r) =>
        r.timestamp.isAfter(lastMonthStart.subtract(const Duration(days: 1))) &&
        r.timestamp.isBefore(thisMonthStart)).length;
    final difference = thisMonthTrips - lastMonthTrips;
    final percentChange = lastMonthTrips > 0 ? ((difference / lastMonthTrips) * 100).round() : (thisMonthTrips > 0 ? 100 : 0);
    return {'thisMonth': thisMonthTrips, 'lastMonth': lastMonthTrips, 'difference': difference, 'percentChange': percentChange};
  }

  static List<MonthlyStats> calculateMonthlyStats(List<TripRecord> records, {int months = 6}) {
    final now = DateTime.now();
    final result = <MonthlyStats>[];
    for (int i = 0; i < months; i++) {
      final targetMonth = DateTime(now.year, now.month - i, 1);
      final nextMonth = DateTime(targetMonth.year, targetMonth.month + 1, 1);
      final monthRecords = records
          .where((r) =>
              r.timestamp.isAfter(targetMonth.subtract(const Duration(days: 1))) &&
              r.timestamp.isBefore(nextMonth))
          .toList();
      final lineUsage = <String, int>{};
      for (final record in monthRecords) {
        lineUsage[record.line] = (lineUsage[record.line] ?? 0) + 1;
      }
      result.add(MonthlyStats(
        year: targetMonth.year,
        month: targetMonth.month,
        tripCount: monthRecords.length,
        lineUsage: lineUsage,
      ));
    }
    return result.reversed.toList();
  }
}
