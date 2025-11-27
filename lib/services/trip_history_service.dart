import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip_record.dart';

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
}
