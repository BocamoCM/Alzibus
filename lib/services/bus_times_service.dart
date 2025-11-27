import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

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

  Future<List<BusArrival>> getArrivalTimes(int stopId) async {
    try {
      final url = Uri.parse('$baseUrl?id=$stopId');
      final response = await http.get(url);

      if (response.statusCode != 200) {
        return [];
      }

      // Parsear HTML
      final document = html_parser.parse(response.body);
      final rows = document.querySelectorAll('table tr');
      
      final arrivals = <BusArrival>[];
      
      // Saltar la primera fila (encabezados)
      for (var i = 1; i < rows.length; i++) {
        final cells = rows[i].querySelectorAll('td');
        if (cells.length >= 3) {
          final line = cells[0].text.trim();
          final destination = cells[1].text.trim();
          final time = cells[2].text.trim();
          
          if (line.isNotEmpty && destination.isNotEmpty && time.isNotEmpty) {
            arrivals.add(BusArrival(
              line: line,
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
