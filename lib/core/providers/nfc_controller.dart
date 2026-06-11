import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/src/nfc_manager_android/tags/nfc_a.dart';
import 'package:nfc_manager/src/nfc_manager_android/tags/iso_dep.dart';
import 'package:nfc_manager/src/nfc_manager_android/tags/mifare_classic.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import '../../models/bus_card.dart';
import '../../services/suma_parser.dart';
import 'tts_provider.dart';
import '../../services/ad_service.dart';
import 'ad_provider.dart';
import '../../constants/app_config.dart';

/// Estado del flujo NFC. Ahora soporta **dos slots** de tarjeta:
///
/// * [alziraCard]    → tarjeta del bus de Alzira (o ilimitada).
/// * [sumaCard]      → tarjeta SUMA 10 de la ATMV.
/// * [selectedSlot]  → 0 = Alzira, 1 = SUMA. Determina qué tarjeta se
///                     muestra al frente y sobre cuál opera `validateTrip`.
///
/// Para mantener compat con la UI y el resto del código, `cardData`,
/// `storedTrips`, `isUnlimited` y `lastCardUid` siguen existiendo como
/// **getters derivados** de la tarjeta seleccionada — no como campos
/// independientes.
class NfcState {
  final String status;
  final bool scanning;
  final BusCard? alziraCard;
  final BusCard? sumaCard;
  final int selectedSlot;
  final bool nfcAvailable;
  final bool lowBalanceWarningsEnabled;
  final int lowBalanceThreshold;

  const NfcState({
    this.status = 'Acerca tu tarjeta para leer el saldo',
    this.scanning = false,
    this.alziraCard,
    this.sumaCard,
    this.selectedSlot = 0,
    this.nfcAvailable = true,
    this.lowBalanceWarningsEnabled = true,
    this.lowBalanceThreshold = 5,
  });

  /// La tarjeta seleccionada (delante). `null` si ese slot aún está vacío.
  BusCard? get cardData => selectedSlot == 1 ? sumaCard : alziraCard;

  int get storedTrips => cardData?.trips ?? 0;
  bool get isUnlimited => cardData?.isUnlimited ?? false;
  String? get lastCardUid => cardData?.uid;

  /// Las tarjetas que existen, en orden Alzira → SUMA. Útil para el
  /// CardStack: tamaño 0/1/2.
  List<BusCard> get cards => [
        if (alziraCard != null) alziraCard!,
        if (sumaCard != null) sumaCard!,
      ];

  /// Índice de la tarjeta seleccionada **dentro de [cards]** (la lista
  /// filtrada). Sirve para que el widget de pila sepa cuál está delante.
  int get displayIndex {
    final list = cards;
    if (list.isEmpty) return 0;
    final selected = cardData;
    if (selected == null) return 0;
    final idx = list.indexOf(selected);
    return idx < 0 ? 0 : idx;
  }

  NfcState copyWith({
    String? status,
    bool? scanning,
    Object? alziraCard = _sentinel,
    Object? sumaCard = _sentinel,
    int? selectedSlot,
    bool? nfcAvailable,
    bool? lowBalanceWarningsEnabled,
    int? lowBalanceThreshold,
  }) {
    return NfcState(
      status: status ?? this.status,
      scanning: scanning ?? this.scanning,
      // `_sentinel` distingue "no se ha pasado" de "se ha pasado null".
      // Para poder explícitamente vaciar un slot hacemos falta este truco;
      // si copyWith usase `??` no podríamos limpiar la tarjeta tras logout.
      alziraCard: identical(alziraCard, _sentinel) ? this.alziraCard : alziraCard as BusCard?,
      sumaCard: identical(sumaCard, _sentinel) ? this.sumaCard : sumaCard as BusCard?,
      selectedSlot: selectedSlot ?? this.selectedSlot,
      nfcAvailable: nfcAvailable ?? this.nfcAvailable,
      lowBalanceWarningsEnabled: lowBalanceWarningsEnabled ?? this.lowBalanceWarningsEnabled,
      lowBalanceThreshold: lowBalanceThreshold ?? this.lowBalanceThreshold,
    );
  }
}

const Object _sentinel = Object();

