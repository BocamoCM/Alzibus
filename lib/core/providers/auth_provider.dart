import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../../services/auth_service.dart';
import '../storage/session_storage.dart';

// Provider básico para el servicio de autenticación
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Token JWT pre-cargado en `main()` desde [SessionStorage] (FSS).
///
/// El `build()` del [AuthNotifier] es síncrono y Riverpod no permite usar
/// `await` directamente; por eso `main()` lee el token de FSS antes de
/// `runApp()` y lo inyecta aquí como override. Si no se override-a (p. ej.
/// en tests) devuelve `null` (= no logueado).
final initialJwtTokenProvider = Provider<String?>((ref) => null);

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
    final token = ref.watch(initialJwtTokenProvider);
    bool isLogged = false;

    if (token != null && token.split('.').length == 3) {
      try {
        if (!JwtDecoder.isExpired(token)) {
          isLogged = true;
        } else {
          // El token estaba expirado al arrancar: limpiamos el secure storage
          // en background (no podemos await aquí — Notifier.build es síncrono).
          // ignore: discarded_futures
          SessionStorage.clear();
        }
      } catch (_) {
        // Token malformado → ignoramos y dejamos isLogged=false
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

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    await ref.read(authServiceProvider).logout();
    state = state.copyWith(isLoading: false, isLoggedIn: false);
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
