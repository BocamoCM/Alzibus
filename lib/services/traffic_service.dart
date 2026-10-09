import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';

/// Estado del tráfico cerca de Alzira, para que Albus avise de posibles
/// retrasos por atascos/incidencias.
class TrafficStatus {
  /// Nº de incidencias detectadas en el área (0 = circulación normal).
  final int incidentCount;

  /// `true` si no se pudo consultar (sin key en el backend, sin red, error) —
  /// en ese caso Albus simplemente no dice nada de tráfico.
  final bool unknown;

  const TrafficStatus({required this.incidentCount, this.unknown = false});

  const TrafficStatus.unknown()
      : incidentCount = 0,
        unknown = true;

  bool get hasIncidents => !unknown && incidentCount > 0;
}

/// Consulta el estado del tráfico a NUESTRO backend (`/traffic`), que a su vez
/// consulta TomTom una vez por intervalo y cachea el resultado para toda la
/// app. Ventajas frente a llamar a TomTom desde el móvil: el gasto de cuota no
/// depende del nº de usuarios y la key de TomTom nunca viaja en el APK.
class TrafficService {
  /// Estado del tráfico en Alzira. Nunca lanza: ante cualquier problema
  /// devuelve [TrafficStatus.unknown].
  Future<TrafficStatus> fetchAlzira() async {
    try {
      final res = await ApiClient().get('/traffic');
      if (res.statusCode != 200 || res.data is! Map) {
        return const TrafficStatus.unknown();
      }
      final data = Map<String, dynamic>.from(res.data as Map);
      if (data['unknown'] == true) return const TrafficStatus.unknown();
      final count = (data['incidentCount'] as num?)?.toInt() ?? 0;
      return TrafficStatus(incidentCount: count);
    } catch (e) {
      debugPrint('[Traffic] error: $e');
      return const TrafficStatus.unknown();
    }
  }
}
