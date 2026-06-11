import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';
import '../core/storage/session_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'telemetry_service.dart';

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

/// Lanzada cuando el backend responde con un error de servidor genérico
/// (típicamente 5xx) que SÍ trae un mensaje legible — por ejemplo cuando
/// el SMTP de OTP cae y devuelve "No se pudo enviar el código por email".
/// Antes esto se mostraba como "credenciales inválidas" y engañaba al
/// usuario haciéndole pensar que la contraseña estaba mal.
class AuthServerException implements Exception {
  final String message;
  const AuthServerException(this.message);
}

class AuthService {
  final LocalAuthentication _auth = LocalAuthentication();
  // FSS para los metadatos de biometría (flag + email). YA NO guardamos
  // la password del usuario aquí; el patrón anterior persistía la contraseña
  // en claro dentro de FSS y permitía a un atacante con acceso al dispositivo
  // (root, malware, backup ADB capaz de leer el Keystore) recuperarla.
  // Ahora el JWT vive en [SessionStorage] (también FSS) y se reutiliza
  // mientras no expire; cuando expira, el usuario vuelve a hacer login OTP.
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _keyEmail = 'biometric_email';
  static const String _keyEnabled = 'biometric_enabled';
  // Clave legacy (preauditoría) — sólo se usa para borrarla al arrancar y
  // así eliminar contraseñas de instalaciones anteriores tras la actualización.
  static const String _legacyKeyPassword = 'biometric_password';

  // Email del último login exitoso, usado por [persistBiometricCredentials]
  // cuando el usuario decide activar biometría tras pasar el OTP. Estático
  // para compartir entre instancias del servicio dentro del mismo proceso.
  static String? _tempEmail;

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

  /// Activa el login biométrico para el [email] dado. Ya no recibe password:
  /// el JWT vigente en [SessionStorage] es lo que se reutiliza tras validar
  /// la huella.
  Future<void> saveBiometricCredentials(String email) async {
    await _storage.write(key: _keyEmail, value: email);
    await _storage.write(key: _keyEnabled, value: 'true');
    // Limpieza por si quedaba una password de versiones anteriores.
    await _storage.delete(key: _legacyKeyPassword);
  }

  /// Persiste la activación biométrica tras un OTP exitoso, usando el email
  /// cacheado en [_tempEmail] por el último login.
  Future<void> persistBiometricCredentials() async {
    if (_tempEmail != null) {
      await saveBiometricCredentials(_tempEmail!);
      _tempEmail = null;
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
    await _storage.delete(key: _keyEnabled);
    await _storage.delete(key: _legacyKeyPassword);
  }

  /// Intenta acceso automático usando biometría.
  ///
  /// Devuelve `true` si la huella es válida y aún hay un JWT vivo en
  /// [SessionStorage] (la sesión queda activa sin pasar por el backend).
  /// Devuelve `false` si la biometría falla, no está activada, o el JWT
  /// ha expirado — en ese caso el caller debe pedir login normal con OTP.
  Future<bool> loginWithBiometrics() async {
    if (!await isBiometricEnabled()) return false;
    if (!await authenticateWithBiometrics()) return false;

    final token = await SessionStorage.getToken();
    if (token == null) return false;

    final expiryEpoch = await SessionStorage.getExpiry();
    if (expiryEpoch != null) {
      final expires = DateTime.fromMillisecondsSinceEpoch(expiryEpoch * 1000);
      if (!DateTime.now().isBefore(expires)) {
        // Token caducado: forzar login con OTP. No podemos renovar solo con
        // huella porque ya no guardamos la password — y el backend tampoco
        // tiene un endpoint de refresh todavía. Limpiamos la sesión expirada
        // para que el resto de la app no la considere viva.
        await SessionStorage.clear();
        return false;
      }
    }
    return true;
  }

  /// Intenta iniciar sesión. Lanza [AuthInvalidCredentialsException] si las
  /// credenciales son incorrectas, o [AuthNetworkException] si no hay red.
  /// Si [biometric] es true, el servidor salta el OTP (la huella actúa como 2FA).
  Future<void> login(String email, String password, {bool biometric = false}) async {
    // Cacheamos solo el email para que persistBiometricCredentials pueda
    // marcar la huella tras el OTP. La password NUNCA se persiste.
    _tempEmail = email;

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

      // 5xx = problema del servidor (no credenciales). El backend ya nos
      // pasa un mensaje legible — p.ej. "No se pudo enviar el código por
      // email. Inténtalo de nuevo en unos segundos." cuando Brevo cae.
      // Antes esto se convertía en "credenciales inválidas" → usuario
      // pensaba que la contraseña estaba mal y dejaba la app.
      if (response.statusCode != null && response.statusCode! >= 500) {
        throw AuthServerException(error);
      }

      throw const AuthInvalidCredentialsException();
    } on AuthLoginOtpRequiredException {
      rethrow;
    } on AuthInvalidCredentialsException {
      rethrow;
    } on AuthServerException {
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
    final email = data['user']['email'] as String;
    final userId = data['user']['id'] as int;
    final expiry = _extractExpiry(token);

    // Token + identidad → secure storage (Keystore/Keychain). Antes vivían
    // en SharedPreferences sin cifrar → cualquier backup ADB o app con root
    // podía leerlos.
    await SessionStorage.saveSession(
      token: token,
      email: email,
      userId: userId,
      expiryEpoch: expiry,
    );

    // Establecer identidad en Sentry
    await Sentry.configureScope((scope) {
      scope.setUser(SentryUser(id: userId.toString(), email: email));
    });

    // Telemetría: notificar el inicio de sesión (sin cooldown). Cubre todos
    // los caminos de login (directo, OTP, biométrico) porque todos pasan por aquí.
    // No esperamos a la respuesta — no debe bloquear el flujo de auth.
    // ignore: discarded_futures
    TelemetryService.sendLogin();
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

    await SessionStorage.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pending_trip'); // No-PII pero ligado a la sesión

    // Limpiar identidad en Sentry
    await Sentry.configureScope((scope) {
      scope.setUser(null);
    });
  }

  /// Comprueba si hay sesión activa Y el token no ha expirado.
  Future<bool> isLoggedIn() async {
    final token = await SessionStorage.getToken();
    if (token == null) return false;

    final expiry = await SessionStorage.getExpiry();
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

  Future<String?> getToken() => SessionStorage.getToken();

  Future<String?> getSavedEmail() => SessionStorage.getEmail();

  /// Obtiene el perfil del usuario desde la API.
  Future<Map<String, dynamic>?> getProfile(String token) async {
    try {
      final response = await ApiClient().get('/users/profile');
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
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
        await SessionStorage.updateEmail(newEmail);
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
