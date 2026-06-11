import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alzitrans/l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../core/providers/nfc_controller.dart';
import '../models/bus_card.dart' show BusCardKind;
import '../widgets/card_stack.dart';
import '../widgets/nfc_card_visual.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mobile_ads/google_mobile_ads.dart' if (dart.library.js_util) 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/ad_ui_factory.dart';
import '../services/ad_service.dart';
import '../constants/app_config.dart';

class NfcPage extends ConsumerStatefulWidget {
  const NfcPage({super.key});

  @override
  ConsumerState<NfcPage> createState() => _NfcPageState();
}

class _NfcPageState extends ConsumerState<NfcPage> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late NfcController _nfcNotifier;
  
  dynamic _bannerAd;
  bool _isBannerAdLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _nfcNotifier = ref.read(nfcControllerProvider.notifier);
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadBannerAd();
  }

  void _loadBannerAd() {
    if (!AppConfig.showAds || kIsWeb) return;
    // La inicialización de BannerAd se movió para ser segura en compilación
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _bannerAd?.dispose();
    _nfcNotifier.stopScan();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _nfcNotifier.stopScan();
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
                  Expanded(
                    child: Builder(builder: (context) {
                      return Text(
                        AppLocalizations.of(context)!.mifareClassicInfo,
                        style: const TextStyle(fontSize: 12),
                      );
                    }),
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

  void _showSettingsDialog(NfcState nfcState) {
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
                value: nfcState.lowBalanceWarningsEnabled,
                onChanged: (value) {
                  ref.read(nfcControllerProvider.notifier).updatePreferences(
                    warningsEnabled: value,
                    threshold: nfcState.lowBalanceThreshold,
                  );
                },
              ),
              const Divider(),
              ListTile(
                title: const Text('Avisar cuando queden'),
                subtitle: Text('${nfcState.lowBalanceThreshold} viajes o menos'),
              ),
              Slider(
                value: nfcState.lowBalanceThreshold.toDouble(),
                min: 1,
                max: 20,
                divisions: 19,
                label: '${nfcState.lowBalanceThreshold} viajes',
                onChanged: nfcState.lowBalanceWarningsEnabled
                    ? (value) {
                        ref.read(nfcControllerProvider.notifier).updatePreferences(
                          warningsEnabled: nfcState.lowBalanceWarningsEnabled,
                          threshold: value.toInt(),
                        );
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

  /// Tarjeta(s) NFC: pila animada o placeholder si aún no se ha escaneado
  /// ninguna. Solo la tarjeta de delante muestra la animación de pulso
  /// mientras se escanea.
  Widget _buildCardArea(NfcState state) {
    final cards = state.cards;

    if (cards.isEmpty) {
      // Placeholder con la MISMA altura que la pila completa
      // (cardHeight 220 + peekHeight 56 = 276) para que la página
      // no salte cuando aparezca la primera tarjeta.
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: Container(
          width: double.infinity,
          height: 276,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border.all(color: Colors.grey.shade300, width: 1.5),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              state.scanning
                  ? AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, _) => Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Icon(Icons.nfc, size: 48, color: Colors.grey.shade400),
                      ),
                    )
                  : Icon(Icons.nfc, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                'Acerca tu tarjeta para empezar',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 1 o 2 tarjetas: las pasamos al CardStack. La animación de pulso
    // (NFC escaneando) solo se aplica a la tarjeta que tiene el slot
    // seleccionado — la otra se queda quieta detrás.
    final selectedSlot = state.selectedSlot;
    final visuals = <Widget>[];
    for (var i = 0; i < cards.length; i++) {
      final card = cards[i];
      final isFront = i == state.displayIndex;
      visuals.add(NfcCardVisual(
        card: card,
        scanning: state.scanning && isFront,
        pulseAnimation: _pulseAnimation,
      ));
    }
    return CardStack(
      cards: visuals,
      selectedIndex: state.displayIndex,
      onSelected: (i) {
        // Mapear displayIndex (posición en cards filtrada) al slot real
        // (0=Alzira, 1=SUMA). Como la lista mantiene ese mismo orden
        // cuando ambas existen, displayIndex coincide con el slot.
        final newSlot = cards.length == 2 ? i : selectedSlot;
        ref.read(nfcControllerProvider.notifier).selectSlot(newSlot);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(nfcControllerProvider);
    final controller = ref.read(nfcControllerProvider.notifier);
    
    final trips = state.cardData?.trips;
    final isLowBalance = trips != null && trips > 0 && trips <= state.lowBalanceThreshold;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    // Variante SUMA (ATMV / Generalitat Valenciana). Cambia colores, texto y
    // deshabilita "Validar viaje" porque la app solo lee este tipo, no escribe.
    final isSuma = state.cardData?.kind == BusCardKind.sumaValencia;

    return Scaffold(
      appBar: AppBar(
        title: const Text('NFC Alzibus'),
        backgroundColor: Colors.white,
        foregroundColor: AlzitransColors.burgundy,
        elevation: 1,
      ),
      body: (isIOS || kIsWeb)
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(kIsWeb ? Icons.web_asset_off : Icons.phonelink_erase, size: 80, color: Colors.grey.shade400),
                    const SizedBox(height: 24),
                    Builder(builder: (context) {
                      final l = AppLocalizations.of(context)!;
                      return Text(
                        kIsWeb ? l.featureNotAvailableWeb : l.featureAndroidOnly,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      );
                    }),
                    const SizedBox(height: 16),
                    Builder(builder: (context) {
                      final l = AppLocalizations.of(context)!;
                      return Text(
                        kIsWeb ? l.nfcWebExplained : l.nfcIosExplained,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                      );
                    }),
                    if (kIsWeb) ...[
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          launchUrl(
                            Uri.parse('https://play.google.com/store/apps/details?id=com.alzitrans.app'),
                            mode: LaunchMode.externalApplication,
                          );
                        },
                        icon: const Icon(Icons.android),
                        label: const Text('Descargar para Android'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AlzitransColors.burgundy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          const SizedBox(height: 40),
                          // CardStack: hasta 2 tarjetas (Alzira + SUMA) en
                          // pila, swipe horizontal para cambiar la del
                          // frente. Si solo hay 1 la muestra sin gesto;
                          // si no hay ninguna pinta un placeholder con la
                          // bienvenida.
                          _buildCardArea(state),
                          const SizedBox(height: 32),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: isLowBalance ? Colors.orange.withOpacity(0.1) : Colors.grey.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              state.status,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: isLowBalance ? Colors.orange.shade900 : Colors.grey[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          if (!state.scanning)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                // SUMA es solo lectura: no manipulamos el saldo de
                                // la tarjeta de la ATMV desde la app. Desactivamos
                                // el botón y abajo cambiamos el texto.
                                onPressed: (state.storedTrips > 0 && !state.isUnlimited && !isSuma) ? () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text(AppLocalizations.of(context)!.confirmTripTitle),
                                      content: Text(AppLocalizations.of(context)!.validateTripPrompt),
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
                                    int newTrips = await controller.validateTrip();
                                    if (newTrips >= 0 && mounted) {
                                      final l = AppLocalizations.of(context)!;
                                      final balanceStr = (newTrips * 1.5).toStringAsFixed(2);
                                      controller.speak(l.nfcBalanceAnnounce(balanceStr, newTrips));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Viaje validado. Te quedan $newTrips viajes.'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  }
                                } : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isSuma
                                      ? const Color(0xFFB81D2C)
                                      : (state.isUnlimited ? AlzitransColors.wine : Colors.green.shade700),
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: isSuma
                                      ? const Color(0xFFB81D2C).withOpacity(0.5)
                                      : (state.isUnlimited ? AlzitransColors.wine.withOpacity(0.5) : Colors.grey),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  minimumSize: const Size(double.infinity, 56),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isSuma
                                          ? Icons.lock_outline
                                          : (state.isUnlimited ? Icons.all_inclusive : Icons.check_circle_outline),
                                      size: 28,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        isSuma
                                            ? 'Solo lectura · valida en el torno'
                                            : (state.isUnlimited ? 'Viajes Ilimitados Activos' : 'Confirmar / Validar Viaje'),
                                        style: const TextStyle(fontSize: 18),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            Column(
                              children: [
                                const CircularProgressIndicator(),
                                const SizedBox(height: 16),
                                TextButton(
                                  onPressed: () => controller.stopScan(),
                                  child: const Text('Cancelar'),
                                ),
                              ],
                            ),
                          const SizedBox(height: 16),
                          if (!state.scanning)
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: state.nfcAvailable ? () {
                                  controller.startScan(
                                    onError: () {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('NFC no disponible')),
                                        );
                                      }
                                    },
                                    onVoiceAnnounce: (type) {
                                      if (mounted) {
                                        final l = AppLocalizations.of(context)!;
                                        if (state.isUnlimited) {
                                          controller.speak(l.nfcUnlimitedAnnounce);
                                        } else {
                                          final balanceStr = (state.storedTrips * 1.5).toStringAsFixed(2);
                                          controller.speak(l.nfcBalanceAnnounce(balanceStr, state.storedTrips));
                                        }
                                      }
                                    }
                                  );
                                } : null,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AlzitransColors.burgundy,
                                  side: const BorderSide(color: AlzitransColors.burgundy),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  minimumSize: const Size(double.infinity, 50),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.nfc),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        state.storedTrips > 0 ? 'Actualizar / Leer Tarjeta' : 'Leer Tarjeta NFC',
                                        style: const TextStyle(fontSize: 16),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 24),
                          if (state.cardData != null && isLowBalance) ...[
                            Card(
                              color: Colors.orange.shade50,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warning_amber, color: Colors.orange),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        AppLocalizations.of(context)!.rechargeYourCardSoon,
                                        style: const TextStyle(
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
                ),
                if (AppConfig.showAds && _bannerAd != null && _isBannerAdLoaded)
                  Container(
                    alignment: Alignment.center,
                    width: _bannerAd!.size.width.toDouble(),
                    height: _bannerAd!.size.height.toDouble(),
                    margin: const EdgeInsets.only(bottom: 16),
                    child: buildNativeAdStub(ad: _bannerAd),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSettingsDialog(state),
        backgroundColor: AlzitransColors.burgundy,
        foregroundColor: Colors.white,
        tooltip: 'Ajustes de advertencias',
        child: const Icon(Icons.settings),
      ),
    );
  }
}
