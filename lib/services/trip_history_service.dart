import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_config.dart';
import '../models/trip_record.dart';

/// Servicio de historial de viajes.
///
/// - Los viajes confirmados/guardados se almacenan en la BD del servidor.
/// - El viaje "pendiente" (hasta que el usuario confirma o rechaza) se guarda
///   localmente en SharedPreferences para poder acceder a él incluso sin red.
class TripHistoryService {
  static const String _pendingTripKey = 'pending_trip';

  final SharedPreferences _prefs;

  /// Cache local de los registros cargados desde la API.
  List<TripRecord> _records = [];

  TripHistoryService(this._prefs);

  // ─────────────────────────────────────────────────────────────
  // CARGA DESDE LA API
  // ─────────────────────────────────────────────────────────────

  /// Carga el historial del servidor. Debe llamarse al iniciar la pantalla.
  Future<void> loadFromApi(String token) async {
    try {
      final response = await ApiClient().get('/trips');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _records = data.map((e) => TripRecord.fromJson(_normalizeJson(e))).toList();
        debugPrint('[TripHistory] Cargados ${_records.length} viajes desde la API');
      }
    } catch (e) {
      debugPrint('[TripHistory] Error cargando viajes: $e');
    }
  }

  /// Normaliza las claves que vienen del servidor (snake_case → camelCase si necesario).
  Map<String, dynamic> _normalizeJson(dynamic e) {
    final map = Map<String, dynamic>.from(e);
    // La BD devuelve "stopName" y "stopId" ya en camelCase por el alias SQL.
    // Aseguramos que 'id' de BD esté disponible para borrar por ID en el servidor.
    return map;
  }

  // ─────────────────────────────────────────────────────────────
  // VIAJE PENDIENTE (local, antes de confirmar)
  // ─────────────────────────────────────────────────────────────

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

  Map<String, dynamic>? getPendingTrip() {
    final json = _prefs.getString(_pendingTripKey);
    if (json == null || json.isEmpty) return null;
    return jsonDecode(json);
  }

  /// El usuario confirmó que cogió el bus → guardar en API y descontar local si aplica.
  Future<void> confirmTrip(String token, {String paymentMethod = 'card'}) async {
    final pending = getPendingTrip();
    if (pending == null) return;
    
    // 1. Guardar en API
    await _saveToApi(
      token: token,
      line: pending['line'],
      destination: pending['destination'],
      stopName: pending['stopName'],
      stopId: pending['stopId'],
      timestamp: DateTime.parse(pending['timestamp']),
      confirmed: true,
      paymentMethod: paymentMethod,
    );

    // 2. Gestionar descuento de viaje NFC si existe tarjeta local y el pago fue con tarjeta
    final isUnlimited = _prefs.getBool('is_unlimited') ?? false;
    final storedTrips = _prefs.getInt('stored_trips') ?? 0;
    
    if (!isUnlimited && storedTrips > 0 && paymentMethod == 'card') {
      final newTrips = storedTrips - 1;
      await _prefs.setInt('stored_trips', newTrips);
      debugPrint('[TripHistory] Auto-descuento NFC (Tarjeta): $storedTrips -> $newTrips');
    }

    await _prefs.remove(_pendingTripKey);
  }

  Future<void> rejectTrip() async {
    await _prefs.remove(_pendingTripKey);
  }

  // ─────────────────────────────────────────────────────────────
  // ESCRITURA EN LA API
  // ─────────────────────────────────────────────────────────────

  Future<void> addTrip({
    required String token,
    required String line,
    required String destination,
    required String stopName,
    required int stopId,
    bool confirmed = true,
  }) async {
    await _saveToApi(
      token: token,
      line: line,
      destination: destination,
      stopName: stopName,
      stopId: stopId,
      timestamp: DateTime.now(),
      confirmed: confirmed,
      paymentMethod: 'card', 
    );
  }

  Future<void> _saveToApi({
    required String token,
    required String line,
    required String destination,
    required String stopName,
    required int stopId,
    required DateTime timestamp,
    required bool confirmed,
    String? paymentMethod,
  }) async {
    try {
      final response = await ApiClient().post(
        '/trips',
        data: {
          'line': line,
          'destination': destination,
          'stopName': stopName,
          'stopId': stopId,
          'timestamp': timestamp.toIso8601String(),
          'confirmed': confirmed,
          'paymentMethod': paymentMethod,
        },
      );

      if (response.statusCode == 201) {
        final newRecord = TripRecord.fromJson(_normalizeJson(response.data));
        _records.insert(0, newRecord);
      }
    } catch (e) {
      debugPrint('[TripHistory] Error guardando viaje: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // BORRADO
  // ─────────────────────────────────────────────────────────────

  Future<void> clearHistory(String token) async {
    try {
      await ApiClient().delete('/trips');
      _records.clear();
    } catch (e) {
      debugPrint('[TripHistory] Error borrando historial: $e');
    }
    await _prefs.remove(_pendingTripKey);
  }

  /// Elimina un viaje por su timestamp (busca el ID en _records).
  Future<void> deleteTrip(String token, DateTime timestamp) async {
    // Buscar el registro por timestamp para obtener el 'id' del servidor
    final record = _records.firstWhere(
      (r) => r.timestamp == timestamp,
      orElse: () => TripRecord(
          line: '', destination: '', stopName: '', stopId: 0, timestamp: timestamp),
    );
    final serverId = record.serverId;
    if (serverId != null) {
      try {
        await ApiClient().delete('/trips/$serverId');
      } catch (e) {
        debugPrint('[TripHistory] Error eliminando viaje: $e');
      }
    }
    _records.removeWhere((r) => r.timestamp == timestamp);
  }

  // ─────────────────────────────────────────────────────────────
  // CONSULTAS (trabajan sobre _records en memoria)
  // ─────────────────────────────────────────────────────────────

  List<TripRecord> get allRecords => List.unmodifiable(_records);

  List<TripRecord> get todayRecords {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return _records.where((r) => r.timestamp.isAfter(today)).toList();
  }

  List<TripRecord> getRecordsLastDays(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _records.where((r) => r.timestamp.isAfter(cutoff)).toList();
  }

  TripStats getStats({int? lastDays}) {
    final records = lastDays != null ? getRecordsLastDays(lastDays) : _records;
    return TripStats.fromRecords(records);
  }

  List<MonthlyStats> getMonthlyStats({int months = 6}) {
    final now = DateTime.now();
    final result = <MonthlyStats>[];
    for (int i = 0; i < months; i++) {
      final targetMonth = DateTime(now.year, now.month - i, 1);
      final nextMonth = DateTime(targetMonth.year, targetMonth.month + 1, 1);
      final monthRecords = _records
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

  int getCurrentStreak() {
    if (_records.isEmpty) return 0;
    int streak = 0;
    DateTime? lastDate;
    final sorted = List<TripRecord>.from(_records)
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

  int getBestStreak() {
    if (_records.isEmpty) return 0;
    final sorted = List<TripRecord>.from(_records)
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

  Map<String, dynamic> getMonthComparison() {
    final now = DateTime.now();
    final thisMonthStart = DateTime(now.year, now.month, 1);
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);
    final thisMonthTrips = _records.where((r) => r.timestamp.isAfter(thisMonthStart.subtract(const Duration(days: 1)))).length;
    final lastMonthTrips = _records.where((r) =>
        r.timestamp.isAfter(lastMonthStart.subtract(const Duration(days: 1))) &&
        r.timestamp.isBefore(thisMonthStart)).length;
    final difference = thisMonthTrips - lastMonthTrips;
    final percentChange = lastMonthTrips > 0 ? ((difference / lastMonthTrips) * 100).round() : (thisMonthTrips > 0 ? 100 : 0);
    return {'thisMonth': thisMonthTrips, 'lastMonth': lastMonthTrips, 'difference': difference, 'percentChange': percentChange};
  }
}
