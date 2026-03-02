import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/src/nfc_manager_android/tags/nfc_a.dart';
import 'package:nfc_manager/src/nfc_manager_android/tags/iso_dep.dart';
import 'package:nfc_manager/src/nfc_manager_android/tags/mifare_classic.dart';
import 'package:nfc_manager/src/nfc_manager_android/tags/tag.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'package:alzitrans/l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../models/bus_card.dart';
import '../services/tts_service.dart';

/// Claves Mifare para tarjetas de bus de Alzira
/// Extraídas de los dumps de las tarjetas reales
class BusCardKeys {
  // Claves Key A por sector (extraídas de sector trailers)
  static final Map<int, Uint8List> keyA = {
    0: Uint8List.fromList([0xBC, 0x93, 0x33, 0xB1, 0xBB, 0x6E]),  // Block 3
    1: Uint8List.fromList([0xDF, 0xED, 0x7C, 0x26, 0xBF, 0x1B]),  // Block 7 - Contiene estado actual
    2: Uint8List.fromList([0x17, 0x5B, 0x77, 0xCD, 0x00, 0x97]),  // Block 11
    3: Uint8List.fromList([0xE4, 0xBC, 0xDF, 0x37, 0x24, 0x03]),  // Block 15
    4: Uint8List.fromList([0xE4, 0x74, 0xDF, 0x44, 0x8D, 0x37]),  // Block 19
    5: Uint8List.fromList([0x39, 0x8E, 0xA4, 0xFE, 0x52, 0x06]),  // Block 23 - Historial
    6: Uint8List.fromList([0xF2, 0x0C, 0x09, 0x4B, 0xDB, 0x31]),  // Block 27
    7: Uint8List.fromList([0x1C, 0x93, 0x8B, 0xA7, 0xE7, 0x0E]),  // Block 31
  };
  
  // Clave por defecto (fallback)
  static final Uint8List defaultKey = Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]);
}

class NfcPage extends StatefulWidget {
  const NfcPage({super.key});

  @override
  State<NfcPage> createState() => _NfcPageState();
}

