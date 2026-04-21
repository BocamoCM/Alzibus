import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../../services/auth_service.dart';
import '../../providers/high_visibility_provider.dart';
import '../../domain/shared/result.dart';
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
        final isExpired = JwtDecoder.isExpired(token);
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
    final loggedIn = await ref.read(authServiceProvider).isLoggedIn();
    state = state.copyWith(isLoading: false, isLoggedIn: loggedIn);
  }

  Future<void> login(String email, String password, {bool biometric = false}) async {
    state = state.copyWith(isLoading: true);
    try {
      await ref.read(authServiceProvider).login(email, password, biometric: biometric);
      state = state.copyWith(isLoading: false, isLoggedIn: true);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }
  
  Future<void> register(String email, String password) async {
    state = state.copyWith(isLoading: true);
    try {
      await ref.read(authServiceProvider).register(email, password);
      state = state.copyWith(isLoading: false, isLoggedIn: false); // Asumimos que tras registrar debe verificar OTP o similar, pero no está logueado a nivel JWT
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
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
    try {
      await ref.read(authServiceProvider).deleteAccount(token);
      state = state.copyWith(isLoading: false, isLoggedIn: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
