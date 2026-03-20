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
import 'tts_provider.dart';
import '../../services/ad_service.dart';
import 'ad_provider.dart';
import '../../constants/app_config.dart';

class NfcState {
  final String status;
  final bool scanning;
  final BusCard? cardData;
  final int storedTrips;
  final bool isUnlimited;
  final String? lastCardUid;
  final bool nfcAvailable;
  final bool lowBalanceWarningsEnabled;
  final int lowBalanceThreshold;

  const NfcState({
    this.status = 'Acerca tu tarjeta para leer el saldo',
    this.scanning = false,
    this.cardData,
    this.storedTrips = 0,
    this.isUnlimited = false,
    this.lastCardUid,
    this.nfcAvailable = true,
    this.lowBalanceWarningsEnabled = true,
    this.lowBalanceThreshold = 5,
  });

  NfcState copyWith({
    String? status,
    bool? scanning,
    BusCard? cardData,
    int? storedTrips,
    bool? isUnlimited,
    String? lastCardUid,
    bool? nfcAvailable,
    bool? lowBalanceWarningsEnabled,
    int? lowBalanceThreshold,
  }) {
    return NfcState(
      status: status ?? this.status,
      scanning: scanning ?? this.scanning,
      cardData: cardData ?? this.cardData,
      storedTrips: storedTrips ?? this.storedTrips,
      isUnlimited: isUnlimited ?? this.isUnlimited,
      lastCardUid: lastCardUid ?? this.lastCardUid,
      nfcAvailable: nfcAvailable ?? this.nfcAvailable,
      lowBalanceWarningsEnabled: lowBalanceWarningsEnabled ?? this.lowBalanceWarningsEnabled,
      lowBalanceThreshold: lowBalanceThreshold ?? this.lowBalanceThreshold,
    );
  }
}

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
    final isAvailable = await NfcManager.instance.isAvailable();
    state = state.copyWith(
      nfcAvailable: isAvailable,
      status: isAvailable ? state.status : 'NFC no disponible en este dispositivo',
    );
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final isUnlimited = prefs.getBool('is_unlimited') ?? false;
    final storedTrips = prefs.getInt('stored_trips') ?? 0;
    
    String initialStatus = state.status;
    if (isUnlimited) {
      initialStatus = 'Tienes viajes ILIMITADOS';
    } else if (storedTrips > 0) {
      initialStatus = 'Tienes $storedTrips viajes guardados';
    }

    _scanCounter = prefs.getInt('nfc_scan_count') ?? 0;

    state = state.copyWith(
      lowBalanceWarningsEnabled: prefs.getBool('low_balance_warnings') ?? true,
      lowBalanceThreshold: prefs.getInt('low_balance_threshold') ?? 5,
      storedTrips: storedTrips,
      isUnlimited: isUnlimited,
      lastCardUid: prefs.getString('last_card_uid'),
      status: initialStatus,
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
    if (state.storedTrips <= 0) {
      return -1; // Not enough trips
    }

    final newTrips = state.storedTrips - 1;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('stored_trips', newTrips);
    
    BusCard? newCardData;
    if (state.cardData != null) {
      newCardData = BusCard(
        uid: state.cardData!.uid,
        balance: state.cardData!.balance,
        trips: newTrips,
        cardType: state.cardData!.cardType,
        isUnlimited: state.cardData!.isUnlimited,
      );
    }
    
    state = state.copyWith(
      storedTrips: newTrips,
      cardData: newCardData,
    );

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

    state = state.copyWith(
      scanning: true,
      status: 'Acerca tu tarjeta al teléfono...',
      cardData: null,
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

  Future<void> _saveTrips(int trips, String uid, bool isUnlimited, Function(String text) onVoiceAnnounce) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('stored_trips', trips);
    await prefs.setString('last_card_uid', uid);
    await prefs.setBool('is_unlimited', isUnlimited);
    
    state = state.copyWith(
      isUnlimited: isUnlimited,
    );
    
    onVoiceAnnounce("trigger"); // Special keyword, UI will decode the localizations.
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
            );
            
            state = state.copyWith(
              status: cardData.isUnlimited ? 'Bono Ilimitado Detectado' : 'Tarjeta leída correctamente',
              cardData: cardData,
              storedTrips: trips,
              isUnlimited: cardData.isUnlimited,
              scanning: false,
            );
            
            await _saveTrips(trips, uid, cardData.isUnlimited, onVoiceAnnounce);
            await _checkLowBalance(trips);

            final prefs = await SharedPreferences.getInstance();
            _scanCounter++;
            await prefs.setInt('nfc_scan_count', _scanCounter);

            if (AppConfig.showAds && _scanCounter % 5 == 1) {
              ref.read(adServiceProvider).showInterstitialAd();
            }
          } else {
            state = state.copyWith(
              status: 'Error al leer bloques de la tarjeta',
              scanning: false,
            );
          }
        } catch (e) {
          debugPrint('Error en lectura multi-sector: $e');
          state = state.copyWith(
            status: 'Error de comunicación con la tarjeta',
            scanning: false,
          );
        }
      } else {
        uid ??= 'Desconocido';
        state = state.copyWith(
          status: 'Tarjeta detectada (no es Mifare Classic)',
          cardData: BusCard(uid: uid, balance: 0, trips: 0, cardType: 0, isUnlimited: false),
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
