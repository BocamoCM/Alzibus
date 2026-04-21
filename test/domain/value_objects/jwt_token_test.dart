import 'dart:convert';

import 'package:alzitrans/domain/exceptions/app_failure.dart';
import 'package:alzitrans/domain/value_objects/jwt_token.dart';
import 'package:flutter_test/flutter_test.dart';

String _fakeJwt(Map<String, dynamic> payload) {
  String b64(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final header = b64({'alg': 'HS256', 'typ': 'JWT'});
  final body = b64(payload);
  // firma irrelevante para el dominio
  return '$header.$body.signature';
}

void main() {
  group('JwtToken.tryParse', () {
    test('extrae el campo exp como DateTime', () {
      final exp = DateTime.utc(2030, 1, 1).millisecondsSinceEpoch ~/ 1000;
      final raw = _fakeJwt({'sub': '42', 'exp': exp});
      final r = JwtToken.tryParse(raw);
      expect(r.isOk, true);
      final t = r.unwrap();
      expect(t.expiresAt, isNotNull);
      expect(t.expiresAt!.toUtc().year, 2030);
    });

    test('isExpiredAt detecta correctamente la caducidad', () {
      final exp = DateTime.utc(2020, 1, 1).millisecondsSinceEpoch ~/ 1000;
      final t = JwtToken.tryParse(_fakeJwt({'exp': exp})).unwrap();
      expect(t.isExpiredAt(DateTime.utc(2025, 6, 1)), true);
      expect(t.isExpiredAt(DateTime.utc(2019, 6, 1)), false);
    });

    test('si no hay exp, isExpiredAt devuelve false (asume vivo)', () {
      final t = JwtToken.tryParse(_fakeJwt({'sub': '1'})).unwrap();
      expect(t.isExpiredAt(DateTime.now()), false);
    });

    test('rechaza tokens con menos de 3 partes', () {
      final r = JwtToken.tryParse('only.two');
      expect(r.isErr, true);
      expect(r.unwrapErr(), isA<InvalidCredentialsFailure>());
    });

    test('rechaza payload no decodificable', () {
      final r = JwtToken.tryParse('aaa.???.bbb');
      expect(r.isErr, true);
    });
  });
}
