import 'package:html/parser.dart' as html_parser;
import '../network/api_client.dart';

class ScrapingRepository {
  /// Devuelve una lista de llegadas en formato Map para un `stopId` dado.
  /// Contiene: 'line', 'destination', 'timeText'
  static Future<List<Map<String, String>>> getStopArrivals(String stopId) async {
    final url = 'https://servidor.autocareslozano.es/Alzira/webtiempos/PopupPoste.aspx?id=$stopId';
    final response = await ApiClient().get(url);
    final List<Map<String, String>> arrivals = [];

    if (response.statusCode == 200) {
      final document = html_parser.parse(response.data.toString());
      final rows = document.querySelectorAll('tr');

      for (final row in rows) {
        final cells = row.querySelectorAll('td');
        if (cells.length >= 3) {
          // Extraemos de acuerdo a la estructura conocida de la tabla (normalmente pos 2 es tiempo)
          arrivals.add({
            'line': cells[0].text.trim(),
            'destination': cells[1].text.trim(), // Normalmente el destino o viceversa
            'timeText': cells[2].text.trim(),
          });
        }
      }
    }
    
    return arrivals;
  }
}
