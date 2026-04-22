/// Entidad de dominio que representa un viaje registrado.
///
/// Es inmutable. Los campos [serverId] y [paymentMethod] son opcionales
/// porque un viaje pendiente (local) aún no tiene ID de servidor ni método
/// de pago asignado.
class TripRecord {
  final int? serverId;
  final String line;
  final String destination;
  final String stopName;
  final int stopId;
  final DateTime timestamp;
  final bool confirmed;
  final String? paymentMethod; // 'card', 'cash', null

  const TripRecord({
    this.serverId,
    required this.line,
    required this.destination,
    required this.stopName,
    required this.stopId,
    required this.timestamp,
    this.confirmed = false,
    this.paymentMethod,
  });

  Map<String, dynamic> toJson() => {
    'line': line,
    'destination': destination,
    'stopName': stopName,
    'stopId': stopId,
    'timestamp': timestamp.toIso8601String(),
    'confirmed': confirmed,
    'paymentMethod': paymentMethod,
  };

  factory TripRecord.fromJson(Map<String, dynamic> json) => TripRecord(
    serverId: json['id'] as int?,
    line: json['line'] ?? '',
    destination: json['destination'] ?? '',
    stopName: json['stopName'] ?? '',
    stopId: json['stopId'] ?? 0,
    timestamp: DateTime.parse(json['timestamp']),
    confirmed: json['confirmed'] ?? false,
    paymentMethod: json['paymentMethod'],
  );

  @override
  String toString() =>
      'TripRecord(line=$line, stop=$stopName, confirmed=$confirmed)';
}
