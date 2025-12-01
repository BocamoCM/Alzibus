import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip_record.dart';

// Estadísticas mensuales
class MonthlyStats {
  final int year;
  final int month;
  final int tripCount;
  final Map<String, int> lineUsage;
  
  MonthlyStats({
    required this.year,
    required this.month,
    required this.tripCount,
    required this.lineUsage,
  });
  
  String get monthName {
    const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 
                    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return months[month - 1];
  }
  
  String get label => '$monthName ${year.toString().substring(2)}';
}

class TripHistoryService {
  static const String _storageKey = 'trip_history';
  static const String _pendingTripKey = 'pending_trip';
  
  final SharedPreferences _prefs;
  List<TripRecord> _records = [];

  TripHistoryService(this._prefs) {
    _loadRecords();
  }

  void _loadRecords() {
    final json = _prefs.getString(_storageKey);
    if (json != null && json.isNotEmpty) {
      final List<dynamic> data = jsonDecode(json);
      _records = data.map((e) => TripRecord.fromJson(e)).toList();
    }
  }

  Future<void> _saveRecords() async {
    final json = jsonEncode(_records.map((e) => e.toJson()).toList());
    await _prefs.setString(_storageKey, json);
  }

  // Guardar viaje pendiente (cuando llega el bus)
  Future<void> savePendingTrip({
    required String line,
    required String destination,
    required String stopName,
    required int stopId,
  }) async {
    final trip = {
      'line': line,
      'destination': destination,
      'stopName': stopName,
      'stopId': stopId,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await _prefs.setString(_pendingTripKey, jsonEncode(trip));
  }

  // Obtener viaje pendiente
  Map<String, dynamic>? getPendingTrip() {
    final json = _prefs.getString(_pendingTripKey);
    if (json == null || json.isEmpty) return null;
    return jsonDecode(json);
  }

  // Confirmar que cogió el bus
  Future<void> confirmTrip() async {
    final pending = getPendingTrip();
    if (pending == null) return;

    final record = TripRecord(
      line: pending['line'],
      destination: pending['destination'],
      stopName: pending['stopName'],
      stopId: pending['stopId'],
      timestamp: DateTime.parse(pending['timestamp']),
      confirmed: true,
    );

    _records.insert(0, record);
    await _saveRecords();
    await _prefs.remove(_pendingTripKey);
  }

  // Rechazar - no cogió el bus
  Future<void> rejectTrip() async {
    await _prefs.remove(_pendingTripKey);
  }

  // Auto-confirmar después de 5 minutos (asumimos que lo cogió)
  Future<void> autoConfirmIfExpired() async {
    final pending = getPendingTrip();
    if (pending == null) return;

    final timestamp = DateTime.parse(pending['timestamp']);
    if (DateTime.now().difference(timestamp).inMinutes >= 5) {
      final record = TripRecord(
        line: pending['line'],
        destination: pending['destination'],
        stopName: pending['stopName'],
        stopId: pending['stopId'],
        timestamp: timestamp,
        confirmed: false, // No confirmado, asumido
      );

      _records.insert(0, record);
      await _saveRecords();
      await _prefs.remove(_pendingTripKey);
    }
  }

  // Añadir viaje manualmente
  Future<void> addTrip({
    required String line,
    required String destination,
    required String stopName,
    required int stopId,
    bool confirmed = true,
  }) async {
    final record = TripRecord(
      line: line,
      destination: destination,
      stopName: stopName,
      stopId: stopId,
      timestamp: DateTime.now(),
      confirmed: confirmed,
    );

    _records.insert(0, record);
    await _saveRecords();
  }

  // Obtener todos los viajes
  List<TripRecord> get allRecords => List.unmodifiable(_records);

  // Obtener viajes de los últimos N días
  List<TripRecord> getRecordsLastDays(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _records.where((r) => r.timestamp.isAfter(cutoff)).toList();
  }

  // Obtener estadísticas
  TripStats getStats({int? lastDays}) {
    final records = lastDays != null 
        ? getRecordsLastDays(lastDays)
        : _records;
    return TripStats.fromRecords(records);
  }

  // Obtener viajes de hoy
  List<TripRecord> get todayRecords {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _records.where((r) => 
      r.timestamp.isAfter(today)
    ).toList();
  }

  // Limpiar historial
  Future<void> clearHistory() async {
    _records.clear();
    await _prefs.remove(_storageKey);
    await _prefs.remove(_pendingTripKey);
  }

  // Eliminar un viaje específico
  Future<void> deleteTrip(DateTime timestamp) async {
    _records.removeWhere((r) => r.timestamp == timestamp);
    await _saveRecords();
  }
  
  // Obtener estadísticas mensuales de los últimos N meses
  List<MonthlyStats> getMonthlyStats({int months = 6}) {
    final now = DateTime.now();
    final result = <MonthlyStats>[];
    
    for (int i = 0; i < months; i++) {
      final targetMonth = DateTime(now.year, now.month - i, 1);
      final nextMonth = DateTime(targetMonth.year, targetMonth.month + 1, 1);
      
      final monthRecords = _records.where((r) => 
        r.timestamp.isAfter(targetMonth.subtract(const Duration(days: 1))) &&
        r.timestamp.isBefore(nextMonth)
      ).toList();
      
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
    
    return result.reversed.toList(); // Orden cronológico
  }
  
  // Obtener racha actual (días consecutivos con viajes)
  int getCurrentStreak() {
    if (_records.isEmpty) return 0;
    
    int streak = 0;
    DateTime? lastDate;
    
    // Ordenar por fecha descendente
    final sorted = List<TripRecord>.from(_records)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    for (final record in sorted) {
      final recordDate = DateTime(record.timestamp.year, record.timestamp.month, record.timestamp.day);
      
      if (lastDate == null) {
        // Primer registro - debe ser hoy o ayer para contar
        if (today.difference(recordDate).inDays <= 1) {
          streak = 1;
          lastDate = recordDate;
        } else {
          break; // Racha rota
        }
      } else {
        final diff = lastDate.difference(recordDate).inDays;
        if (diff == 0) {
          // Mismo día, continuar
          continue;
        } else if (diff == 1) {
          // Día consecutivo
          streak++;
          lastDate = recordDate;
        } else {
          // Racha rota
          break;
        }
      }
    }
    
    return streak;
  }
  
  // Obtener mejor racha histórica
  int getBestStreak() {
    if (_records.isEmpty) return 0;
    
    final sorted = List<TripRecord>.from(_records)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    int bestStreak = 1;
    int currentStreak = 1;
    DateTime? lastDate;
    
    for (final record in sorted) {
      final recordDate = DateTime(record.timestamp.year, record.timestamp.month, record.timestamp.day);
      
      if (lastDate == null) {
        lastDate = recordDate;
        continue;
      }
      
      final diff = recordDate.difference(lastDate).inDays;
      if (diff == 0) {
        continue; // Mismo día
      } else if (diff == 1) {
        currentStreak++;
        if (currentStreak > bestStreak) {
          bestStreak = currentStreak;
        }
      } else {
        currentStreak = 1;
      }
      lastDate = recordDate;
    }
    
    return bestStreak;
  }
  
  // Comparar con el mes anterior
  Map<String, dynamic> getMonthComparison() {
    final now = DateTime.now();
    final thisMonthStart = DateTime(now.year, now.month, 1);
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);
    
    final thisMonthTrips = _records.where((r) => 
      r.timestamp.isAfter(thisMonthStart.subtract(const Duration(days: 1)))
    ).length;
    
    final lastMonthTrips = _records.where((r) => 
      r.timestamp.isAfter(lastMonthStart.subtract(const Duration(days: 1))) &&
      r.timestamp.isBefore(thisMonthStart)
    ).length;
    
    final difference = thisMonthTrips - lastMonthTrips;
    final percentChange = lastMonthTrips > 0 
        ? ((difference / lastMonthTrips) * 100).round()
        : (thisMonthTrips > 0 ? 100 : 0);
    
    return {
      'thisMonth': thisMonthTrips,
      'lastMonth': lastMonthTrips,
      'difference': difference,
      'percentChange': percentChange,
    };
  }
}
