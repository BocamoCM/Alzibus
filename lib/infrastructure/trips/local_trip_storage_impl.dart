import 'dart:convert';
import '../../domain/exceptions/app_failure.dart';
import '../../domain/ports/outbound/local_trip_storage.dart';
import '../../domain/ports/outbound/preferences_port.dart';
import '../../domain/shared/result.dart';

class LocalTripStorageImpl implements LocalTripStorage {
  static const String _pendingTripKey = 'pending_trip';
  final PreferencesPort _prefs;

  const LocalTripStorageImpl(this._prefs);

  @override
  Future<Result<void, AppFailure>> savePendingTrip(Map<String, dynamic> tripData) async {
    try {
      final json = jsonEncode(tripData);
      await _prefs.writeString(_pendingTripKey, json);
      return const Ok(null);
    } catch (e, s) {
      return Err(StorageWriteFailure(cause: e, stackTrace: s));
    }
  }

  @override
  Future<Result<Map<String, dynamic>?, AppFailure>> getPendingTrip() async {
    try {
      final json = await _prefs.readString(_pendingTripKey);
      if (json == null || json.isEmpty) return const Ok(null);
      return Ok(jsonDecode(json));
    } catch (e, s) {
      return Err(StorageReadFailure(cause: e, stackTrace: s));
    }
  }

  @override
  Future<Result<void, AppFailure>> clearPendingTrip() async {
    try {
      await _prefs.remove(_pendingTripKey);
      return const Ok(null);
    } catch (e, s) {
      return Err(StorageWriteFailure(cause: e, stackTrace: s));
    }
  }
}
