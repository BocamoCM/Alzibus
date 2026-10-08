import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';

/// Cliente del API `/game/*` — monedas y skins del jugador en el servidor.
///
/// Diseño offline-first: el cliente trabaja con su valor local. Estas
/// llamadas se hacen "best effort" — si fallan (sin red), el código que
/// las llama debe ignorar el error silenciosamente y reintentar más tarde.
class GameService {
  /// Devuelve el estado completo del usuario (monedas + skins poseídos).
  /// Útil al arrancar la app para reconciliar con el local.
  Future<({int coins, List<String> ownedSkins})> getState() async {
    final res = await ApiClient().dio.get('/game/state');
    if (res.statusCode != 200) {
      throw GameServiceException('GET state ${res.statusCode}: ${res.data}');
    }
    final data = _asMap(res.data);
    return (
      coins: (data['coins'] as num?)?.toInt() ?? 0,
      ownedSkins: ((data['ownedSkins'] as List?) ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  /// Sincroniza monedas. El servidor devuelve el MAYOR entre cliente y
  /// servidor (gana el más alto). El cliente debe actualizar su local con
  /// el valor devuelto si difiere.
  Future<int> syncCoins(int localCoins) async {
    final res = await ApiClient().dio.post(
      '/game/coins/sync',
      data: {'coins': localCoins},
    );
    if (res.statusCode != 200) {
      throw GameServiceException(
          'POST coins/sync ${res.statusCode}: ${res.data}');
    }
    return (_asMap(res.data)['coins'] as num).toInt();
  }

  /// COMPRA server-authoritative de una skin. Resuelve el fallo por el que
  /// el gasto se revertía solo (el cliente restaba en local y luego el sync
  /// max-wins le devolvía el saldo viejo → skins gratis).
  ///
  /// Envía el saldo local ([localCoins]) para que las monedas ganadas
  /// offline cuenten; el servidor cobra el coste (que decide él) de forma
  /// atómica y devuelve el estado AUTORITATIVO (saldo ya descontado +
  /// skins poseídos). El llamador debe adoptar ese estado en local.
  ///
  /// Requiere conexión: si falla la red lanza excepción y la compra NO se
  /// realiza (correcto — no queremos volver a la ilusión local que se
  /// revertía). Lanza [GameServiceException] también si el saldo es
  /// insuficiente (el backend responde 400).
  Future<({int coins, List<String> ownedSkins})> purchaseSkin(
    String skinId,
    int localCoins,
  ) async {
    final res = await ApiClient().dio.post(
      '/game/skins/purchase',
      data: {'skinId': skinId, 'coins': localCoins},
    );
    if (res.statusCode != 200) {
      throw GameServiceException(
          'POST skins/purchase ${res.statusCode}: ${res.data}');
    }
    final data = _asMap(res.data);
    return (
      coins: (data['coins'] as num?)?.toInt() ?? 0,
      ownedSkins: ((data['ownedSkins'] as List?) ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  /// Sincroniza skins poseídos. El servidor hace UNIÓN (preserva ambos sets).
  Future<List<String>> syncOwnedSkins(List<String> localSkins) async {
    final res = await ApiClient().dio.post(
      '/game/skins/sync',
      data: {'ownedSkins': localSkins},
    );
    if (res.statusCode != 200) {
      throw GameServiceException(
          'POST skins/sync ${res.statusCode}: ${res.data}');
    }
    final list = (_asMap(res.data)['ownedSkins'] as List?) ?? [];
    return list.map((e) => e.toString()).toList();
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw GameServiceException('Respuesta inesperada: $data');
  }
}

class GameServiceException implements Exception {
  final String message;
  GameServiceException(this.message);
  @override
  String toString() => 'GameServiceException: $message';

  /// Helper para logs: no contaminar release con stack traces de fallos
  /// de red esperables.
  void debugLog() {
    if (kDebugMode) debugPrint(toString());
  }
}