class BusCardKeys {
  static final Map<int, Uint8List> keyA = {
    0: Uint8List.fromList([0xBC, 0x93, 0x33, 0xB1, 0xBB, 0x6E]),
    1: Uint8List.fromList([0xDF, 0xED, 0x7C, 0x26, 0xBF, 0x1B]),
    2: Uint8List.fromList([0x17, 0x5B, 0x77, 0xCD, 0x00, 0x97]),
    3: Uint8List.fromList([0xE4, 0xBC, 0xDF, 0x37, 0x24, 0x03]),
    4: Uint8List.fromList([0xE4, 0x74, 0xDF, 0x44, 0x8D, 0x37]),
    5: Uint8List.fromList([0x39, 0x8E, 0xA4, 0xFE, 0x52, 0x06]),
    6: Uint8List.fromList([0xF2, 0x0C, 0x09, 0x4B, 0xDB, 0x31]),
    7: Uint8List.fromList([0x1C, 0x93, 0x8B, 0xA7, 0xE7, 0x0E]),
  };
  
  static final Uint8List defaultKey = Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]);
}

class NfcController extends Notifier<NfcState> {
  final FlutterLocalNotificationsPlugin _notif = FlutterLocalNotificationsPlugin();
  int _scanCounter = 0;

  @override
  NfcState build() {
    _initNotifications();
    _checkNfcAvailability();
    _loadPreferences();
    return const NfcState();
  }

  Future<void> _initNotifications() async {
    const android = AndroidInitializationSettings('@drawable/ic_launcher_foreground');
    const initSettings = InitializationSettings(android: android);
    await _notif.initialize(initSettings);
  }

  Future<void> _checkNfcAvailability() async {
    // checkAvailability sustituyó a isAvailable en nfc_manager 4.1.0
    // PERO ya no devuelve bool — devuelve un enum NfcAvailability con
    // tres valores: enabled / disabled / unsupported. Para mantener la
    // semántica del flag interno bool comparamos contra .enabled
    // (equivalente al antiguo true). Si el NFC está físicamente presente
    // pero apagado (disabled) o el dispositivo no tiene NFC (unsupported),
    // contaba como false antes y sigue contando como false ahora.
    final availability = await NfcManager.instance.checkAvailability();
    final isAvailable = availability == NfcAvailability.enabled;
    state = state.copyWith(
      nfcAvailable: isAvailable,
      status: isAvailable ? state.status : 'NFC no disponible en este dispositivo',
    );
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _scanCounter = prefs.getInt('nfc_scan_count') ?? 0;

    // ── Slot Alzira ──
    BusCard? alzira;
    final alziraUid = prefs.getString('card_alzira_uid');
    if (alziraUid != null) {
      alzira = BusCard(
        uid: alziraUid,
        balance: prefs.getInt('card_alzira_balance') ?? 0,
        trips: prefs.getInt('card_alzira_trips') ?? 0,
        cardType: prefs.getInt('card_alzira_card_type') ?? 0,
        isUnlimited: prefs.getBool('card_alzira_is_unlimited') ?? false,
        kind: BusCardKind.alzira,
      );
    } else {
      // Migración desde el formato antiguo (1 tarjeta sin slots).
      // Si existía `last_card_uid` + `stored_trips`, era una Alzira.
      final legacyUid = prefs.getString('last_card_uid');
      if (legacyUid != null) {
        alzira = BusCard(
          uid: legacyUid,
          balance: 0,
          trips: prefs.getInt('stored_trips') ?? 0,
          cardType: 0,
          isUnlimited: prefs.getBool('is_unlimited') ?? false,
          kind: BusCardKind.alzira,
        );
        // Persistimos en el nuevo formato y dejamos las claves antiguas
        // un par de releases por si hay rollback.
        await _persistAlzira(alzira, prefs);
      }
    }

    // ── Slot SUMA ──
    BusCard? suma;
    final sumaUid = prefs.getString('card_suma_uid');
    if (sumaUid != null) {
      suma = BusCard(
        uid: sumaUid,
        balance: 0,
        trips: prefs.getInt('card_suma_trips') ?? 0,
        cardType: 0,
        isUnlimited: false,
        kind: BusCardKind.sumaValencia,
        sumaZone: prefs.getString('card_suma_zone'),
        sumaZoneCode: prefs.getInt('card_suma_zone_code'),
      );
    }

    final selectedSlot = prefs.getInt('selected_slot') ?? 0;

    state = state.copyWith(
      lowBalanceWarningsEnabled: prefs.getBool('low_balance_warnings') ?? true,
      lowBalanceThreshold: prefs.getInt('low_balance_threshold') ?? 5,
      alziraCard: alzira,
      sumaCard: suma,
      selectedSlot: selectedSlot.clamp(0, 1),
      status: _statusFor(alzira: alzira, suma: suma, slot: selectedSlot),
    );
  }

