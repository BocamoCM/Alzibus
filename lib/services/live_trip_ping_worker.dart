import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/api_client.dart';

/// Keys de SharedPreferences usadas para coordinar entre la UI
/// (ShareTripScreen) y el background worker.
class LiveTripPingKeys {
  /// ID del viaje compartido actualmente activo. Null cuando no hay viaje.
  /// La UI lo escribe al iniciar y lo borra al terminar.
  static const String activeTripId = 'active_share_trip_id';

  /// Timestamp del último ping exitoso (ms desde epoch). Permite a la UI
  /// saber si el background worker está pingueando OK.
  static const String lastPingAtMs = 'active_share_trip_last_ping_ms';

  /// Si está a true, el worker NO pingueará — útil mientras la UI está
  /// activa y haciendo sus propios pings (evita duplicados).
  static const String suspendedByUi = 'active_share_trip_suspended_by_ui';
}

/// Hace UN ping si hay un viaje compartido activo en SharedPreferences.
///
/// Diseñado para llamarse desde el Timer.periodic existente del
/// ForegroundService (cada 30s). No usa Riverpod ni context — funciona
/// puramente con SharedPreferences + ApiClient (que ya lee el JWT de
/// SharedPreferences).
///
/// Si el backend responde 404 o 410, asumimos que el viaje ya no está
/// activo y limpiamos `activeTripId` para que paremos de intentar.
@pragma('vm:entry-point')
Future<void> liveTripPingTick(SharedPreferences prefs) async {
  // Re-leer keys frescas — en el isolate del background service, las
  // escrituras desde el isolate principal solo aparecen tras reload().
  await prefs.reload();

  final tripId = prefs.getString(LiveTripPingKeys.activeTripId);
  if (tripId == null || tripId.isEmpty) return;

  // Si la UI está activa pingueando, no duplicamos.
  final suspended = prefs.getBool(LiveTripPingKeys.suspendedByUi) ?? false;
  if (suspended) {
    if (kDebugMode) {
      debugPrint('[LiveTripPing] suspended by UI; skip background tick');
    }
    return;
  }

  // GPS con timeout corto — si no podemos pillar posición en 8s,
  // mejor saltar este tick y reintentar al siguiente.
  Position pos;
  try {
    pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 8),
      ),
    );
  } catch (e) {
    debugPrint('[LiveTripPing] GPS fallido: $e');
    return;
  }

  try {
    final res = await ApiClient().dio.post(
      '/live-trips/$tripId/ping',
      data: {
        'lat': pos.latitude,
        'lng': pos.longitude,
        if (pos.speed >= 0) 'speedMps': pos.speed,
        'accuracyM': pos.accuracy,
      },
    );

    // 404 / 410 / 400 = el viaje ya no está activo (terminado o expirado).
    // Limpiamos el key para no seguir intentando.
    if (res.statusCode == 404 || res.statusCode == 410 || res.statusCode == 400) {
      await prefs.remove(LiveTripPingKeys.activeTripId);
      debugPrint('[LiveTripPing] Viaje ya no activo (${res.statusCode}); limpio key');
      return;
    }

    if (res.statusCode == 200 || res.statusCode == 201) {
      await prefs.setInt(
        LiveTripPingKeys.lastPingAtMs,
        DateTime.now().millisecondsSinceEpoch,
      );
    }
  } catch (e) {
    // Error de red, lo ignoramos — reintentamos en el siguiente tick.
    debugPrint('[LiveTripPing] Error de red en ping: $e');
  }
}
