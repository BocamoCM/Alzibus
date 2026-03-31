import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_play_install_referrer/android_play_install_referrer.dart';
import '../constants/app_config.dart';

/// Servicio encargado de leer el "Install Referrer" de la Google Play Store
/// en el primer inicio de la app para atribuir las descargas físicas (Códigos QR).
class InstallTrackingService {
  static const String _keyHasSentPing = 'has_sent_install_ping';

  static Future<void> checkAndSendReferrer(SharedPreferences prefs) async {
    // Solo disponible en Android
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    
    // Si ya procesamos el evento de instalación, terminamos silenciosamente.
    if (prefs.getBool(_keyHasSentPing) == true) {
      return;
    }

    try {
      debugPrint('[InstallTracking] Solicitando Referrer a Google Play...');
      ReferrerDetails referrerDetails = await AndroidPlayInstallReferrer.installReferrer;
      final referrerUrl = referrerDetails.installReferrer;

      if (referrerUrl != null && referrerUrl.isNotEmpty) {
        debugPrint('[InstallTracking] Referrer obtenido: $referrerUrl');
        
        // Enviar hitcap al backend
        final uri = Uri.parse('${AppConfig.baseUrl}/metrics/install');
        final response = await http.post(
          uri,
          headers: AppConfig.headers,
          body: jsonEncode({'referrer': referrerUrl}),
        ).timeout(AppConfig.httpTimeout);

        if (response.statusCode == 200) {
          debugPrint('[InstallTracking] Ping de instalación enviado con éxito.');
          // Marcar como procesado con éxito para que no se repita
          await prefs.setBool(_keyHasSentPing, true);
        } else {
          debugPrint('[InstallTracking] El servidor rechazó el ping: ${response.statusCode}');
        }
      } else {
        debugPrint('[InstallTracking] Referrer vacío o nulo. Marcamos como procesado.');
        // Fallback: Si se instaló sin referrer, se marca para no sobrecargar los inicios 
        await prefs.setBool(_keyHasSentPing, true); 
      }
    } catch (e) {
      debugPrint('[InstallTracking] Error obteniendo el referrer (posiblemente sin Play Store): $e');
      // Lo marcamos para no interrumpir inicios futuros
      await prefs.setBool(_keyHasSentPing, true);
    }
  }
}
