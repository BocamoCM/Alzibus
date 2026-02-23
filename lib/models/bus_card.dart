/// Modelo para tarjeta de bus NFC Mifare Classic
class BusCard {
  final String uid;
  final int balance; // En céntimos
  final int trips;
  final int cardType;
  final DateTime? lastUse;
  final List<TripRecord> tripHistory;

  BusCard({
    required this.uid,
    required this.balance,
    required this.trips,
    required this.cardType,
    this.lastUse,
    this.tripHistory = const [],
  });

  /// Saldo formateado en euros
  String get balanceFormatted => '${(balance / 100).toStringAsFixed(2)}€';

  /// Tipo de tarjeta como texto
  String get cardTypeName {
    switch (cardType) {
      case 1: return 'Bono 10 viajes';
      case 2: return 'Bono 20 viajes';
      case 3: return 'Bono mensual';
      case 4: return 'Bono estudiante';
      default: return 'Tarjeta estándar';
    }
  }

  /// Parsear datos desde bloques Mifare Classic
  factory BusCard.fromMifareBlocks(String uid, List<List<int>> blocks) {
    // Block 5/6 contiene datos actuales (duplicado como backup)
    // Block 22 contiene el registro más reciente
    // Block 8 parece ser un contador de transacciones

    int balance = 0;
    int trips = 0;
    int cardType = 0;
    final tripHistory = <TripRecord>[];

    // Intentar leer de Block 5 (o 6 como backup)
    if (blocks.length > 5 && blocks[5].length >= 16) {
      final block5 = blocks[5];
      // Bytes 0-1: tipo de tarjeta/bono
      cardType = (block5[0] << 8) | block5[1];
      // Bytes 2-3: saldo en céntimos (big endian)
      balance = (block5[2] << 8) | block5[3];
      // Byte 8: viajes restantes
      trips = block5[8];
    }

    // Leer historial de viajes de bloques 20-26
    for (int i = 20; i <= 26; i++) {
      if (blocks.length > i && blocks[i].length >= 16) {
        final block = blocks[i];
        // Verificar si tiene datos (no todo ceros)
        if (block.any((b) => b != 0)) {
          final record = TripRecord.fromBlock(block);
          if (record != null) {
            tripHistory.add(record);
          }
        }
      }
    }

    return BusCard(
      uid: uid,
      balance: balance,
      trips: trips,
      cardType: cardType,
      tripHistory: tripHistory,
    );
  }

  /// Decodificar desde dump hexadecimal (formato Flipper Zero)
  factory BusCard.fromFlipperDump(String dumpContent) {
    String uid = '';
    final blocks = <List<int>>[];

    for (final line in dumpContent.split('\n')) {
      if (line.startsWith('UID:')) {
        uid = line.substring(4).trim().replaceAll(' ', '');
      } else if (line.startsWith('Block ')) {
        final parts = line.split(':');
        if (parts.length == 2) {
          final hexBytes = parts[1].trim().split(' ');
          final bytes = hexBytes
              .where((h) => h.isNotEmpty && h != '??')
              .map((h) => int.tryParse(h, radix: 16) ?? 0)
              .toList();
          blocks.add(bytes);
        }
      }
    }

    return BusCard.fromMifareBlocks(uid, blocks);
  }

  @override
  String toString() {
    return 'BusCard(uid: $uid, balance: $balanceFormatted, trips: $trips, type: $cardTypeName)';
  }
}

/// Registro de un viaje individual
class TripRecord {
  final int lineCode;
  final int stopCode;
  final DateTime timestamp;
  final int fare; // En céntimos

  TripRecord({
    required this.lineCode,
    required this.stopCode,
    required this.timestamp,
    required this.fare,
  });

  /// Parsear desde un bloque de 16 bytes
  static TripRecord? fromBlock(List<int> block) {
    if (block.length < 16 || block.every((b) => b == 0)) {
      return null;
    }

    try {
      // Estructura estimada basada en análisis:
      // Bytes 0-1: tipo operación
      // Bytes 2-3: importe
      // Bytes 4-5: código de línea/parada
      // Bytes 10-13: fecha/hora codificada

      final fare = (block[2] << 8) | block[3];
      final lineCode = block[4];
      final stopCode = block[8];

      // Fecha codificada (bytes 10-13 parecen contener timestamp)
      // Formato: parece ser días desde época + hora
      final dateBytes = (block[10] << 8) | block[11];
      
      // Aproximación: usar fecha actual si no se puede decodificar
      final timestamp = DateTime.now();

      return TripRecord(
        lineCode: lineCode,
        stopCode: stopCode,
        timestamp: timestamp,
        fare: fare,
      );
    } catch (e) {
      return null;
    }
  }

  String get lineName => 'L$lineCode';
  String get fareFormatted => '${(fare / 100).toStringAsFixed(2)}€';
}
