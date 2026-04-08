import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alzitrans/l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../core/providers/nfc_controller.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mobile_ads/google_mobile_ads.dart' if (dart.library.js_util) 'package:flutter/widgets.dart';
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(nfcControllerProvider);
    final controller = ref.read(nfcControllerProvider.notifier);
    
    final trips = state.cardData?.trips;
    final isLowBalance = trips != null && trips > 0 && trips <= state.lowBalanceThreshold;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

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
                    Text(
                      kIsWeb ? 'Función no disponible en navegador' : 'Función exclusiva de Android',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      kIsWeb 
                        ? 'La lectura de tarjetas NFC requiere acceso al hardware que no está disponible en la versión web.\n\nInstala la app para usar esta función.'
                        : 'Debido a restricciones de Apple con las tarjetas Mifare Classic, la lectura de saldo no es compatible con iPhone.\n\nUsa el mapa y horarios para planificar tu viaje.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                    ),
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
                          MediaQuery(
                            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
                            child: Container(
                              width: double.infinity,
                              height: 220,
                              decoration: BoxDecoration(
                                gradient: state.isUnlimited
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
                                              state.cardData?.cardTypeName ?? 'Transporte Público Alzira',
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(0.8),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          state.isUnlimited ? 'CONTRATO' : 'VIAJES DISPONIBLES',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.7),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 1.1,
                                          ),
                                        ),
                                        Center(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              state.isUnlimited ? 'ILIMITADO' : '${state.storedTrips}',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: state.isUnlimited ? 36 : 48,
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
                                        ),
                                        if (state.lastCardUid != null)
                                          Align(
                                            alignment: Alignment.bottomRight,
                                            child: Text(
                                              'ID: ${state.lastCardUid}',
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
                                      child: state.scanning
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
                          ),
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
                                onPressed: (state.storedTrips > 0 && !state.isUnlimited) ? () async {
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
                                  backgroundColor: state.isUnlimited ? AlzitransColors.wine : Colors.green.shade700,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: state.isUnlimited ? AlzitransColors.wine.withOpacity(0.5) : Colors.grey,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  minimumSize: const Size(double.infinity, 56),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(state.isUnlimited ? Icons.all_inclusive : Icons.check_circle_outline, size: 28),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        state.isUnlimited ? 'Viajes Ilimitados Activos' : 'Confirmar / Validar Viaje',
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
