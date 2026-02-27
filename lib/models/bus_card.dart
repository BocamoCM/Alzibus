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
    required this.isUnlimited,
    this.lastUse,
    this.tripHistory = const [],
  });

  /// Saldo formateado en euros
  String get balanceFormatted => isUnlimited ? 'Ilimitado' : '${(balance / 100).toStringAsFixed(2)}€';

  /// ¿La tarjeta tiene viajes ilimitados?
  /// Se detecta si el precio por viaje es 0 o si tiene el flag de ilimitado (byte 6)
  final bool isUnlimited;

  /// Tipo de tarjeta como texto
  String get cardTypeName {
    switch (cardType) {
      case 1: return 'Bono 10 viajes';
      case 2: return 'Bono 20 viajes';
      case 3: return 'Bono mensual';
      case 4: return 'Bono estudiante';
      case 5: return 'Bono Ilimitado';
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
    bool isUnlimited = false;
    final tripHistory = <TripRecord>[];

    // Leer saldo real de Block 8 (Value Block - Little Endian)
    if (blocks.length > 8 && blocks[8].length >= 16) {
      final block8 = blocks[8];
      balance = block8[0] | (block8[1] << 8) | (block8[2] << 16) | (block8[3] << 24);
      
      // Calcular viajes (Tarifa 1.50€, Remanente 0.50€)
      if (balance >= 50) {
        trips = (balance - 50) ~/ 150;
      }
    }

    // Leer tipo de tarjeta de Block 5
    if (blocks.length > 5 && blocks[5].length >= 16) {
      final block5 = blocks[5];
      cardType = block5[1]; // Tipo de bono
      
      // La tarjeta es ilimitada si el precio/viaje (bytes 2-3) es 0 
      // o si el byte 6 tiene el flag de ilimitado (0x01)
      if ((block5[2] == 0 && block5[3] == 0) || block5[6] == 0x01) {
        isUnlimited = true;
        cardType = 5; // Forzar tipo ilimitado
      }
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
      isUnlimited: isUnlimited,
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
