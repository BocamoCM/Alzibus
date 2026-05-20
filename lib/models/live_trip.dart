/// Modelo de un viaje compartido en vivo. Refleja la respuesta del backend
/// (endpoints `/api/live-trips/*`).
class LiveTrip {
  final String id;
  final String shareToken;
  final String? shareUrl;
  final String? line;
  final int? originStopId;
  final String? originStopName;
  final int? destinationStopId;
  final String? destinationStopName;
  final double? destinationLat;
  final double? destinationLng;
  final double? lastLat;
  final double? lastLng;
  final DateTime? lastPingAt;
  final int? etaMin;
  final DateTime startedAt;
  final DateTime? endedAt;
  final DateTime? expiresAt;
  final LiveTripStatus status;

  const LiveTrip({
    required this.id,
    required this.shareToken,
    required this.startedAt,
    required this.status,
    this.shareUrl,
    this.line,
    this.originStopId,
    this.originStopName,
    this.destinationStopId,
    this.destinationStopName,
    this.destinationLat,
    this.destinationLng,
    this.lastLat,
    this.lastLng,
    this.lastPingAt,
    this.etaMin,
    this.endedAt,
    this.expiresAt,
  });

  bool get isActive => status == LiveTripStatus.active;

  /// Devuelve una copia con los campos sobrescritos. Útil para preservar
  /// `shareUrl` cuando un ping update no lo trae (backends antiguos).
  LiveTrip copyWith({
    String? shareUrl,
    double? lastLat,
    double? lastLng,
    DateTime? lastPingAt,
    int? etaMin,
  }) {
    return LiveTrip(
      id: id,
      shareToken: shareToken,
      shareUrl: shareUrl ?? this.shareUrl,
      line: line,
      originStopId: originStopId,
      originStopName: originStopName,
      destinationStopId: destinationStopId,
      destinationStopName: destinationStopName,
      destinationLat: destinationLat,
      destinationLng: destinationLng,
      lastLat: lastLat ?? this.lastLat,
      lastLng: lastLng ?? this.lastLng,
      lastPingAt: lastPingAt ?? this.lastPingAt,
      etaMin: etaMin ?? this.etaMin,
      startedAt: startedAt,
      endedAt: endedAt,
      expiresAt: expiresAt,
      status: status,
    );
  }

  factory LiveTrip.fromJson(Map<String, dynamic> json) {
    return LiveTrip(
      id: json['id'] as String,
      shareToken: json['shareToken'] as String,
      shareUrl: json['shareUrl'] as String?,
      line: json['line'] as String?,
      originStopId: json['originStopId'] as int?,
      originStopName: json['originStopName'] as String?,
      destinationStopId: json['destinationStopId'] as int?,
      destinationStopName: json['destinationStopName'] as String?,
      destinationLat: (json['destinationLat'] as num?)?.toDouble(),
      destinationLng: (json['destinationLng'] as num?)?.toDouble(),
      lastLat: (json['lastLat'] as num?)?.toDouble(),
      lastLng: (json['lastLng'] as num?)?.toDouble(),
      lastPingAt: _parseDate(json['lastPingAt']),
      etaMin: json['etaMin'] as int?,
      startedAt: _parseDate(json['startedAt']) ?? DateTime.now(),
      endedAt: _parseDate(json['endedAt']),
      expiresAt: _parseDate(json['expiresAt']),
      status: LiveTripStatusX.fromString(json['status'] as String? ?? 'active'),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}

/// Entrada del histórico de viajes compartidos. Versión reducida del modelo
/// — solo lo que la lista necesita.
class LiveTripHistoryEntry {
  final String id;
  final String shareToken;
  final String? line;
  final String? destinationStopName;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationMin;
  final LiveTripStatus status;

  const LiveTripHistoryEntry({
    required this.id,
    required this.shareToken,
    required this.startedAt,
    required this.status,
    this.line,
    this.destinationStopName,
    this.endedAt,
    this.durationMin,
  });

  factory LiveTripHistoryEntry.fromJson(Map<String, dynamic> json) {
    return LiveTripHistoryEntry(
      id: json['id'] as String,
      shareToken: json['shareToken'] as String,
      line: json['line'] as String?,
      destinationStopName: json['destinationStopName'] as String?,
      startedAt:
          DateTime.tryParse(json['startedAt'] as String? ?? '') ?? DateTime.now(),
      endedAt: json['endedAt'] != null
          ? DateTime.tryParse(json['endedAt'] as String)
          : null,
      durationMin: json['durationMin'] as int?,
      status: LiveTripStatusX.fromString(json['status'] as String? ?? 'ended'),
    );
  }
}

enum LiveTripStatus { active, ended, expired }

extension LiveTripStatusX on LiveTripStatus {
  static LiveTripStatus fromString(String s) => switch (s) {
        'active' => LiveTripStatus.active,
        'ended' => LiveTripStatus.ended,
        'expired' => LiveTripStatus.expired,
        _ => LiveTripStatus.active,
      };

  String get label => switch (this) {
        LiveTripStatus.active => 'En marcha',
        LiveTripStatus.ended => 'Finalizado',
        LiveTripStatus.expired => 'Caducado',
      };
}
