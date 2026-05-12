import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../../constants/app_config.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late Dio dio;

  /// Construye un User-Agent identificable para que el backend sepa
  /// qué plataforma usa el cliente incluso si no envía 'platform' en el body.
  /// Ejemplos:
  ///   "Alzitrans/1.0 (Android)"
  ///   "Alzitrans/1.0 (iOS)"
  ///   "Alzitrans/1.0 (Web)"
  static String _buildUserAgent() {
    String platform = 'Unknown';
    if (kIsWeb) {
      platform = 'Web';
    } else {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android: platform = 'Android'; break;
        case TargetPlatform.iOS:     platform = 'iOS';     break;
        case TargetPlatform.windows: platform = 'Windows'; break;
        case TargetPlatform.macOS:   platform = 'macOS';   break;
        case TargetPlatform.linux:   platform = 'Linux';   break;
        default: platform = 'Unknown';
      }
    }
    return 'Alzitrans/1.0 ($platform)';
  }

  ApiClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: AppConfig.httpTimeout,
      receiveTimeout: AppConfig.httpTimeout,
      headers: {
        ...AppConfig.headers,
        // En web Dio NO permite sobrescribir 'user-agent' (es un header prohibido
        // por la fetch spec; el navegador siempre pone el suyo). En móvil/desktop sí.
        if (!kIsWeb) 'User-Agent': _buildUserAgent(),
      },
      validateStatus: (status) => true, // Para mantener compatibilidad con las lógicas actuales de la app que leen response.statusCode manualmente.
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Solo inyectar Token JWT si la petición es hacia nuestro API interno
        final isInternalApi = options.path.startsWith('/') || options.uri.toString().startsWith(AppConfig.baseUrl);
        
        if (isInternalApi) {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('jwt_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401) {
          debugPrint('[ApiClient] Error 401 detectado, sesión posiblemente caducada.');
          // Aquí podríamos disparar un evento global o llamar a AuthService.logout()
          // pero para evitar dependencias circulares, emitiremos la limpieza de prefs
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('jwt_token');
          await prefs.remove('user_email');
          await prefs.remove('user_id');
          await prefs.remove('token_expiry');
          await prefs.remove('pending_trip');
        }
        return handler.next(e);
      },
    ));
    
    // Opcional: Logger en modo debug
    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: true,
        responseBody: true,
        error: true,
      ));
    }
  }

  // Métodos helper para facilitar uso
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    return dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) async {
    return dio.post(path, data: data, queryParameters: queryParameters, options: options);
  }

  Future<Response> put(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    return dio.put(path, data: data, queryParameters: queryParameters);
  }

  Future<Response> delete(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    return dio.delete(path, data: data, queryParameters: queryParameters);
  }
}