class _NfcPageState extends State<NfcPage> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  String _status = 'Acerca tu tarjeta para leer el saldo';
  bool _scanning = false;
  BusCard? _cardData;
  int _storedTrips = 0;
  bool _isUnlimited = false;
  String? _lastCardUid;
  bool _nfcAvailable = true;
  bool _lowBalanceWarningsEnabled = true;
  int _lowBalanceThreshold = 5;
  final FlutterLocalNotificationsPlugin _notif = FlutterLocalNotificationsPlugin();
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAnimations();
    _initNotifications();
    _loadPreferences();
    _checkNfcAvailability();
    
    // Timer para refrescar datos (por si se descuenta desde el diálogo global)
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted && !_scanning) {
        _loadPreferences();
      }
    });
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadPreferences();
    }
  }

  Future<void> _checkNfcAvailability() async {
    final isAvailable = await NfcManager.instance.isAvailable();
    setState(() {
      _nfcAvailable = isAvailable;
      if (!isAvailable) {
        _status = 'NFC no disponible en este dispositivo';
      }
    });
  }

  Future<void> _initNotifications() async {
    const android = AndroidInitializationSettings('@drawable/ic_launcher_foreground');
    const initSettings = InitializationSettings(android: android);
    await _notif.initialize(initSettings);
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lowBalanceWarningsEnabled = prefs.getBool('low_balance_warnings') ?? true;
      _lowBalanceThreshold = prefs.getInt('low_balance_threshold') ?? 5;
      _storedTrips = prefs.getInt('stored_trips') ?? 0;
      _isUnlimited = prefs.getBool('is_unlimited') ?? false;
      _lastCardUid = prefs.getString('last_card_uid');
      if (_isUnlimited) {
        _status = 'Tienes viajes ILIMITADOS';
      } else if (_storedTrips > 0) {
        _status = 'Tienes $_storedTrips viajes guardados';
      }
    });
  }

  Future<void> _saveTrips(int trips, String uid, bool isUnlimited) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('stored_trips', trips);
    await prefs.setString('last_card_uid', uid);
    await prefs.setBool('is_unlimited', isUnlimited);
    setState(() {
      _isUnlimited = isUnlimited;
    });
    
    // Anuncio por voz si está habilitado
    if (mounted) {
      final l = AppLocalizations.of(context)!;
      if (isUnlimited) {
        TtsService().speak(l.nfcUnlimitedAnnounce);
      } else {
        final balanceStr = (trips * 1.5).toStringAsFixed(2); // Estimación basada en tarifa 1.50€
        TtsService().speak(l.nfcBalanceAnnounce(balanceStr, trips));
      }
    }
  }

  Future<void> _validateTrip() async {
    if (_storedTrips <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No te quedan viajes disponibles')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar viaje'),
        content: const Text('¿Deseas validar un viaje ahora? Se restará 1 de tu contador.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AlzitransColors.burgundy),
            child: const Text('Validar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final newTrips = _storedTrips - 1;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('stored_trips', newTrips);
      
      setState(() {
        _storedTrips = newTrips;
        if (_cardData != null) {
          _cardData = BusCard(
            uid: _cardData!.uid,
            balance: _cardData!.balance,
            trips: newTrips,
            cardType: _cardData!.cardType,
            isUnlimited: _cardData!.isUnlimited,
          );
        }
      });

      if (mounted) {
        final l = AppLocalizations.of(context)!;
        final balanceStr = (newTrips * 1.5).toStringAsFixed(2);
        TtsService().speak(l.nfcBalanceAnnounce(balanceStr, newTrips));
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Viaje validado. Te quedan $newTrips viajes.'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      await _checkLowBalance(newTrips);
    }
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('low_balance_warnings', _lowBalanceWarningsEnabled);
    await prefs.setInt('low_balance_threshold', _lowBalanceThreshold);
  }

  Future<void> _checkLowBalance(int trips) async {
    if (_lowBalanceWarningsEnabled && trips > 0 && trips <= _lowBalanceThreshold) {
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
      
      // Vibrar el dispositivo
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

  Future<void> _startScan() async {
    if (!_nfcAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('NFC no disponible')),
      );
      return;
    }

    setState(() {
      _scanning = true;
      _status = 'Acerca tu tarjeta al teléfono...';
      _cardData = null;
    });

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
        },
        onDiscovered: (NfcTag tag) async {
          await _handleTagDiscovered(tag);
        },
      );
    } catch (e) {
      debugPrint('Error starting NFC session: $e');
      setState(() {
        _status = 'Error al iniciar escaneo NFC';
        _scanning = false;
      });
    }
  }

  Future<void> _handleTagDiscovered(NfcTag tag) async {
    try {
      String? uid;
      
      // Intentar obtener UID de NfcA (común en Mifare)
      final nfca = NfcAAndroid.from(tag);
      if (nfca != null) {
        uid = nfca.tag.id.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':').toUpperCase();
      }
      
      // Si no, intentar IsoDep
      if (uid == null) {
        final isodep = IsoDepAndroid.from(tag);
        if (isodep != null) {
          uid = isodep.tag.id.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':').toUpperCase();
        }
      }
      
      // Intentar Mifare Classic - usando claves reales de las tarjetas de bus
      final mifareClassic = MifareClassicAndroid.from(tag);
      BusCard? cardData;
      
      if (mifareClassic != null) {
        if (uid == null) {
          uid = mifareClassic.tag.id.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':').toUpperCase();
        }
        
        // Claves Mifare de las tarjetas de bus de Alzira
        // Usamos las claves específicas del sector 1 (blocks 4-7)
        final keysToTry = [
          BusCardKeys.keyA[1]!, // Key A del Sector 1 (primaria)
          BusCardKeys.keyA[0]!, // Key A del Sector 0 (alternativa)
          BusCardKeys.defaultKey, // Clave por defecto (último recurso)
        ];
        
        // Intentar leer bloques con autenticación
        // Función auxiliar para autenticar un sector
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
            // Reintentar con clave por defecto
            if (await authenticateSector(2, BusCardKeys.defaultKey)) {
              block8 = await mifareClassic.readBlock(blockIndex: 8);
            }
          }

          bool authSector1 = await authenticateSector(1, BusCardKeys.keyA[1]!);
          Uint8List? block5;
          if (authSector1) {
            block5 = await mifareClassic.readBlock(blockIndex: 5);
          } else {
            // Reintentar con clave por defecto
            if (await authenticateSector(1, BusCardKeys.defaultKey)) {
              block5 = await mifareClassic.readBlock(blockIndex: 5);
            }
          }

          if (block8 != null && block5 != null) {
            final balance = block8[0] | (block8[1] << 8) | (block8[2] << 16) | (block8[3] << 24);
            final cardType = block5[1];
            
            // Calcular viajes (Tarifa 1.50€, Remanente 0.50€)
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
            
            setState(() {
              _status = cardData!.isUnlimited ? 'Bono Ilimitado Detectado' : 'Tarjeta leída correctamente';
              _cardData = cardData;
              _storedTrips = trips;
              _isUnlimited = cardData.isUnlimited;
              _scanning = false;
            });
            
            await _saveTrips(trips, uid, cardData.isUnlimited);
            await _checkLowBalance(trips);
          } else {
            setState(() {
              _status = 'Error al leer bloques de la tarjeta';
              _scanning = false;
            });
          }
        } catch (e) {
          debugPrint('Error en lectura multi-sector: $e');
          setState(() {
            _status = 'Error de comunicación con la tarjeta';
            _scanning = false;
          });
        }
      } else {
        // No es Mifare Classic
        uid ??= 'Desconocido';
        setState(() {
          _status = 'Tarjeta detectada (no es Mifare Classic)';
          _cardData = BusCard(uid: uid!, balance: 0, trips: 0, cardType: 0, isUnlimited: false);
          _scanning = false;
        });
      }
      
      // Mostrar diálogo informativo
      if (mounted && mifareClassic == null) {
        _showCardInfoDialog(uid);
      }
      
      await NfcManager.instance.stopSession();
    } catch (e) {
      debugPrint('Error reading tag: $e');
      setState(() {
        _status = 'Error al leer la tarjeta: ${e.toString().split('\n').first}';
        _scanning = false;
      });
      await NfcManager.instance.stopSession();
    }
  }

  void _showCardInfoDialog(String uid) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.nfc, color: AlzitransColors.burgundy),
            const SizedBox(width: 8),
            const Text('Tarjeta detectada'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('UID: $uid'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade800),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Las tarjetas Mifare Classic 1K requieren autenticación especial para leer el saldo. La mayoría de móviles Android no pueden leerlas sin hardware especializado.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _stopScan() {
    NfcManager.instance.stopSession();
    setState(() {
      _scanning = false;
      _status = 'Escaneo cancelado';
    });
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ajustes de advertencias'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Activar advertencias'),
                subtitle: const Text('Notificar cuando el saldo sea bajo'),
                value: _lowBalanceWarningsEnabled,
                onChanged: (value) {
                  setDialogState(() => _lowBalanceWarningsEnabled = value);
                  setState(() => _lowBalanceWarningsEnabled = value);
                  _savePreferences();
                },
              ),
              const Divider(),
              ListTile(
                title: const Text('Avisar cuando queden'),
                subtitle: Text('$_lowBalanceThreshold viajes o menos'),
              ),
              Slider(
                value: _lowBalanceThreshold.toDouble(),
                min: 1,
                max: 20,
                divisions: 19,
                label: '$_lowBalanceThreshold viajes',
                onChanged: _lowBalanceWarningsEnabled
                    ? (value) {
                        setDialogState(() => _lowBalanceThreshold = value.toInt());
                        setState(() => _lowBalanceThreshold = value.toInt());
                        _savePreferences();
                      }
                    : null,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showFlipperDumpInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.analytics, color: AlzitransColors.burgundy),
            const SizedBox(width: 8),
            const Text('Información de tarjetas'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tarjetas analizadas:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildCardInfo('Bus1.nfc', 'Antes de usar', '0.96€', '1 viaje'),
              const Divider(),
              _buildCardInfo('Bus2.nfc', 'Después de usar', '4.50€', '27 viajes'),
              const Divider(),
              _buildCardInfo('BusJP.nfc', 'Bono ilimitado', 'Ilimitado', '--'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Estructura detectada:\n'
                  '• Bloque 5: Estado actual\n'
                  '• Bytes 2-3: Saldo en céntimos\n'
                  '• Byte 8: Contador de viajes\n'
                  '• Bloques 20-26: Historial',
                  style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildCardInfo(String name, String desc, String balance, String trips) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.credit_card, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(balance, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(trips, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trips = _cardData?.trips;
    final isLowBalance = trips != null && trips > 0 && trips <= _lowBalanceThreshold;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    return Scaffold(
      appBar: AppBar(
        title: const Text('NFC Alzibus'),
        backgroundColor: Colors.white,
        foregroundColor: AlzitransColors.burgundy,
        elevation: 1, // Añadido para un poco de profundidad sobre el fondo claro
      ),
      body: isIOS
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.phonelink_erase, size: 80, color: Colors.grey.shade400),
                    const SizedBox(height: 24),
                    const Text(
                      'Función exclusiva de Android',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Debido a restricciones de Apple con las tarjetas Mifare Classic, la lectura de saldo no es compatible con iPhone.\n\nUsa el mapa y horarios para planificar tu viaje.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    // Tarjeta visual
                    Container(
                      width: double.infinity,
                      height: 220,
                      decoration: BoxDecoration(
                        gradient: _isUnlimited
                            ? AlzitransColors.primaryGradient
                            : const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF4CAF50),
                                  Color(0xFFFF9800),
                                ],
                              ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -30,
                            bottom: -30,
                            child: Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.directions_bus, color: Colors.white.withOpacity(0.9), size: 24),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Alzitrans NFC',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      _cardData?.cardTypeName ?? 'Transporte Público Alzira',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  _isUnlimited ? 'CONTRATO' : 'VIAJES DISPONIBLES',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                Center(
                                  child: Text(
                                    _isUnlimited ? 'ILIMITADO' : '$_storedTrips',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: _isUnlimited ? 36 : 48,
                                      fontWeight: FontWeight.w900,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withOpacity(0.2),
                                          offset: const Offset(0, 2),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (_lastCardUid != null)
                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: Text(
                                      'ID: $_lastCardUid',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.5),
                                        fontSize: 9,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Positioned(
                            top: 15,
                            right: 15,
                            child: Opacity(
                              opacity: 0.8,
                              child: _scanning
                                  ? AnimatedBuilder(
                                      animation: _pulseAnimation,
                                      builder: (context, child) => Transform.scale(
                                        scale: _pulseAnimation.value,
                                        child: const Icon(Icons.nfc, color: Colors.white, size: 36),
                                      ),
                                    )
                                  : const Icon(Icons.nfc, color: Colors.white, size: 36),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: isLowBalance ? Colors.orange.withOpacity(0.1) : Colors.grey.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        _status,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: isLowBalance ? Colors.orange.shade900 : Colors.grey[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (!_scanning)
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: (_storedTrips > 0 && !_isUnlimited) ? _validateTrip : null,
                          icon: Icon(_isUnlimited ? Icons.all_inclusive : Icons.check_circle_outline, size: 28),
                          label: Text(
                            _isUnlimited ? 'Viajes Ilimitados Activos' : 'Confirmar / Validar Viaje',
                            style: const TextStyle(fontSize: 18),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isUnlimited ? AlzitransColors.wine : Colors.green.shade700,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: _isUnlimited ? AlzitransColors.wine.withOpacity(0.5) : Colors.grey,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      )
                    else
                      Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: _stopScan,
                            child: const Text('Cancelar'),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    if (!_scanning)
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: _nfcAvailable ? _startScan : null,
                          icon: const Icon(Icons.nfc),
                          label: Text(
                            _storedTrips > 0 ? 'Actualizar / Leer Tarjeta' : 'Leer Tarjeta NFC',
                            style: const TextStyle(fontSize: 16),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AlzitransColors.burgundy,
                            side: const BorderSide(color: AlzitransColors.burgundy),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    if (_cardData != null && isLowBalance) ...[
                      Card(
                        color: Colors.orange.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber, color: Colors.orange),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  '¡Recarga tu tarjeta pronto!',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showSettingsDialog,
        backgroundColor: AlzitransColors.burgundy,
        foregroundColor: Colors.white,
        tooltip: 'Ajustes de advertencias',
        child: const Icon(Icons.settings),
      ),
    );
  }
}
