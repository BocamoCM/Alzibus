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

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_email');
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