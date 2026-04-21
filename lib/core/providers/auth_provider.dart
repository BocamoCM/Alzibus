import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../providers/high_visibility_provider.dart';
import '../../domain/exceptions/app_failure.dart';
import '../../domain/ports/outbound/auth_repository.dart';
import '../../domain/shared/result.dart';
import '../../domain/value_objects/jwt_token.dart';
import '../../presentation/providers/di.dart';

// Provider básico para el servicio de autenticación
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// Estado de la autenticación
class AuthState {
  final bool isLoading;
  final bool isLoggedIn;
  
  const AuthState({this.isLoading = false, this.isLoggedIn = false});

  AuthState copyWith({bool? isLoading, bool? isLoggedIn}) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
    );
  }
}

// Notifier para exponer y manipular el estado de autenticación de forma reactiva
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Lectura síncrona gracias a sharedPreferencesProvider
    final prefs = ref.watch(sharedPreferencesProvider);
    final token = prefs.getString('jwt_token');
    bool isLogged = false;
    
    if (token != null && token.split('.').length == 3) {
      try {
        final jwtResult = JwtToken.tryParse(token);
        final isExpired = switch (jwtResult) {
          Ok(value: final jwt) => jwt.isExpiredAt(DateTime.now()),
          Err() => true,
        };
        if (!isExpired) {
          isLogged = true;
        } else {
          // Si está expirado, limpiamos
          prefs.remove('jwt_token');
          prefs.remove('user_email');
          prefs.remove('user_id');
        }
      } catch (e) {
        // Ignorar
      }
    }
    return AuthState(isLoading: false, isLoggedIn: isLogged);
  }

  Future<void> checkLogin() async {
    state = state.copyWith(isLoading: true);
    final sessionStorage = ref.read(sessionStorageProvider);
    final result = await sessionStorage.read();

    switch (result) {
      case Ok(value: final session):
        if (session == null) {
          state = state.copyWith(isLoading: false, isLoggedIn: false);
          return;
        }
        final isExpired = session.token.isExpiredAt(DateTime.now());
        if (isExpired) {
          await sessionStorage.clear();
          state = state.copyWith(isLoading: false, isLoggedIn: false);
          return;
        }
        state = state.copyWith(isLoading: false, isLoggedIn: true);
        return;
      case Err():
        state = state.copyWith(isLoading: false, isLoggedIn: false);
        return;
    }
  }

  Future<void> login(String email, String password, {bool biometric = false}) async {
    state = state.copyWith(isLoading: true);
    final loginWithPassword = ref.read(loginWithPasswordProvider);
    final result = await loginWithPassword(
      rawEmail: email,
      rawPassword: password,
      biometric: biometric,
    );

    switch (result) {
      case Ok(value: LoginSucceeded()):
        state = state.copyWith(isLoading: false, isLoggedIn: true);
        return;
      case Ok(value: LoginRequiresOtp(:final email)):
        state = state.copyWith(isLoading: false, isLoggedIn: false);
        throw AuthLoginOtpRequiredException(email.value);
      case Err(failure: final f):
        state = state.copyWith(isLoading: false);
        throw _mapLoginFailure(f);
    }
  }
  
  Future<void> register(String email, String password) async {
    state = state.copyWith(isLoading: true);
    final registerUser = ref.read(registerUserProvider);
    final result = await registerUser(
      rawEmail: email,
      rawPassword: password,
    );

    switch (result) {
      case Ok():
        state = state.copyWith(isLoading: false, isLoggedIn: false);
        return;
      case Err(failure: final f):
        state = state.copyWith(isLoading: false);
        throw _mapRegisterFailure(f);
    }
  }

  Future<bool> logout() async {
    state = state.copyWith(isLoading: true);
    final logout = ref.read(logoutProvider);
    final result = await logout();

    switch (result) {
      case Ok():
        state = state.copyWith(isLoading: false, isLoggedIn: false);
        return true;
      case Err():
        state = state.copyWith(isLoading: false);
        return false;
    }
  }

  Future<void> deleteAccount(String token) async {
    state = state.copyWith(isLoading: true);
    final deleteAccount = ref.read(deleteAccountProvider);
    final result = await deleteAccount();

    switch (result) {
      case Ok():
        state = state.copyWith(isLoading: false, isLoggedIn: false);
        return;
      case Err(failure: final f):
        state = state.copyWith(isLoading: false);
        throw Exception('No se pudo eliminar la cuenta: ${f.code}');
    }
  }

  Object _mapLoginFailure(AppFailure failure) {
    return switch (failure) {
      OtpRequiredFailure(:final email) => AuthLoginOtpRequiredException(email),
      InvalidCredentialsFailure() => const AuthInvalidCredentialsException(),
      InvalidOtpFailure() => const AuthInvalidCredentialsException(),
      SessionExpiredFailure() => const AuthInvalidCredentialsException(),
      ValidationFailure() => const AuthInvalidCredentialsException(),
      NetworkFailure() => AuthNetworkException(
          failure.cause ?? Exception(failure.code),
        ),
      EmailNotVerifiedFailure() => Exception(
          'Debes verificar tu correo antes de iniciar sesión.',
        ),
      _ => Exception('Error inesperado: ${failure.code}'),
    };
  }

  Object _mapRegisterFailure(AppFailure failure) {
    return switch (failure) {
      NetworkFailure() => AuthNetworkException(
          failure.cause ?? Exception(failure.code),
        ),
      RegistrationFailure(serverMessage: final msg) =>
        Exception(msg ?? 'No se pudo completar el registro.'),
      ValidationFailure(fieldErrors: final errors) => Exception(
          errors.values.isNotEmpty ? errors.values.first : 'Datos inválidos.',
        ),
      _ => Exception('Error inesperado: ${failure.code}'),
    };
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
