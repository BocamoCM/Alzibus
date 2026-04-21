import '../value_objects/email.dart';

/// Entidad raíz del usuario autenticado.
class User {
  final int id;
  final Email email;
  final bool isPremium;

  const User({
    required this.id,
    required this.email,
    this.isPremium = false,
  });

  User copyWith({int? id, Email? email, bool? isPremium}) => User(
        id: id ?? this.id,
        email: email ?? this.email,
        isPremium: isPremium ?? this.isPremium,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          other.id == id &&
          other.email == email &&
          other.isPremium == isPremium;

  @override
  int get hashCode => Object.hash(id, email, isPremium);

  @override
  String toString() => 'User(id=$id, email=$email, premium=$isPremium)';
}
