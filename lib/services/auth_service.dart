import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_config.dart';

/// Excepción lanzada cuando las credenciales son incorrectas.
class AuthInvalidCredentialsException implements Exception {
  const AuthInvalidCredentialsException();
}

/// Excepción lanzada cuando no hay conexión con el servidor.
class AuthNetworkException implements Exception {
  final Object cause;
  const AuthNetworkException(this.cause);
}

class AuthService {
  /// Intenta iniciar sesión. Lanza [AuthInvalidCredentialsException] si las
  /// credenciales son incorrectas, o [AuthNetworkException] si no hay red.
  Future<void> login(String email, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('${AppConfig.baseUrl}/login'),
            headers: AppConfig.headers,
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(AppConfig.httpTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'] as String;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', token);
        await prefs.setString('user_email', data['user']['email'] as String);
        await prefs.setInt('user_id', data['user']['id'] as int);
        // Guardar expiración del token para validación futura
        final expiry = _extractExpiry(token);
        if (expiry != null) {
          await prefs.setInt('token_expiry', expiry);
        }
        return;
      }
      throw const AuthInvalidCredentialsException();
    } on AuthInvalidCredentialsException {
      rethrow;
    } catch (e) {
      debugPrint('Error en login: $e');
      throw AuthNetworkException(e);
    }
  }

  /// Intenta registrar un nuevo usuario. Lanza [AuthNetworkException] si
  /// el servidor no responde, o devuelve false si el usuario ya existe.
  Future<bool> register(String email, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('${AppConfig.baseUrl}/register'),
            headers: AppConfig.headers,
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(AppConfig.httpTimeout);

      return response.statusCode == 201;
    } catch (e) {
      debugPrint('Error en registro: $e');
      throw AuthNetworkException(e);
    }
  }

  /// Verifica el código OTP enviado al correo. Lanza [AuthNetworkException].
  /// Devuelve null si tuvo éxito, o el mensaje de error si falló.
  Future<String?> verifyEmail(String email, String code) async {
    try {
      final response = await http
          .post(
            Uri.parse('${AppConfig.baseUrl}/verify-email'),
            headers: AppConfig.headers,
            body: jsonEncode({'email': email, 'code': code}),
          )
          .timeout(AppConfig.httpTimeout);

      if (response.statusCode == 200) return null; // éxito
      final body = jsonDecode(response.body);
      return body['error'] as String? ?? 'Error de verificación';
    } catch (e) {
      debugPrint('Error en verificación de email: $e');
      throw AuthNetworkException(e);
    }
  }

  /// Reenvía un nuevo código OTP al correo.
  /// Devuelve null si tuvo éxito, o el mensaje de error si falló.
  Future<String?> resendOtp(String email) async {
    try {
      final response = await http
          .post(
            Uri.parse('${AppConfig.baseUrl}/resend-otp'),
            headers: AppConfig.headers,
            body: jsonEncode({'email': email}),
          )
          .timeout(AppConfig.httpTimeout);

      if (response.statusCode == 200) return null; // éxito
      final body = jsonDecode(response.body);
      return body['error'] as String? ?? 'Error al reenviar código';
    } catch (e) {
      debugPrint('Error al reenviar OTP: $e');
      throw AuthNetworkException(e);
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_email');
    await prefs.remove('user_id');
    await prefs.remove('token_expiry');
  }

  /// Comprueba si hay sesión activa Y el token no ha expirado.
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) return false;

    // Validar expiración
    final expiry = prefs.getInt('token_expiry');
    if (expiry != null) {
      final expiryDate = DateTime.fromMillisecondsSinceEpoch(expiry * 1000);
      if (DateTime.now().isAfter(expiryDate)) {
        debugPrint('Token JWT expirado, cerrando sesión');
        await logout();
        return false;
      }
    }
    return true;
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Future<String?> getSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_email');
  }

  /// Obtiene el perfil del usuario desde la API.
  Future<Map<String, dynamic>?> getProfile(String token) async {
    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.baseUrl}/users/profile'),
            headers: {
              ...AppConfig.headers,
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(AppConfig.httpTimeout);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error obteniendo perfil: $e');
    }
    return null;
  }

  /// Actualiza el email del usuario.
  Future<bool> updateEmail(String token, String newEmail) async {
    try {
      final response = await http
          .put(
            Uri.parse('${AppConfig.baseUrl}/users/profile'),
            headers: {
              ...AppConfig.headers,
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'email': newEmail}),
          )
          .timeout(AppConfig.httpTimeout);
      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_email', newEmail);
        return true;
      }
      final error = jsonDecode(response.body)['error'] ?? 'Error desconocido';
      throw Exception(error);
    } catch (e) {
      debugPrint('Error actualizando email: $e');
      rethrow;
    }
  }

  /// Cambia la contraseña del usuario.
  Future<bool> updatePassword(String token, String currentPassword, String newPassword) async {
    try {
      final response = await http
          .put(
            Uri.parse('${AppConfig.baseUrl}/users/password'),
            headers: {
              ...AppConfig.headers,
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'currentPassword': currentPassword,
              'newPassword': newPassword,
            }),
          )
          .timeout(AppConfig.httpTimeout);
      if (response.statusCode == 200) return true;
      final error = jsonDecode(response.body)['error'] ?? 'Error desconocido';
      throw Exception(error);
    } catch (e) {
      debugPrint('Error cambiando contraseña: $e');
      rethrow;
    }
  }

  /// Envía un pulso de actividad al servidor para indicar que el usuario está en línea.
  Future<void> sendHeartbeat() async {
    try {
      final token = await getToken();
      if (token == null) return;

      await http.post(
        Uri.parse('${AppConfig.baseUrl}/users/heartbeat'),
        headers: {
          ...AppConfig.headers,
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Error en heartbeat: $e');
    }
  }

  /// Extrae el campo `exp` del payload de un JWT (sin verificar firma).
  int? _extractExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = parts[1];
      // Base64url → Base64 estándar
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final map = jsonDecode(decoded) as Map<String, dynamic>;
      return map['exp'] as int?;
    } catch (e) {
      debugPrint('Error decodificando JWT: $e');
      return null;
    }
  }
}
