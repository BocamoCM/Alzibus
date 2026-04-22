import 'dart:convert';

import '../../domain/entities/favorite_stop.dart';
import '../../domain/exceptions/app_failure.dart';
import '../../domain/ports/outbound/favorite_stop_repository.dart';
import '../../domain/ports/outbound/preferences_port.dart';
import '../../domain/shared/result.dart';

/// Adaptador de [FavoriteStopRepository] usando [PreferencesPort].
///
/// Mantiene las claves legacy para asegurar compatibilidad con
/// `favorite_stops_service.dart` durante la migración:
///   `favorite_stops`         → lista serializada como JSON.
///   `widget_favorite_stop`   → stopId actualmente asignado al widget.
class PrefsFavoriteStopRepository implements FavoriteStopRepository {
  final PreferencesPort _prefs;

  const PrefsFavoriteStopRepository(this._prefs);

  static const String keyList = 'favorite_stops';
  static const String keyWidgetStopId = 'widget_favorite_stop';

  @override
  Future<Result<List<FavoriteStop>, AppFailure>> listAll() async {
    try {
      final raw = await _prefs.readString(keyList);
      if (raw == null || raw.isEmpty) return const Ok([]);
      final list = jsonDecode(raw) as List<dynamic>;
      final parsed = list
          .map((e) => FavoriteStop.fromJson(e as Map<String, dynamic>))
          .toList();
      return Ok(parsed);
    } catch (e, s) {
      return Err(StorageReadFailure(cause: e, stackTrace: s));
    }
  }

  @override
  Future<Result<void, AppFailure>> save(List<FavoriteStop> stops) async {
    try {
      final json = jsonEncode(stops.map((s) => s.toJson()).toList());
      await _prefs.writeString(keyList, json);
      return const Ok(null);
    } catch (e, s) {
      return Err(StorageWriteFailure(cause: e, stackTrace: s));
    }
  }

  @override
  Future<Result<int?, AppFailure>> getWidgetStopId() async {
    try {
      final value = await _prefs.readInt(keyWidgetStopId);
      return Ok(value);
    } catch (e, s) {
      return Err(StorageReadFailure(cause: e, stackTrace: s));
    }
  }

  @override
  Future<Result<void, AppFailure>> setWidgetStopId(int? stopId) async {
    try {
      if (stopId == null) {
        await _prefs.remove(keyWidgetStopId);
      } else {
        await _prefs.writeInt(keyWidgetStopId, stopId);
      }
      return const Ok(null);
    } catch (e, s) {
      return Err(StorageWriteFailure(cause: e, stackTrace: s));
    }
  }
}
