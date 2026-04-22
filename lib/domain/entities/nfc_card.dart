/// Entidad de dominio que representa una tarjeta NFC del bus de Alzira
/// (Mifare Classic 1K).
///
/// Es inmutable y totalmente independiente de `nfc_manager`, `MethodChannel`
/// o cualquier plugin. Los adaptadores de infraestructura son responsables de
/// mapear los bloques crudos de la tarjeta a esta entidad.
class NfcCard {
  /// UID de la tarjeta en formato `AA:BB:CC:DD` mayúsculas.
  final String uid;

  /// Saldo en céntimos de euro. `0` cuando es ilimitado o vacío.
  final int balanceCents;

  /// Número de viajes restantes. Se deriva del saldo en la mayoría de bonos.
  final int trips;

  /// Tipo de bono según el byte 1 del bloque 5.
  /// 1 = Bono 10, 2 = Bono 20, 3 = Mensual, 4 = Estudiante, 5 = Ilimitado.
  final int cardType;

  /// `true` si la tarjeta es de viajes ilimitados (bono mensual, estudiante…).
  final bool isUnlimited;

  /// Fecha del último uso decodificada desde los bytes 10-13 del bloque 5.
  final DateTime? lastUse;

  /// Historial de viajes leídos desde los bloques 20-26.
  final List<NfcTripRecord> tripHistory;

  const NfcCard({
    required this.uid,
    required this.balanceCents,
    required this.trips,
    required this.cardType,
    required this.isUnlimited,
    this.lastUse,
    this.tripHistory = const [],
  });

  /// Saldo formateado en euros para la UI.
  String get balanceFormatted =>
      isUnlimited ? 'Ilimitado' : '${(balanceCents / 100).toStringAsFixed(2)}€';

  /// Nombre del tipo de bono.
  String get cardTypeName {
    switch (cardType) {
      case 1:
        return 'Bono 10 viajes';
      case 2:
        return 'Bono 20 viajes';
      case 3:
        return 'Bono mensual';
      case 4:
        return 'Bono estudiante';
      case 5:
        return 'Bono Ilimitado';
      default:
        return 'Tarjeta estándar';
    }
  }

  NfcCard copyWith({
    String? uid,
    int? balanceCents,
    int? trips,
    int? cardType,
    bool? isUnlimited,
    DateTime? lastUse,
    List<NfcTripRecord>? tripHistory,
  }) {
    return NfcCard(
      uid: uid ?? this.uid,
      balanceCents: balanceCents ?? this.balanceCents,
      trips: trips ?? this.trips,
      cardType: cardType ?? this.cardType,
      isUnlimited: isUnlimited ?? this.isUnlimited,
      lastUse: lastUse ?? this.lastUse,
      tripHistory: tripHistory ?? this.tripHistory,
    );
  }

  @override
  String toString() =>
      'NfcCard(uid=$uid, balance=$balanceFormatted, trips=$trips, type=$cardTypeName)';
}

/// Registro de un viaje leído directamente del chip Mifare.
///
/// Nótese que esto NO es `TripRecord` del dominio de viajes — esa entidad
/// representa un viaje sincronizado con el backend, mientras que éste es un
/// evento puramente local decodificado de los bloques 20-26 de la tarjeta.
class NfcTripRecord {
  final int lineCode;
  final int stopCode;
  final DateTime timestamp;
  final int fareCents;

  const NfcTripRecord({
    required this.lineCode,
    required this.stopCode,
    required this.timestamp,
    required this.fareCents,
  });

  String get lineName => 'L$lineCode';
  String get fareFormatted => '${(fareCents / 100).toStringAsFixed(2)}€';
}
