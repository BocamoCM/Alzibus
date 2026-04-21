import '../value_objects/jwt_token.dart';
import 'user.dart';

/// Sesión activa: un usuario + un token JWT con su expiración.
class Session {
  final User user;
  final JwtToken token;

  const Session({required this.user, required this.token});

  bool isAliveAt(DateTime now) => !token.isExpiredAt(now);

  @override
  String toString() => 'Session(user=$user, $token)';
}
