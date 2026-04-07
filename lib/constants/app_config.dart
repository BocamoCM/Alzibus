/// Configuración centralizada de la aplicación.
/// Cambia [baseUrl] para apuntar a tu servidor.
class AppConfig {
  AppConfig._();

  /// URL base de la API de producción.
  static const String _productionBaseUrl = 'https://alzitrans.duckdns.org/api';

  /// URL base de la API.
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: _productionBaseUrl,
  );

  /// API Key que el servidor debe validar en el header [X-API-Key].
  /// Debe coincidir con la que configures en tu servidor Node.js.
  // API Key para validación básica (se debe pasar como --dart-define=API_KEY=...)
  static const String apiKey = String.fromEnvironment('API_KEY', defaultValue: 'alzibus-secret-key-2024');
  
  /// URL de la Política de Privacidad (Requerido por Google Play)
  static const String privacyPolicyUrl = 'https://github.com/BocamoCM/Alzibus/blob/main/backend/POLITICA_PRIVACIDAD_ALZITRANS.md';

  /// DSN de Sentry para el monitoreo de errores.
  static const String sentryDsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: 'https://b2bd0df7d8dfeb7fa13a08e0377d1898@o4510974925406208.ingest.de.sentry.io/4510974939299920',
  );

  /// --- CONFIGURACIÓN DE MONETIZACIÓN (ADMOB) ---
  
  /// Permite desactivar todos los anuncios de la app de forma global.
  static bool showAds = true; // Reactivado tras capturas de pantalla 

  /// ID de la Aplicación AdMob (Android)
  static const String admobAppId = 'ca-app-pub-5215993257564469~3690891315';

  /// ID del Banner Principal (Cabecera)
  static const String bannerAdId = 'ca-app-pub-5215993257564469/6729019552';

  /// ID del Banner de Ajustes (Inferior)
  static const String settingsBannerAdId = 'ca-app-pub-5215993257564469/4213160138';

  /// ID del Anuncio Nativo (Ficha de Parada)
  static const String nativeAdId = 'ca-app-pub-5215993257564469/1679805649';

  /// ID del Anuncio Intersticial (Post-NFC)
  static const String interstitialAdId = 'ca-app-pub-5215993257564469/8708248424';

  /// ID del Anuncio de Apertura (App Open Ad)
  static const String appOpenAdId = 'ca-app-pub-5215993257564469/7955497350';

  /// --- FIN MONETIZACIÓN ---

  /// Hash del commit actual (opcional, vía --dart-define=COMMIT_HASH=...)
  static const String commitHash = String.fromEnvironment('COMMIT_HASH', defaultValue: 'none');

  /// Timeout para peticiones HTTP.
  static const Duration httpTimeout = Duration(seconds: 10);

  /// Headers comunes para todas las peticiones.
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'X-API-Key': apiKey,
  };
}