  /// Texto inicial según las tarjetas presentes y el slot seleccionado.
  String _statusFor({BusCard? alzira, BusCard? suma, int slot = 0}) {
    final shown = slot == 1 ? suma : alzira;
    if (shown == null) {
      // El slot pedido está vacío: caemos al otro si existe.
      final fallback = slot == 1 ? alzira : suma;
      if (fallback == null) return 'Acerca tu tarjeta para leer el saldo';
      if (fallback.isUnlimited) return 'Tienes viajes ILIMITADOS';
      return 'Tienes ${fallback.trips} viajes guardados';
    }
    if (shown.isUnlimited) return 'Tienes viajes ILIMITADOS';
    if (shown.kind == BusCardKind.sumaValencia) {
      return 'SUMA — ${shown.trips} viajes';
    }
    return 'Tienes ${shown.trips} viajes guardados';
  }

  Future<void> _persistAlzira(BusCard card, SharedPreferences prefs) async {
    await prefs.setString('card_alzira_uid', card.uid);
    await prefs.setInt('card_alzira_trips', card.trips);
    await prefs.setInt('card_alzira_balance', card.balance);
    await prefs.setInt('card_alzira_card_type', card.cardType);
    await prefs.setBool('card_alzira_is_unlimited', card.isUnlimited);
    // Compat con código antiguo (otros sitios todavía leen estas claves).
    await prefs.setString('last_card_uid', card.uid);
    await prefs.setInt('stored_trips', card.trips);
    await prefs.setBool('is_unlimited', card.isUnlimited);
  }

  Future<void> _persistSuma(BusCard card, SharedPreferences prefs) async {
    await prefs.setString('card_suma_uid', card.uid);
    await prefs.setInt('card_suma_trips', card.trips);
    if (card.sumaZone != null) {
      await prefs.setString('card_suma_zone', card.sumaZone!);
    } else {
      await prefs.remove('card_suma_zone');
    }
    if (card.sumaZoneCode != null) {
      await prefs.setInt('card_suma_zone_code', card.sumaZoneCode!);
    }
  }

  /// Cambia la tarjeta visible (delante). Lo llama el CardStack al
  /// completar un swipe.
  Future<void> selectSlot(int slot) async {
    final clamped = slot.clamp(0, 1);
    if (clamped == state.selectedSlot) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selected_slot', clamped);
    state = state.copyWith(
      selectedSlot: clamped,
      status: _statusFor(
        alzira: state.alziraCard,
        suma: state.sumaCard,
        slot: clamped,
      ),
    );
  }

  Future<void> updatePreferences({
    required bool warningsEnabled,
    required int threshold,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('low_balance_warnings', warningsEnabled);
    await prefs.setInt('low_balance_threshold', threshold);
    state = state.copyWith(
      lowBalanceWarningsEnabled: warningsEnabled,
      lowBalanceThreshold: threshold,
    );
  }

  void speak(String text) {
    ref.read(ttsProvider).speak(text);
  }

  Future<int> validateTrip() async {
    // Solo opera sobre Alzira. Si la seleccionada es SUMA o está vacía,
    // ignora la pulsación — la UI ya deshabilita el botón en esos casos.
    final card = state.alziraCard;
    if (card == null || card.isUnlimited || card.trips <= 0) {
      return -1;
    }
    final newTrips = card.trips - 1;
    final updated = BusCard(
      uid: card.uid,
      balance: card.balance,
      trips: newTrips,
      cardType: card.cardType,
      isUnlimited: card.isUnlimited,
      kind: BusCardKind.alzira,
    );
    final prefs = await SharedPreferences.getInstance();
    await _persistAlzira(updated, prefs);

    state = state.copyWith(alziraCard: updated);

    await _checkLowBalance(newTrips);
    return newTrips;
  }

  Future<void> _checkLowBalance(int trips) async {
    if (state.lowBalanceWarningsEnabled && trips > 0 && trips <= state.lowBalanceThreshold) {
      final androidDetails = AndroidNotificationDetails(
        'alzibus-hu',
        'Alzibus (Heads-up) - Saldo',
        channelDescription: 'Avisos heads-up de saldo bajo en tarjeta',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 300, 200, 300, 200, 300]),
        ticker: 'Saldo bajo',
        styleInformation: const BigTextStyleInformation(''),
        fullScreenIntent: true,
        category: AndroidNotificationCategory.status,
        visibility: NotificationVisibility.public,
      );
      final details = NotificationDetails(android: androidDetails);
      
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        Vibration.vibrate(pattern: [0, 300, 200, 300, 200, 300]);
      }
      
