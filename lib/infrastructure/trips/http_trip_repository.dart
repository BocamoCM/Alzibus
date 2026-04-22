import '../../domain/entities/trip_record.dart';
import '../../domain/exceptions/app_failure.dart';
import '../../domain/ports/outbound/http_port.dart';
import '../../domain/ports/outbound/trip_repository.dart';
import '../../domain/shared/result.dart';

/// Implementación del repositorio de viajes basada en [HttpPort].
///
/// Realiza llamadas HTTP mapeando las respuestas a [TripRecord].
/// NO recibe token — el [HttpPort] (DioHttpAdapter) ya lo inyecta
/// vía interceptors de Dio.
class HttpTripRepository implements TripRepository {
  final HttpPort _http;

  const HttpTripRepository(this._http);

  @override
  Future<Result<List<TripRecord>, AppFailure>> fetchAll() async {
    final result = await _http.get('/trips');
    if (result.isErr) return Err(result.unwrapErr());

    final response = result.unwrap();
    if (!response.isSuccess) {
      return Err(ServerFailure(
        statusCode: response.statusCode,
        body: response.body?.toString(),
      ));
    }

    final data = response.body;
    if (data is List<dynamic>) {
      try {
        final records = data
            .map((e) => TripRecord.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        return Ok(records);
      } catch (e, s) {
        return Err(UnexpectedResponseFailure(cause: e, stackTrace: s));
      }
    }
    return const Ok([]);
  }

  @override
  Future<Result<TripRecord, AppFailure>> addTrip({
    required String line,
    required String destination,
    required String stopName,
    required int stopId,
    required DateTime timestamp,
    required bool confirmed,
    String? paymentMethod,
  }) async {
    final data = {
      'line': line,
      'destination': destination,
      'stopName': stopName,
      'stopId': stopId,
      'timestamp': timestamp.toIso8601String(),
      'confirmed': confirmed,
      'paymentMethod': paymentMethod,
    };

    final result = await _http.post('/trips', body: data);
    if (result.isErr) return Err(result.unwrapErr());

    final response = result.unwrap();
    if (response.statusCode == 201) {
      final body = response.bodyAsMap;
      if (body != null) {
        return Ok(TripRecord.fromJson(body));
      }
      return const Err(UnexpectedResponseFailure());
    }

    return Err(ServerFailure(
      statusCode: response.statusCode,
      body: response.body?.toString(),
    ));
  }

  @override
  Future<Result<void, AppFailure>> deleteTrip(int tripId) async {
    final result = await _http.delete('/trips/$tripId');
    if (result.isErr) return Err(result.unwrapErr());

    final response = result.unwrap();
    if (response.isSuccess) return const Ok(null);

    if (response.statusCode == 404) {
      return const Err(TripNotFoundFailure());
    }

    return Err(ServerFailure(
      statusCode: response.statusCode,
      body: response.body?.toString(),
    ));
  }

  @override
  Future<Result<void, AppFailure>> clearAll() async {
    final result = await _http.delete('/trips');
    if (result.isErr) return Err(result.unwrapErr());

    final response = result.unwrap();
    if (response.isSuccess) return const Ok(null);

    return Err(ServerFailure(
      statusCode: response.statusCode,
      body: response.body?.toString(),
    ));
  }
}
