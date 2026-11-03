import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:html/parser.dart' as html_parser;
import '../core/network/api_client.dart';
import '../constants/app_config.dart';

class BusArrival {
  final String line;
  final String destination;
  final String time;

  BusArrival({
    required this.line,
    required this.destination,
    required this.time,
  });
}

class _CachedArrivals {
  final DateTime at;
  final List<BusArrival> arrivals;
  _CachedArrivals(this.at, this.arrivals);
}

class BusTimesService {
  static const String baseUrl = 'https://servidor.autocareslozano.es/Alzira/webtiempos/PopupPoste.aspx';

  // Últimos tiempos de cada parada (los rellena también el escaneo inicial),
  // para que la ficha de una parada se abra con datos al momento.
  static final Map<int, _CachedArrivals> _cache = {};

  /// Tiempos guardados de la parada si tienen menos de [maxAge]; si no, null.
  static List<BusArrival>? cachedArrivals(int stopId, {Duration maxAge = const Duration(seconds: 45)}) {
    final c = _cache[stopId];
    if (c == null || DateTime.now().difference(c.at) > maxAge) return null;
    return c.arrivals;
  }

  @visibleForTesting
  static void clearCache() => _cache.clear();

  Future<List<BusArrival>> getArrivalTimes(int stopId) async {
    try {
      // Usar el proxy del backend en Web para evitar errores de CORS
      final url = kIsWeb 
          ? '${AppConfig.baseUrl}/proxy/bus-times?id=$stopId'
          : '$baseUrl?id=$stopId';
          
      final response = await ApiClient().get(url);

      if (response.statusCode != 200) {
        return [];
      }

      // Parsear HTML
      final document = html_parser.parse(response.data.toString());
      final rows = document.querySelectorAll('table tr');
      
      final arrivals = <BusArrival>[];
      
      // Saltar la primera fila (encabezados)
      for (var i = 1; i < rows.length; i++) {
        final cells = rows[i].querySelectorAll('td');
        if (cells.length >= 3) {
          final rawLine = cells[0].text.trim().toUpperCase();
          final destination = cells[1].text.trim();
          final time = cells[2].text.trim();
          
          if (rawLine.isNotEmpty && destination.isNotEmpty && time.isNotEmpty) {
            arrivals.add(BusArrival(
              line: rawLine,
              destination: destination,
              time: time,
            ));
          }
        }
      }

      _cache[stopId] = _CachedArrivals(DateTime.now(), arrivals);
      return arrivals;
    } catch (e) {
      print('Error obteniendo tiempos de llegada: $e');
      return [];
    }
  }
}
