/// Configuración centralizada de la aplicación.
/// Cambia [baseUrl] para apuntar a tu servidor.
class AppConfig {
  AppConfig._();

  /// URL base de la API. Cámbiala por la IP/dominio real de tu servidor.
  static const String baseUrl = 'http://10.155.227.62:3000/api';

  /// API Key que el servidor debe validar en el header [X-API-Key].
  /// Debe coincidir con la que configures en tu servidor Node.js.
  static const String apiKey = 'alzibus-secret-key-2024';

  /// Timeout para peticiones HTTP.
  static const Duration httpTimeout = Duration(seconds: 10);

  /// Headers comunes para todas las peticiones.
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'X-API-Key': apiKey,
  };
}
