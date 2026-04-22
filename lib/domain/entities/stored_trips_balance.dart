/// Estado local de los viajes almacenados en la app (persistido en
/// SharedPreferences). Es lo que se muestra en el contador grande de la
/// pantalla NFC cuando no hay tarjeta escaneada.
class StoredTripsBalance {
  /// Viajes restantes almacenados localmente.
  final int trips;

  /// `true` si el usuario tiene bono ilimitado (se ignora [trips]).
  final bool isUnlimited;

  /// UID de la última tarjeta leída, útil para recordar al usuario cuál es
  /// «su» tarjeta.
  final String? lastCardUid;

  const StoredTripsBalance({
    this.trips = 0,
    this.isUnlimited = false,
    this.lastCardUid,
  });

  StoredTripsBalance copyWith({
    int? trips,
    bool? isUnlimited,
    String? lastCardUid,
  }) =>
      StoredTripsBalance(
        trips: trips ?? this.trips,
        isUnlimited: isUnlimited ?? this.isUnlimited,
        lastCardUid: lastCardUid ?? this.lastCardUid,
      );
}

/// Configuración del aviso de saldo bajo.
class LowBalanceSettings {
  final bool warningsEnabled;
  final int threshold;

  const LowBalanceSettings({
    this.warningsEnabled = true,
    this.threshold = 5,
  });

  LowBalanceSettings copyWith({bool? warningsEnabled, int? threshold}) =>
      LowBalanceSettings(
        warningsEnabled: warningsEnabled ?? this.warningsEnabled,
        threshold: threshold ?? this.threshold,
      );
}
