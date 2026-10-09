import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/app_config.dart';

/// Estado del tráfico cerca de Alzira, para que Albus avise de posibles
/// retrasos por atascos/incidencias.
class TrafficStatus {
  /// Nº de incidencias detectadas en el área (0 = circulación normal).
  final int incidentCount;

  /// `true` si no se pudo consultar (sin key, sin red, error) — en ese caso
  /// Albus simplemente no dice nada de tráfico.
  final bool unknown;

  const TrafficStatus({required this.incidentCount, this.unknown = false});

  const TrafficStatus.unknown()
      : incidentCount = 0,
        unknown = true;

  bool get hasIncidents => !unknown && incidentCount > 0;
}

/// Consulta incidencias de tráfico en tiempo real con la API de TomTom
/// (Traffic Incidents v5). Gratis en el plan Freemium.
///
/// Uso previsto: al planificar un viaje o al abrir la app, llamar a
/// [fetchAround] con el centro de Alzira; si [TrafficStatus.hasIncidents],
/// Albus avisa de que puede haber variaciones por el tráfico.
///
/// NO se llama a la red si [AppConfig.trafficEnabled] es false (sin key).
class TrafficService {
  /// Caja aproximada de Alzira (min/max lon y lat). Cubre el casco urbano y
  /// los accesos por donde circulan las líneas.
  static const double _minLon = -0.46;
  static const double _minLat = 39.13;
  static const double _maxLon = -0.41;
  static const double _maxLat = 39.17;

  final http.Client _client;

  TrafficService({http.Client? client}) : _client = client ?? http.Client();

  /// Devuelve el estado del tráfico en el área de Alzira. Nunca lanza: ante
  /// cualquier problema devuelve [TrafficStatus.unknown].
  Future<TrafficStatus> fetchAlzira() =>
      _fetch(_minLon, _minLat, _maxLon, _maxLat);

  Future<TrafficStatus> _fetch(
      double minLon, double minLat, double maxLon, double maxLat) async {
    if (!AppConfig.trafficEnabled) return const TrafficStatus.unknown();

    final uri =
        Uri.https('api.tomtom.com', '/traffic/services/5/incidentDetails', {
      'key': AppConfig.tomtomApiKey,
      'bbox': '$minLon,$minLat,$maxLon,$maxLat',
      // Pedimos solo lo mínimo: el tipo de incidencia por icono.
      'fields': '{incidents{properties{iconCategory}}}',
      'language': 'es-ES',
    });

    try {
      final res = await _client.get(uri).timeout(AppConfig.httpTimeout);
      if (res.statusCode != 200) {
        debugPrint('[Traffic] HTTP ${res.statusCode}');
        return const TrafficStatus.unknown();
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final incidents = (data['incidents'] as List?) ?? const [];
      return TrafficStatus(incidentCount: incidents.length);
    } catch (e) {
      debugPrint('[Traffic] error: $e');
      return const TrafficStatus.unknown();
    }
  }
}