      await _notif.show(
        999,
        '⚠️ Saldo bajo en tu tarjeta',
        'Te quedan solo $trips viajes. Recarga pronto tu tarjeta.',
        details,
      );
    }
  }

  Future<void> stopScan() async {
    await NfcManager.instance.stopSession();
    state = state.copyWith(
      scanning: false,
      status: 'Escaneo cancelado',
    );
  }

  Future<void> startScan({
    required Function(String text) onVoiceAnnounce,
    required VoidCallback onError,
  }) async {
    if (!state.nfcAvailable) {
      onError(); // UI can show snackbar "NFC no disponible"
      return;
    }

    // Solo marcamos que estamos escaneando — NO borramos las tarjetas
    // guardadas, así el CardStack sigue mostrando las que ya tenías
    // mientras esperas a la nueva.
    state = state.copyWith(
      scanning: true,
      status: 'Acerca tu tarjeta al teléfono...',
    );

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
        },
        onDiscovered: (NfcTag tag) async {
          await _handleTagDiscovered(tag, onVoiceAnnounce);
        },
      );
    } catch (e) {
      debugPrint('Error starting NFC session: $e');
      state = state.copyWith(
        status: 'Error al iniciar escaneo NFC',
        scanning: false,
      );
    }
  }

  /// Intenta leer la tarjeta como SUMA 10 (ATMV / Generalitat Valenciana).
  ///
  /// Solo se invoca cuando la lectura como tarjeta de Alzira ha fallado
  /// (claves distintas, bloques distintos). Autentica el sector 1 con la
  /// clave SUMA y, si el bloque 5 lleva el marcador `01 00 00 00`, extrae
  /// viajes y zona.
  Future<BusCard?> _tryReadSumaCard(
    MifareClassicAndroid mifareClassic,
    String uid,
  ) async {
    try {
      final ok = await mifareClassic.authenticateSectorWithKeyA(
        sectorIndex: 1,
        key: SumaParser.sector1KeyA,
      );
      if (!ok) return null;

      final block5 = await mifareClassic.readBlock(blockIndex: 5);
      final parsed = SumaParser.parseBlock5(block5);
      if (parsed == null) return null;

      return BusCard(
        uid: uid,
        balance: 0,
        trips: parsed.trips,
        cardType: 0,
        isUnlimited: false,
        kind: BusCardKind.sumaValencia,
        sumaZone: parsed.zoneName,
        sumaZoneCode: parsed.zoneCode,
      );
    } catch (e) {
      debugPrint('SUMA read fail: $e');
      return null;
    }
  }

  /// Guarda la tarjeta recién escaneada en su slot y la activa como
  /// seleccionada. Cada tipo va a su slot, así puedes tener Alzira + SUMA
  /// guardadas a la vez y cambiar entre ellas deslizando.
  Future<void> _storeReadCard(BusCard card, Function(String text) onVoiceAnnounce) async {
    final prefs = await SharedPreferences.getInstance();
    if (card.kind == BusCardKind.sumaValencia) {
      await _persistSuma(card, prefs);
      await prefs.setInt('selected_slot', 1);
      state = state.copyWith(sumaCard: card, selectedSlot: 1);
    } else {
      await _persistAlzira(card, prefs);
      await prefs.setInt('selected_slot', 0);
      state = state.copyWith(alziraCard: card, selectedSlot: 0);
    }
    onVoiceAnnounce('trigger'); // Special keyword, UI will decode the localizations.
  }

  Future<void> _handleTagDiscovered(NfcTag tag, Function(String text) onVoiceAnnounce) async {
    try {
      String? uid;
      
      final nfca = NfcAAndroid.from(tag);
      if (nfca != null) {
        uid = nfca.tag.id.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':').toUpperCase();
      }
      
      if (uid == null) {
        final isodep = IsoDepAndroid.from(tag);
        if (isodep != null) {
          uid = isodep.tag.id.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':').toUpperCase();
        }
      }
      
      final mifareClassic = MifareClassicAndroid.from(tag);
      BusCard? cardData;
      
      if (mifareClassic != null) {
        if (uid == null) {
          uid = mifareClassic.tag.id.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':').toUpperCase();
        }
        
        Future<bool> authenticateSector(int sector, Uint8List key) async {
          try {
            return await mifareClassic.authenticateSectorWithKeyA(sectorIndex: sector, key: key);
          } catch (e) {
            try {
              return await mifareClassic.authenticateSectorWithKeyB(sectorIndex: sector, key: key);
            } catch (_) {
              return false;
            }
          }
        }

        try {
          bool authSector2 = await authenticateSector(2, BusCardKeys.keyA[2]!);
          Uint8List? block8;
          if (authSector2) {
            block8 = await mifareClassic.readBlock(blockIndex: 8);
          } else {
            if (await authenticateSector(2, BusCardKeys.defaultKey)) {
              block8 = await mifareClassic.readBlock(blockIndex: 8);
            }
          }

          bool authSector1 = await authenticateSector(1, BusCardKeys.keyA[1]!);
          Uint8List? block5;
          if (authSector1) {
            block5 = await mifareClassic.readBlock(blockIndex: 5);
          } else {
            if (await authenticateSector(1, BusCardKeys.defaultKey)) {
              block5 = await mifareClassic.readBlock(blockIndex: 5);
            }
          }

          if (block8 != null && block5 != null) {
            final balance = block8[0] | (block8[1] << 8) | (block8[2] << 16) | (block8[3] << 24);
            final cardType = block5[1];

            int trips = 0;
            if (balance >= 50) {
              trips = (balance - 50) ~/ 150;
            }

            final bool isCardUnlimited = (block5[2] == 0 && block5[3] == 0) || block5[6] == 0x01 || cardType == 5;
            cardData = BusCard(
              uid: uid,
              balance: balance,
              trips: trips,
              cardType: isCardUnlimited ? 5 : cardType,
              isUnlimited: isCardUnlimited,
              kind: BusCardKind.alzira,
            );

            state = state.copyWith(
              status: cardData.isUnlimited ? 'Bono Ilimitado Detectado' : 'Tarjeta leída correctamente',
              scanning: false,
            );

            await _storeReadCard(cardData, onVoiceAnnounce);
            await _checkLowBalance(trips);

            final prefs = await SharedPreferences.getInstance();
            _scanCounter++;
            await prefs.setInt('nfc_scan_count', _scanCounter);

            if (AppConfig.showAds && _scanCounter % 5 == 1) {
              ref.read(adServiceProvider).showInterstitialAd();
            }
          } else {
            // Fallback SUMA: si no hemos podido leer como Alzira, probamos
            // si es una tarjeta SUMA de la ATMV (Cercanías Valencia /
            // Metrovalencia). Solo necesitamos autenticar el sector 1 con
            // la clave SUMA y leer el bloque 5.
            final suma = await _tryReadSumaCard(mifareClassic, uid);
            if (suma != null) {
              state = state.copyWith(
                status: 'Tarjeta SUMA detectada',
                scanning: false,
              );
              await _storeReadCard(suma, onVoiceAnnounce);
              await _checkLowBalance(suma.trips);
            } else {
              state = state.copyWith(
                status: 'Error al leer bloques de la tarjeta',
                scanning: false,
              );
            }
          }
        } catch (e) {
          debugPrint('Error en lectura multi-sector: $e');
          state = state.copyWith(
            status: 'Error de comunicación con la tarjeta',
            scanning: false,
          );
        }
      } else {
        // Tarjeta no compatible: no la guardamos en ningún slot, solo
        // mostramos el aviso en el status.
        state = state.copyWith(
          status: 'Tarjeta detectada (no es Mifare Classic)',
          scanning: false,
        );
      }
      
      await NfcManager.instance.stopSession();
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        Vibration.vibrate(duration: 150);
      }
    } catch (e) {
      debugPrint('Error general NFC: $e');
      state = state.copyWith(
        status: 'Error en protocolo NFC',
        scanning: false,
      );
      await NfcManager.instance.stopSession();
    }
  }
}

final nfcControllerProvider = NotifierProvider<NfcController, NfcState>(() {
  return NfcController();
});
