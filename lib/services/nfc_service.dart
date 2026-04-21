import 'package:flutter/services.dart';
import '../models/bus_card.dart';

/// Servicio para leer tarjetas NFC del bus de Alzira
/// Soporta Mifare Classic 1K
class NfcService {
  static const platform = MethodChannel('com.alzibus.app/nfc');
  
  /// Estructura de la tarjeta del bus de Alzira:
  /// - Block 0: UID y datos del fabricante
  /// - Block 1-2: Datos de identificación
  /// - Block 3: Sector trailer (keys)
  /// - Block 5-6: Estado actual (duplicado como backup)
  ///   - Bytes 0-1: Tipo de bono
  ///   - Bytes 2-3: Saldo en céntimos (big endian)
  ///   - Bytes 4-5: Código de operación
  ///   - Byte 8: Número de viajes/transacciones
  ///   - Bytes 10-13: Fecha codificada
  /// - Block 8: Contador de transacciones (formato value block)
  /// - Block 20-26: Historial de transacciones

  /// Parsear tarjeta desde datos de bloques Mifare
  static BusCard? parseCard(String uid, List<Uint8List> blocks) {
    if (blocks.isEmpty) return null;

    try {
      int balance = 0;
      int trips = 0;
      int cardType = 0;
      DateTime? lastUse;
      final tripHistory = <TripRecord>[];

      // Leer saldo real de Block 8 (Value Block - Little Endian)
      if (blocks.length > 8 && blocks[8].length >= 16) {
        final block8 = blocks[8];
        // Los Value Blocks en Mifare almacenan el saldo en los primeros 4 bytes
        balance = block8[0] | (block8[1] << 8) | (block8[2] << 16) | (block8[3] << 24);
        
        // El número de viajes se deriva del saldo (Tarifa 1.50€, Remanente 0.50€)
        if (balance >= 50) {
          trips = (balance - 50) ~/ 150;
        } else {
          trips = 0;
        }
      }

      bool isUnlimited = false;

      // Leer tipo y otros metadatos de Block 5
      if (blocks.length > 5 && blocks[5].length >= 16) {
        final block5 = blocks[5];
        cardType = block5[1]; // Tipo de bono
        
        if ((block5[2] == 0 && block5[3] == 0) || block5[6] == 0x01) {
          isUnlimited = true;
          cardType = 5;
        }

        // Decodificar fecha del último uso (bytes 10-13)
        lastUse = _decodeDate(block5.sublist(10, 14));
      }

      // Leer historial de transacciones (blocks 20-26)
      for (int i = 20; i <= 26 && i < blocks.length; i++) {
        final block = blocks[i];
        if (block.length >= 16 && block.any((b) => b != 0)) {
          final record = _parseTripRecord(block);
          if (record != null) {
            tripHistory.add(record);
          }
        }
      }

      return BusCard(
        uid: uid,
        balance: balance,
        trips: trips,
        cardType: cardType,
        isUnlimited: isUnlimited,
        lastUse: lastUse,
        tripHistory: tripHistory,
      );
    } catch (e) {
      print('Error parsing bus card: $e');
      return null;
    }
  }

  /// Decodificar fecha desde 4 bytes
  /// Formato estimado: días desde época + hora
  static DateTime? _decodeDate(List<int> bytes) {
    if (bytes.length < 4) return null;
    try {
      // Los bytes parecen contener: [0x48, día, mes, año]
      // Donde 0x48 es un marcador y los siguientes son BCD
      final day = bytes[1];
      final month = bytes[2] >> 4; // Nibble alto
      final year = 2000 + (bytes[3] & 0x0F) + ((bytes[2] & 0x0F) * 10);
      
      if (day > 0 && day <= 31 && month > 0 && month <= 12) {
        return DateTime(year, month, day);
      }
    } catch (e) {
      // Fecha inválida
    }
    return null;
  }

  /// Parsear registro de viaje
  static TripRecord? _parseTripRecord(Uint8List block) {
    if (block.every((b) => b == 0)) return null;

    try {
      // Estructura observada:
      // [0-1]: Tipo operación (00 01 = viaje, 00 02 = recarga, etc.)
      // [2-3]: Importe en céntimos
      // [4-5]: Código línea/operación
      // [8]: Contador/viajes
      // [10-13]: Fecha

      final amount = (block[2] << 8) | block[3];
      final lineCode = block[4];
      final tripCount = block[8];
      
      final date = _decodeDate(block.sublist(10, 14));

      return TripRecord(
        lineCode: lineCode,
        stopCode: tripCount,
        timestamp: date ?? DateTime.now(),
        fare: amount,
      );
    } catch (e) {
      return null;
    }
  }

  /// Verificar si el dispositivo soporta NFC
  static Future<bool> isNfcAvailable() async {
    try {
      final result = await platform.invokeMethod<bool>('isNfcAvailable');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Iniciar escaneo de tarjeta NFC
  static Future<BusCard?> scanCard() async {
    try {
      final result = await platform.invokeMethod<Map>('scanNfcCard');
      if (result == null) return null;

      final uid = result['uid'] as String?;
      final blocksData = result['blocks'] as List?;
      
      if (uid == null || blocksData == null) return null;

      final blocks = blocksData
          .map((b) => Uint8List.fromList(List<int>.from(b)))
          .toList();

      return parseCard(uid, blocks);
    } catch (e) {
      print('Error scanning NFC: $e');
      return null;
    }
  }

  /// Parsear desde dump de Flipper Zero (para testing)
  static BusCard? parseFromFlipperDump(String content) {
    String uid = '';
    final blocks = <Uint8List>[];

    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      
      if (trimmed.startsWith('UID:')) {
        uid = trimmed.substring(4).trim().replaceAll(' ', '');
      } else if (trimmed.startsWith('Block ')) {
        final colonIndex = trimmed.indexOf(':');
        if (colonIndex > 0) {
          final hexPart = trimmed.substring(colonIndex + 1).trim();
          final bytes = hexPart.split(' ')
              .where((h) => h.isNotEmpty && h != '??')
              .map((h) => int.tryParse(h, radix: 16) ?? 0)
              .toList();
          blocks.add(Uint8List.fromList(bytes));
        }
      }
    }

    if (uid.isEmpty || blocks.isEmpty) return null;
    return parseCard(uid, blocks);
  }

  /// Datos de ejemplo para testing (Bus1 dump)
  static BusCard getTestCard1() {
    return BusCard(
      uid: 'DAAA08AA',
      balance: 450, // 4.50€ (cercano a 4.17€ reportado)
      trips: 27,
      cardType: 4,
      isUnlimited: false,
      lastUse: DateTime(2024, 5, 10),
      tripHistory: [
        TripRecord(lineCode: 1, stopCode: 15, timestamp: DateTime(2024, 5, 10), fare: 96),
        TripRecord(lineCode: 3, stopCode: 20, timestamp: DateTime(2024, 4, 18), fare: 96),
      ],
    );
  }

  /// Datos de ejemplo para testing (Bus2 dump)
  static BusCard getTestCard2() {
    return BusCard(
      uid: 'DAAA08AA',
      balance: 150, // 1.50€
      trips: 1,
      cardType: 1,
      isUnlimited: false,
      lastUse: DateTime(2024, 4, 25),
      tripHistory: [],
    );
  }
}
