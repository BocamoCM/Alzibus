class TripRecord {
  final int? serverId;  // ID en la base de datos del servidor
  final String line;
  final String destination;
  final String stopName;
  final int stopId;
  final DateTime timestamp;
  final bool confirmed;
  final String? paymentMethod; // 'card', 'cash', null

  TripRecord({
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
}

class TripStats {
  final Map<String, int> lineUsage; // línea -> veces usada
  final Map<String, int> stopUsage; // parada -> veces usada
  final Map<int, int> hourUsage; // hora (0-23) -> veces
  final Map<int, int> weekdayUsage; // día semana (1-7) -> veces
  final int totalTrips;

  TripStats({
    required this.lineUsage,
    required this.stopUsage,
    required this.hourUsage,
    required this.weekdayUsage,
    required this.totalTrips,
  });

  factory TripStats.fromRecords(List<TripRecord> records) {
    final lineUsage = <String, int>{};
    final stopUsage = <String, int>{};
    final hourUsage = <int, int>{};
    final weekdayUsage = <int, int>{};

    for (final record in records) {
      // Líneas
      lineUsage[record.line] = (lineUsage[record.line] ?? 0) + 1;
      
      // Paradas
      stopUsage[record.stopName] = (stopUsage[record.stopName] ?? 0) + 1;
      
      // Horas
      final hour = record.timestamp.hour;
      hourUsage[hour] = (hourUsage[hour] ?? 0) + 1;
      
      // Días de la semana
      final weekday = record.timestamp.weekday;
      weekdayUsage[weekday] = (weekdayUsage[weekday] ?? 0) + 1;
    }

    return TripStats(
      lineUsage: lineUsage,
      stopUsage: stopUsage,
      hourUsage: hourUsage,
      weekdayUsage: weekdayUsage,
      totalTrips: records.length,
    );
  }

  // Línea más usada
  String? get mostUsedLine {
    if (lineUsage.isEmpty) return null;
    return lineUsage.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  // Parada más usada
  String? get mostUsedStop {
    if (stopUsage.isEmpty) return null;
    return stopUsage.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  // Hora más frecuente
  String get mostFrequentTimeRange {
    if (hourUsage.isEmpty) return 'Sin datos';
    final peakHour = hourUsage.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
    
    if (peakHour >= 6 && peakHour < 12) return '🌅 Mañana';
    if (peakHour >= 12 && peakHour < 18) return '☀️ Tarde';
    if (peakHour >= 18 && peakHour < 22) return '🌆 Noche';
    return '🌙 Madrugada';
  }

  // Top 3 líneas
  List<MapEntry<String, int>> get topLines {
    final sorted = lineUsage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(3).toList();
  }

  // Top 3 paradas
  List<MapEntry<String, int>> get topStops {
    final sorted = stopUsage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(3).toList();
  }
  
  // Día de la semana más frecuente
  String? get mostFrequentWeekday {
    if (weekdayUsage.isEmpty) return null;
    final peakDay = weekdayUsage.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
    
    const days = ['', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    return days[peakDay];
  }
  
  // Promedio de viajes por día (en el período)
  double get averageTripsPerDay {
    if (totalTrips == 0) return 0;
    final daysWithTrips = weekdayUsage.values.fold(0, (a, b) => a + b);
    if (daysWithTrips == 0) return 0;
    return totalTrips / 7; // Promedio semanal
  }
  
  // Getter para estadísticas de días de la semana
  Map<int, int> getDayOfWeekStats() {
    return weekdayUsage;
  }
}

/// Estadísticas mensuales
class MonthlyStats {
  final int year;
  final int month;
  final int tripCount;
  final Map<String, int> lineUsage;
  
  MonthlyStats({
    required this.year,
    required this.month,
    required this.tripCount,
    required this.lineUsage,
  });
  
  String get monthName {
    const months = ['', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return months[month];
  }

  /// Etiqueta corta para el gráfico: "Ene 25", "Feb 25", etc.
  String get label => '$monthName ${year.toString().substring(2)}';
  
  String get fullMonthName {
    const months = ['', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 
                    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    return months[month];
  }
}
