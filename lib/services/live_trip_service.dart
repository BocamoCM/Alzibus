import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../models/live_trip.dart';

/// Cliente del API `/api/live-trips/*` — feature "Compartir mi viaje".
///
/// Todos los métodos lanzan `LiveTripException` si la respuesta no es 2xx,
/// para que la UI sepa diferenciar errores de "no hay viaje activo".
class LiveTripService {
  /// Inicia un viaje compartido. Devuelve el `LiveTrip` creado con su
  /// `shareUrl` listo para pasar al share sheet del sistema.
  Future<LiveTrip> start({
    String? line,
    int? originStopId,
    String? originStopName,
    int? destinationStopId,
    String? destinationStopName,
    double? destinationLat,
    double? destinationLng,
  }) async {
    final res = await ApiClient().dio.post(
      '/api/live-trips',
      data: {
        if (line != null) 'line': line,
        if (originStopId != null) 'originStopId': originStopId,
        if (originStopName != null) 'originStopName': originStopName,
        if (destinationStopId != null) 'destinationStopId': destinationStopId,
        if (destinationStopName != null) 'destinationStopName': destinationStopName,
        if (destinationLat != null) 'destinationLat': destinationLat,
        if (destinationLng != null) 'destinationLng': destinationLng,
      },
    );
    if (res.statusCode == null || res.statusCode! >= 400) {
      throw LiveTripException(
        'No se pudo iniciar el viaje (${res.statusCode}): ${res.data}',
      );
    }
    return LiveTrip.fromJson(_asMap(res.data));
  }

  /// Manda un ping con la posición GPS actual. Llamar cada ~30s mientras el
  /// usuario se mueve. Si el viaje ya estaba `ended`/`expired`, lanza
  /// excepción — el llamador debe parar el timer.
  Future<LiveTrip> ping({
    required String tripId,
    required double lat,
    required double lng,
    double? speedMps,
    double? accuracyM,
  }) async {
    final res = await ApiClient().dio.post(
      '/api/live-trips/$tripId/ping',
      data: {
        'lat': lat,
        'lng': lng,
        if (speedMps != null) 'speedMps': speedMps,
        if (accuracyM != null) 'accuracyM': accuracyM,
      },
    );
    if (res.statusCode == null || res.statusCode! >= 400) {
      throw LiveTripException(
        'Ping rechazado (${res.statusCode}): ${res.data}',
      );
    }
    return LiveTrip.fromJson(_asMap(res.data));
  }

  /// Marca el viaje como terminado. Idempotente desde la UI: si el
  /// servidor responde 404, asumimos que ya estaba cerrado y devolvemos null.
  Future<LiveTrip?> end(String tripId) async {
    try {
      final res = await ApiClient().dio.post('/api/live-trips/$tripId/end');
      if (res.statusCode == 404) return null;
      if (res.statusCode == null || res.statusCode! >= 400) {
        throw LiveTripException(
          'No se pudo terminar (${res.statusCode}): ${res.data}',
        );
      }
      return LiveTrip.fromJson(_asMap(res.data));
    } catch (e) {
      debugPrint('[LiveTripService] end() error: $e');
      rethrow;
    }
  }

  /// Devuelve el viaje activo del usuario actual, o null si no tiene
  /// ninguno. Útil al abrir la pantalla de compartir para recuperar estado.
  Future<LiveTrip?> getActive() async {
    final res = await ApiClient().dio.get('/api/live-trips/active');
    if (res.statusCode != 200) return null;
    final body = _asMap(res.data);
    final trip = body['trip'];
    if (trip == null) return null;
    return LiveTrip.fromJson(_asMap(trip));
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw LiveTripException('Respuesta inesperada del servidor: $data');
  }
}

class LiveTripException implements Exception {
  final String message;
  LiveTripException(this.message);
  @override
  String toString() => 'LiveTripException: $message';
}
