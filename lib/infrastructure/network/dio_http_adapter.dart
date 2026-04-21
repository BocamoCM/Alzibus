import 'package:dio/dio.dart';

import '../../domain/exceptions/app_failure.dart';
import '../../domain/ports/outbound/http_port.dart';
import '../../domain/shared/result.dart';

/// Adaptador de [HttpPort] basado en Dio.
///
/// Reutiliza la instancia de Dio que ya existe en `core/network/api_client.dart`
/// (con su interceptor de JWT y manejo de 401), de forma que toda la app
/// comparta una sola sesión HTTP.
///
/// Nunca lanza: traduce las excepciones de Dio a [NetworkFailure] concretos.
class DioHttpAdapter implements HttpPort {
  final Dio _dio;
  const DioHttpAdapter(this._dio);

  @override
  Future<Result<HttpResponse, NetworkFailure>> get(
    String path, {
    Map<String, dynamic>? query,
  }) =>
      _send(() => _dio.get(path, queryParameters: query));

  @override
  Future<Result<HttpResponse, NetworkFailure>> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) =>
      _send(() => _dio.post(path, data: body, queryParameters: query));

  @override
  Future<Result<HttpResponse, NetworkFailure>> put(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) =>
      _send(() => _dio.put(path, data: body, queryParameters: query));

  @override
  Future<Result<HttpResponse, NetworkFailure>> delete(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) =>
      _send(() => _dio.delete(path, data: body, queryParameters: query));

  Future<Result<HttpResponse, NetworkFailure>> _send(
    Future<Response> Function() request,
  ) async {
    try {
      final response = await request();
      return Ok(_toHttpResponse(response));
    } on DioException catch (e, s) {
      return Err(_mapDioException(e, s));
    } catch (e, s) {
      return Err(ServerFailure(cause: e, stackTrace: s));
    }
  }

  HttpResponse _toHttpResponse(Response r) {
    final headers = <String, String>{};
    r.headers.forEach((k, v) => headers[k] = v.join(','));
    return HttpResponse(
      statusCode: r.statusCode ?? 0,
      body: r.data,
      headers: headers,
    );
  }

  NetworkFailure _mapDioException(DioException e, StackTrace s) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return TimeoutFailure(cause: e, stackTrace: s);
      case DioExceptionType.connectionError:
        return OfflineFailure(cause: e, stackTrace: s);
      case DioExceptionType.badResponse:
        return ServerFailure(
          statusCode: e.response?.statusCode,
          body: e.response?.data?.toString(),
          cause: e,
          stackTrace: s,
        );
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return ServerFailure(cause: e, stackTrace: s);
    }
  }
}
