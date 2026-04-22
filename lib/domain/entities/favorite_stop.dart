/// Entidad pura de una parada favorita.
///
/// El dominio no sabe nada de SharedPreferences ni de widgets. Serializa a
/// JSON por comodidad del adaptador de preferencias — pero cualquier otro
/// adaptador (backend, SQLite…) podría hacerlo igualmente.
class FavoriteStop {
  final int stopId;
  final String stopName;
  final double lat;
  final double lng;
  final List<String> lines;

  const FavoriteStop({
    required this.stopId,
    required this.stopName,
    required this.lat,
    required this.lng,
    required this.lines,
  });

  FavoriteStop copyWith({
    int? stopId,
    String? stopName,
    double? lat,
    double? lng,
    List<String>? lines,
  }) =>
      FavoriteStop(
        stopId: stopId ?? this.stopId,
        stopName: stopName ?? this.stopName,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        lines: lines ?? this.lines,
      );

  Map<String, dynamic> toJson() => {
        'stopId': stopId,
        'stopName': stopName,
        'lat': lat,
        'lng': lng,
        'lines': lines,
      };

  factory FavoriteStop.fromJson(Map<String, dynamic> json) => FavoriteStop(
        stopId: json['stopId'] as int,
        stopName: json['stopName'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        lines: List<String>.from(json['lines'] as List),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FavoriteStop &&
          other.stopId == stopId &&
          other.stopName == stopName &&
          other.lat == lat &&
          other.lng == lng);

  @override
  int get hashCode => Object.hash(stopId, stopName, lat, lng);
}

/// Snapshot de la info en tiempo real que se muestra en el widget.
class FavoriteWidgetSnapshot {
  final String stopName;
  final String lineDestination;
  final String arrivalTime;
  final String lastUpdate;

  const FavoriteWidgetSnapshot({
    required this.stopName,
    required this.lineDestination,
    required this.arrivalTime,
    required this.lastUpdate,
  });

  /// Estado por defecto cuando aún no hay parada favorita asignada.
  factory FavoriteWidgetSnapshot.empty() => const FavoriteWidgetSnapshot(
        stopName: 'Sin parada favorita',
        lineDestination: 'Añade una desde la app',
        arrivalTime: '--',
        lastUpdate: '--:--',
      );
}
