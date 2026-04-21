import 'dart:convert';

import 'package:alzitrans/domain/entities/session.dart';
import 'package:alzitrans/domain/entities/user.dart';
import 'package:alzitrans/domain/value_objects/email.dart';
import 'package:alzitrans/domain/value_objects/jwt_token.dart';
import 'package:alzitrans/infrastructure/storage/session_storage_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/in_memory_preferences.dart';

String _fakeJwt(int exp) {
  String b64(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${b64({'alg': 'HS256'})}.${b64({'exp': exp})}.sig';
}

void main() {
  late InMemoryPreferences prefs;
  late SessionStorageImpl storage;

  setUp(() {
    prefs = InMemoryPreferences();
    storage = SessionStorageImpl(prefs);
  });

  test('save → read recupera la sesión completa', () async {
    final session = Session(
      user: User(
        id: 7,
        email: Email.tryParse('a@b.com').unwrap(),
        isPremium: true,
      ),
      token: JwtToken.tryParse(_fakeJwt(2000000000)).unwrap(),
    );

    await storage.save(session);
    final read = await storage.read();
    final restored = read.unwrap();

    expect(restored, isNotNull);
    expect(restored!.user.id, 7);
    expect(restored.user.email.value, 'a@b.com');
    expect(restored.user.isPremium, true);
    expect(restored.token.expiresAt, isNotNull);
  });

  test('read sin sesión devuelve null', () async {
    final read = await storage.read();
    expect(read.unwrap(), isNull);
  });

  test('clear borra TODAS las claves del legacy', () async {
    await prefs.writeString('jwt_token', 'x.y.z');
    await prefs.writeString('user_email', 'a@b.com');
    await prefs.writeInt('user_id', 1);
    await prefs.writeBool('is_premium', false);
    await prefs.writeInt('token_expiry', 123);
    await prefs.writeString('pending_trip', '{}');

    await storage.clear();
    expect(prefs.snapshot, isEmpty);
  });

  test('si el token guardado está corrupto, read lo trata como sin sesión y lo limpia', () async {
    await prefs.writeString('jwt_token', 'corrupto');
    final read = await storage.read();
    expect(read.unwrap(), isNull);
    expect(prefs.snapshot.containsKey('jwt_token'), false);
  });
}
