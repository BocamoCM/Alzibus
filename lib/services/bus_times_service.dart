import 'package:html/parser.dart' as html_parser;
import '../core/network/api_client.dart';

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

class BusTimesService {
  static const String baseUrl = 'https://servidor.autocareslozano.es/Alzira/webtiempos/PopupPoste.aspx';

  static final Map<String, String> _lineMapping = {
    'BL': 'L1', // Blava (Azul) -> L1
    'RB': 'L1', // Ribera (Azul) -> L1
    'VR': 'L2', // Verda (Verde) -> L2
    'TR': 'L3', // Taronja (Naranja) -> L3
  };

  static String _normalizeLine(String rawLine) {
    rawLine = rawLine.toUpperCase().trim();
    return _lineMapping[rawLine] ?? rawLine;
  }

  Future<List<BusArrival>> getArrivalTimes(int stopId) async {
    try {
      final response = await ApiClient().get('$baseUrl?id=$stopId');

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
          final rawLine = cells[0].text.trim();
          final destination = cells[1].text.trim();
          final time = cells[2].text.trim();
          
          if (rawLine.isNotEmpty && destination.isNotEmpty && time.isNotEmpty) {
            arrivals.add(BusArrival(
              line: _normalizeLine(rawLine),
              destination: destination,
              time: time,
            ));
          }
        }
      }
      
      return arrivals;
    } catch (e) {
      print('Error obteniendo tiempos de llegada: $e');
      return [];
    }
  }
}
