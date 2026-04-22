import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

import '../../domain/exceptions/app_failure.dart';
import '../../domain/ports/outbound/stop_arrival_fetcher.dart';
import '../../domain/shared/result.dart';

/// Adaptador de [StopArrivalFetcher] que scrappa la web de tiempos de
/// Autocares Lozano (parada concreta).
class HttpStopArrivalFetcher implements StopArrivalFetcher {
  static const String _baseUrl =
      'https://servidor.autocareslozano.es/Alzira/webtiempos/PopupPoste.aspx';

  final Dio _dio;

  const HttpStopArrivalFetcher(this._dio);

  @override
  Future<Result<StopNextArrival?, AppFailure>> fetchNextArrival(
      int stopId) async {
    try {
      final response = await _dio.get('$_baseUrl?id=$stopId');
      if (response.statusCode != 200) {
        return Err(ServerFailure(statusCode: response.statusCode));
      }

      final document = html_parser.parse(response.data.toString());
      final rows = document.querySelectorAll('tr');

      for (final row in rows) {
        final cells = row.querySelectorAll('td');
        if (cells.length >= 3) {
          final line = cells[0].text.trim();
          final destination = cells[1].text.trim();
          final rawTime = cells[2].text.trim();
          if (line.isEmpty) continue;
          return Ok(StopNextArrival(
            line: line,
            destination: destination,
            displayTime: _formatTime(rawTime),
          ));
        }
      }
      return const Ok(null);
    } on DioException catch (e, s) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return Err(TimeoutFailure(cause: e, stackTrace: s));
        case DioExceptionType.connectionError:
          return Err(OfflineFailure(cause: e, stackTrace: s));
        case DioExceptionType.badResponse:
          return Err(ServerFailure(
            statusCode: e.response?.statusCode,
            cause: e,
            stackTrace: s,
          ));
        default:
          return Err(UnexpectedResponseFailure(cause: e, stackTrace: s));
      }
    } catch (e, s) {
      return Err(UnexpectedResponseFailure(cause: e, stackTrace: s));
    }
  }

  static String _formatTime(String time) {
    final lower = time.toLowerCase();
    if (lower.contains('<') || lower.contains('llegando')) {
      return '¡Llegando!';
    }
    final match = RegExp(r'(\d+)').firstMatch(lower);
    if (match != null) {
      return '${match.group(1)} min';
    }
    return time;
  }
}
