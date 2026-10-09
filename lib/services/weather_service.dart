import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/app_config.dart';

/// Estado del tiempo en Alzira, para que Albus avise de posibles retrasos
/// cuando llueve.
class WeatherStatus {
  final bool isRaining;
  final double precipitationMm;
  final int weatherCode;

  /// `true` si no se pudo consultar (sin red/error): Albus no dice nada.
  final bool unknown;

  const WeatherStatus({
    required this.isRaining,
    required this.precipitationMm,
    required this.weatherCode,
    this.unknown = false,
  });

  const WeatherStatus.unknown()
      : isRaining = false,
        precipitationMm = 0,
        weatherCode = 0,
        unknown = true;
}

/// Consulta el tiempo actual en Alzira con Open-Meteo (gratis, SIN API key).
///
/// Nota: Open-Meteo es gratis para uso no comercial (~10k llamadas/día). Si
/// la app escala o se considera uso comercial, conviene (a) cachear esto en
/// el backend —el tiempo es el mismo para todos— y/o (b) pasar a AEMET
/// OpenData (oficial español, gratis con key) o a un plan de Open-Meteo.
class WeatherService {
  // Centro de Alzira.
  static const double _lat = 39.15;
  static const double _lon = -0.43;

  /// Códigos WMO que consideramos "lluvia" (llovizna, lluvia, chubascos,
  /// tormenta). https://open-meteo.com/en/docs (sección weather_code).
  static const Set<int> _rainCodes = {
    51, 53, 55, 56, 57, // llovizna
    61, 63, 65, 66, 67, // lluvia
    80, 81, 82, // chubascos
    95, 96, 99, // tormenta
  };

  final http.Client _client;

  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  /// Tiempo actual en Alzira. Nunca lanza: ante error devuelve
  /// [WeatherStatus.unknown].
  Future<WeatherStatus> fetchAlzira() async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '$_lat',
      'longitude': '$_lon',
      'current': 'precipitation,weather_code',
      'timezone': 'Europe/Madrid',
    });

    try {
      final res = await _client.get(uri).timeout(AppConfig.httpTimeout);
      if (res.statusCode != 200) {
        debugPrint('[Weather] HTTP ${res.statusCode}');
        return const WeatherStatus.unknown();
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final current = (data['current'] as Map<String, dynamic>?) ?? const {};
      final precip = (current['precipitation'] as num?)?.toDouble() ?? 0;
      final code = (current['weather_code'] as num?)?.toInt() ?? 0;
      final raining = precip > 0.1 || _rainCodes.contains(code);
      return WeatherStatus(
        isRaining: raining,
        precipitationMm: precip,
        weatherCode: code,
      );
    } catch (e) {
      debugPrint('[Weather] error: $e');
      return const WeatherStatus.unknown();
    }
  }
}
