import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../constants/app_config.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Excepción lanzada cuando las credenciales son incorrectas.
class AuthInvalidCredentialsException implements Exception {
  const AuthInvalidCredentialsException();
}

/// Excepción lanzada cuando se requiere un código OTP para completar el login.
class AuthLoginOtpRequiredException implements Exception {
  final String email;
  const AuthLoginOtpRequiredException(this.email);
}

/// Excepción lanzada cuando no hay conexión con el servidor.
class AuthNetworkException implements Exception {
  final Object cause;
  const AuthNetworkException(this.cause);
}

class AuthService {
  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _keyEmail = 'biometric_email';
  static const String _keyPassword = 'biometric_password';
  static const String _keyEnabled = 'biometric_enabled';

  // Caché temporal para persistir tras el OTP (estática para compartir entre instancias)
  static String? _tempEmail;
  static String? _tempPassword;

  /// Comprueba si el dispositivo soporta biometría y tiene huellas registradas.
  Future<bool> canCheckBiometrics() async {
    if (kIsWeb) return false;
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool isDeviceSupported = await _auth.isDeviceSupported();
      return canAuthenticateWithBiometrics && isDeviceSupported;
    } catch (e) {
      debugPrint('Error comprobando biometría: $e');
      return false;
    }
  }

  /// Intenta autenticar al usuario localmente con biometría.
  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Alzitrans – verify your identity / verifica tu identidad',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (e) {
      debugPrint('Error en autenticación biométrica: $e');
      return false;
    }
  }

  /// Guarda las credenciales de forma segura para futuro login biométrico.
  Future<void> saveBiometricCredentials(String email, String password) async {
    await _storage.write(key: _keyEmail, value: email);
    await _storage.write(key: _keyPassword, value: password);
    await _storage.write(key: _keyEnabled, value: 'true');
  }

  /// Pasa la caché temporal a persistente (se llama tras verificar OTP)
  Future<void> persistBiometricCredentials() async {
    if (_tempEmail != null && _tempPassword != null) {
      await saveBiometricCredentials(_tempEmail!, _tempPassword!);
      _tempEmail = null;
      _tempPassword = null;
    }
  }

  /// Comprueba si el usuario tiene activado el login biométrico.
  Future<bool> isBiometricEnabled() async {
    final String? enabled = await _storage.read(key: _keyEnabled);
    return enabled == 'true';
  }

  /// Elimina las credenciales biométricas (ej. al cerrar sesión).
  Future<void> clearBiometricCredentials() async {
    await _storage.delete(key: _keyEmail);
    await _storage.delete(key: _keyPassword);
    await _storage.delete(key: _keyEnabled);
  }

  /// Intenta el login automático usando biometría.
  Future<bool> loginWithBiometrics() async {
    if (!await isBiometricEnabled()) return false;

    if (await authenticateWithBiometrics()) {
      final String? email = await _storage.read(key: _keyEmail);
      final String? password = await _storage.read(key: _keyPassword);

      if (email != null && password != null) {
        // Login con biometric: true → el servidor salta el OTP.
        // La autenticación biométrica del dispositivo ya actúa como 2FA.
        try {
          await login(email, password, biometric: true);
          return true;
        } catch (e) {
          debugPrint('Error login tras biometría: $e');
          return false;
        }
      }
    }
    return false;
  }

  /// Intenta iniciar sesión. Lanza [AuthInvalidCredentialsException] si las
  /// credenciales son incorrectas, o [AuthNetworkException] si no hay red.
  /// Si [biometric] es true, el servidor salta el OTP (la huella actúa como 2FA).
  Future<void> login(String email, String password, {bool biometric = false}) async {
    // Guardar en caché temporal por si el usuario activa la huella tras el OTP
    _tempEmail = email;
    _tempPassword = password;

    try {
      final response = await ApiClient().post(
        '/login',
        data: {
          'email': email,
          'password': password,
          if (biometric) 'biometric': true,
        },
      );

      debugPrint('[AuthService] Login status: ${response.statusCode}');
      debugPrint('[AuthService] Login data: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;
        
        // Caso 1: Login directo
        if (data['token'] != null) {
          debugPrint('[AuthService] Login directo exitoso');
          await _saveSession(data);
          return;
        }
        
        // Caso 2: Se requiere OTP (2FA)
        if (data['requiresOtp'] == true) {
          debugPrint('[AuthService] Se requiere OTP para ${data['email']}');
          throw AuthLoginOtpRequiredException(data['email'] as String);
        }
        
        debugPrint('[AuthService] Respuesta 200 inesperada (sin token ni requiresOtp)');
        return;
      }
      
      final body = response.data;
      final error = body['error'] as String? ?? 'Error de autenticación';
      
      if (response.statusCode == 403 && error.contains('verificar tu correo')) {
        // Este caso es para cuando la cuenta NO está verificada en absoluto (registro pendiente)
        // Podríamos lanzar una excepción específica o manejarlo como error normal.
      }
      
      throw const AuthInvalidCredentialsException();
    } on AuthLoginOtpRequiredException {
      rethrow;
    } on AuthInvalidCredentialsException {
      rethrow;
    } catch (e) {
      debugPrint('Error en login: $e');
      throw AuthNetworkException(e);
    }
  }

  /// Intenta registrar un nuevo usuario. 
  /// Devuelve null si tuvo éxito, o el mensaje de error si falló.
  Future<String?> register(String email, String password) async {
    try {
      final response = await ApiClient().post(
        '/register',
        data: {'email': email, 'password': password},
      );

      if (response.statusCode == 201) return null; // Éxito
      
      final body = response.data;
      return body['error'] as String? ?? 'Error en el servidor (${response.statusCode})';
    } catch (e) {
      debugPrint('Error en registro: $e');
      throw AuthNetworkException(e);
    }
  }

  /// Verifica el código OTP de login (2FA).
  Future<String?> verifyLoginCode(String email, String code) async {
    try {
      final response = await ApiClient().post(
        '/login/verify',
        data: {'email': email, 'code': code},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        await _saveSession(data);
        return null; // éxito
      }
      
      final body = response.data;
      return body['error'] as String? ?? 'Código incorrecto';
    } catch (e) {
      debugPrint('Error en verificación de login: $e');
      throw AuthNetworkException(e);
    }
  }

  /// Guarda los datos de la sesión tras un login exitoso.
  Future<void> _saveSession(Map<String, dynamic> data) async {
    final token = data['token'] as String;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
    await prefs.setString('user_email', data['user']['email'] as String);
    await prefs.setInt('user_id', data['user']['id'] as int);
    await prefs.setBool('is_premium', data['user']['isPremium'] as bool? ?? false);
    
    // Establecer identidad en Sentry
    await Sentry.configureScope((scope) {
      scope.setUser(SentryUser(
        id: (data['user']['id'] as int).toString(),
        email: data['user']['email'] as String,
      ));
    });

    // Guardar expiración del token para validación futura
    final expiry = _extractExpiry(token);
    if (expiry != null) {
      await prefs.setInt('token_expiry', expiry);
    }
  }

  /// Verifica el código OTP enviado al correo (Registro).
  Future<String?> verifyEmail(String email, String code) async {
    try {
      final response = await ApiClient().post(
        '/verify-email',
        data: {'email': email, 'code': code},
      );

      if (response.statusCode == 200) return null; // éxito
      final body = response.data;
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
      final response = await ApiClient().post(
        '/resend-otp',
        data: {'email': email},
      );

      if (response.statusCode == 200) return null; // éxito
      final body = response.data;
      return body['error'] as String? ?? 'Error al reenviar código';
    } catch (e) {
      debugPrint('Error al reenviar OTP: $e');
      throw AuthNetworkException(e);
    }
  }

  Future<void> logout() async {
    // Notificar al servidor antes de borrar el token (para Discord tracking)
    try {
      await ApiClient().post('/users/logout');
    } catch (_) {
      // No bloquear el logout si falla la notificación
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_email');
    await prefs.remove('user_id');
    await prefs.remove('is_premium');
    await prefs.remove('token_expiry');
    await prefs.remove('pending_trip'); // Eliminar viajes pendientes al cerrar sesión
    
    // Limpiar identidad en Sentry
    await Sentry.configureScope((scope) {
      scope.setUser(null);
    });
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

  Future<bool> isUserPremium() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_premium') ?? false;
  }

  /// Obtiene el perfil del usuario desde la API.
  Future<Map<String, dynamic>?> getProfile(String token) async {
    try {
      final response = await ApiClient().get('/users/profile');
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_premium', data['isPremium'] as bool? ?? false);
        return data;
      }
    } catch (e) {
      debugPrint('Error obteniendo perfil: $e');
    }
    return null;
  }

  /// Actualiza el email del usuario.
  Future<bool> updateEmail(String token, String newEmail) async {
    try {
      final response = await ApiClient().put(
        '/users/profile',
        data: {'email': newEmail},
      );
      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_email', newEmail);
        return true;
      }
      final error = response.data['error'] ?? 'Error desconocido';
      throw Exception(error);
    } catch (e) {
      debugPrint('Error actualizando email: $e');
      rethrow;
    }
  }

  /// Cambia la contraseña del usuario.
  Future<bool> updatePassword(String token, String currentPassword, String newPassword) async {
    try {
      final response = await ApiClient().put(
        '/users/password',
        data: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
      );
      if (response.statusCode == 200) return true;
      final error = response.data['error'] ?? 'Error desconocido';
      throw Exception(error);
    } catch (e) {
      debugPrint('Error cambiando contraseña: $e');
      rethrow;
    }
  }

  /// Elimina permanentemente la cuenta del usuario y todos sus datos.
  Future<bool> deleteAccount(String token) async {
    try {
      final response = await ApiClient().delete('/users/profile');
      
      if (response.statusCode == 200) {
        await logout(); // Limpiar sesión local tras borrar en servidor
        return true;
      }
      
      final error = response.data['error'] ?? 'Error al eliminar cuenta';
      throw Exception(error);
    } catch (e) {
      debugPrint('Error eliminando cuenta: $e');
      rethrow;
    }
  }

  /// Envía un pulso de actividad al servidor para indicar que el usuario está en línea.
  Future<void> sendHeartbeat() async {
    try {
      final token = await getToken();
      if (token == null) return;

      await ApiClient().post('/users/heartbeat');
    } catch (e) {
      debugPrint('Error en heartbeat: $e');
    }
  }

  /// Solicita un código de recuperación de contraseña.
  Future<String?> requestPasswordReset(String email) async {
    try {
      final response = await ApiClient().post(
        '/forgot-password',
        data: {'email': email},
      );

      if (response.statusCode == 404) {
        return 'Endpoint no encontrado (404). Verifica que el servidor está actualizado.';
      }

      final body = response.data;
      if (response.statusCode == 200) {
        return null; // Éxito
      }
      return body['error'] as String? ?? 'Error al solicitar código (${response.statusCode})';
    } on FormatException {
      return 'Error de formato en la respuesta del servidor. ¿Se ha actualizado el backend?';
    } catch (e) {
      debugPrint('Error en requestPasswordReset: $e');
      throw AuthNetworkException(e);
    }
  }

  /// Restablece la contraseña usando el código recibido por email.
  Future<String?> resetPassword(String email, String code, String newPassword) async {
    try {
      final response = await ApiClient().post(
        '/reset-password',
        data: {
          'email': email,
          'code': code,
          'newPassword': newPassword,
        },
      );

      if (response.statusCode == 404) {
        return 'Endpoint no encontrado (404). Verifica que el servidor está actualizado.';
      }

      final body = response.data;
      if (response.statusCode == 200) return null; // Éxito
      return body['error'] as String? ?? 'Error al restablecer contraseña (${response.statusCode})';
    } on FormatException {
      return 'Error de formato en la respuesta. ¿Se ha actualizado el backend?';
    } catch (e) {
      debugPrint('Error en resetPassword: $e');
      throw AuthNetworkException(e);
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
