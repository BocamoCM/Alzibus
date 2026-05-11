import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';

/// Servicio de telemetría: identifica si la sesión proviene de la app móvil
/// (Android/iOS) o de la versión web (Flutter Web servido en /app/), y qué
/// plataforma usa el dispositivo.
///
/// El backend ya recibe el `User-Agent`, pero en clientes Dart el UA no es
/// fiable (a veces es "Dart/3.x"), así que enviamos `source` y `platform`
/// explícitamente en el body. El backend hace whitelist de valores.
class TelemetryService {
  TelemetryService._();

  /// 'web_app' (Flutter Web /app/) o 'mobile_app' (Android/iOS/desktop nativo).
  static String get source => kIsWeb ? 'web_app' : 'mobile_app';

  /// Plataforma del dispositivo. Usa `defaultTargetPlatform` (web-safe)
  /// para evitar el `dart:io` Platform que no compila en web.
  ///
  /// En web, `defaultTargetPlatform` devuelve la plataforma deducida del UA
  /// del navegador (p.ej. TargetPlatform.android en Chrome Android), pero
  /// nosotros preferimos marcar 'web' para que el dashboard distinga
  /// "usuarios web" de "usuarios app nativa" en la misma fila.
  static String get platform {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.linux:
        return 'linux';
      default:
        return 'unknown';
    }
  }

  /// Notifica al backend que la app se ha abierto, adjuntando source+platform.
  /// El servidor agrega esto a la tabla `web_metrics` con event_type='app_open'
  /// y además dispara la notificación de Discord existente.
  ///
  /// Devuelve silenciosamente si hay error de red — telemetría no debe romper
  /// el arranque de la app.
  static Future<void> sendAppOpen() async {
    await _post(event: 'app_open');
  }

  /// Notifica al backend que un usuario acaba de iniciar sesión.
  /// Pensado para llamarse desde `_saveSession` en AuthService: garantiza que
  /// cada login (directo / OTP / biométrico) deja un rastro independientemente
  /// del initState del widget raíz (que en web solo corre una vez por carga).
  ///
  /// Sin cooldown: cada login es un evento legítimo.
  static Future<void> sendLogin() async {
    await _post(event: 'login');
  }

  static Future<void> _post({required String event}) async {
    try {
      await ApiClient().post(
        '/metrics/app-open',
        data: {
          'event': event,         // 'app_open' | 'login'
          'source': source,
          'platform': platform,
        },
      );
    } catch (e) {
      debugPrint('[Telemetry] $event falló (silencioso): $e');
    }
  }
}
