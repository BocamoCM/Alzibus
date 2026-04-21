import '../../exceptions/app_failure.dart';
import '../../shared/result.dart';

/// Respuesta HTTP en formato neutral (sin Dio, sin http).
class HttpResponse {
  final int statusCode;

  /// Cuerpo decodificado. Puede ser `Map<String, dynamic>`, `List<dynamic>`,
  /// `String` o `null`. Los adaptadores devuelven el JSON ya parseado.
  final Object? body;

  final Map<String, String> headers;

  const HttpResponse({
    required this.statusCode,
    this.body,
    this.headers = const {},
  });

  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  /// Atajo: si `body` es un `Map`, lo devuelve; si no, `null`.
  Map<String, dynamic>? get bodyAsMap {
    final b = body;
    if (b is Map<String, dynamic>) return b;
    if (b is Map) return Map<String, dynamic>.from(b);
    return null;
  }

  /// Atajo: si el body trae un campo `error` (convención del backend), lo devuelve.
  String? get errorMessage => bodyAsMap?['error'] as String?;
}

/// Puerto de cliente HTTP. La implementación concreta (`DioHttpAdapter`) sabe
/// de Dio, baseUrl, interceptors, JWT, etc. El dominio sólo ve esta interfaz.
///
/// IMPORTANTE: las implementaciones NUNCA lanzan — siempre devuelven
/// `Result<HttpResponse, NetworkFailure>`. Eso garantiza que el
/// flujo de errores de red sea explícito en todo el dominio.
abstract interface class HttpPort {
  Future<Result<HttpResponse, NetworkFailure>> get(
    String path, {
    Map<String, dynamic>? query,
  });

  Future<Result<HttpResponse, NetworkFailure>> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  });

  Future<Result<HttpResponse, NetworkFailure>> put(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  });

  Future<Result<HttpResponse, NetworkFailure>> delete(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  });
}
