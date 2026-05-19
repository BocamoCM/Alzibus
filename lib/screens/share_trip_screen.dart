import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/providers/live_trip_provider.dart';
import '../core/router/app_router.dart';
import '../models/bus_stop.dart';
import '../models/live_trip.dart';
import '../services/live_trip_ping_worker.dart';
import '../services/live_trip_service.dart';
import '../theme/app_theme.dart';
import '../widgets/albus_mascot.dart';

/// Pantalla "Compartir mi viaje en vivo".
///
/// La accedes desde el planificador (botón en la card de un plan). Inicia un
/// `LiveTrip` en el backend, recibe `shareUrl` y abre el share sheet del
/// sistema. Mientras la pantalla está abierta, manda ping con GPS cada 30s.
///
/// **Limitación de esta primera versión:** solo funciona con la pantalla en
/// primer plano. Si el usuario minimiza la app, deja de mandar pings (pero el
/// viaje sigue activo en el servidor hasta `expires_at` o `end()`).
/// Versión 2: integrar con `flutter_background_service` para pings en
/// background. Marcado como TODO abajo.
class ShareTripScreen extends ConsumerStatefulWidget {
  /// Si vienes del planificador, podemos prerellenar destino. Opcional.
  final BusStop? destinationStop;
  final String? line;

  const ShareTripScreen({
    super.key,
    this.destinationStop,
    this.line,
  });

  @override
  ConsumerState<ShareTripScreen> createState() => _ShareTripScreenState();
}

class _ShareTripScreenState extends ConsumerState<ShareTripScreen>
    with WidgetsBindingObserver {
  LiveTrip? _trip;
  Timer? _pingTimer;
  StreamSubscription<Position>? _positionSub;
  Position? _lastPosition;
  bool _starting = false;
  bool _ending = false;
  String? _errorMsg;

  // Albus
  AlbusState _albusState = AlbusState.idle;
  String _albusMessage =
      '¿Quieres que alguien sepa por dónde vas? Empieza el viaje compartido y te doy un enlace para enviarles.';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkForExistingTrip();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPinging();
    // IMPORTANTE: al disponer la pantalla, devolvemos el control al background
    // worker quitando el flag de "suspended by UI". El trip ID se mantiene en
    // prefs si el viaje sigue activo — solo se borra en _endTrip o cuando
    // el worker recibe un 404/410.
    _setUiSuspended(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Cuando la app va a background, suspendemos los pings de la UI para que
    // el worker tome el relevo. Al volver, la UI pinguea otra vez.
    if (state == AppLifecycleState.resumed) {
      _setUiSuspended(true);
    } else if (state == AppLifecycleState.paused ||
               state == AppLifecycleState.inactive ||
               state == AppLifecycleState.hidden) {
      _setUiSuspended(false);
    }
  }

  /// Marca en SharedPreferences si el worker en background debe saltar el
  /// ping (porque la UI ya está pingueando ella misma). El worker lee este
  /// flag en cada tick.
  Future<void> _setUiSuspended(bool suspended) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(LiveTripPingKeys.suspendedByUi, suspended);
    } catch (_) {/* silencioso */}
  }

  /// Guarda en SharedPreferences el ID del viaje activo para que el worker
  /// pueda pinguearlo cuando la app esté en background.
  Future<void> _setActiveTripIdInPrefs(String? tripId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (tripId == null) {
        await prefs.remove(LiveTripPingKeys.activeTripId);
      } else {
        await prefs.setString(LiveTripPingKeys.activeTripId, tripId);
      }
    } catch (_) {/* silencioso */}
  }

  Future<void> _checkForExistingTrip() async {
    try {
      final existing =
          await ref.read(liveTripServiceProvider).getActive();
      if (existing != null && existing.isActive && mounted) {
        setState(() {
          _trip = existing;
          _albusState = AlbusState.happy;
          _albusMessage =
              'Ya tienes un viaje activo. Sigues compartiendo con la gente que tiene el enlace.';
        });
        // Asegurar que el worker en background conoce este viaje, por si la
        // pantalla anterior no lo guardó (ej: la app se reinstaló).
        await _setActiveTripIdInPrefs(existing.id);
        await _setUiSuspended(true); // UI activa: el worker no debe duplicar
        _startPinging();
      }
    } catch (_) {
      // Ignorar — la pantalla funciona aunque no haya viaje previo.
    }
  }

  Future<void> _startTrip() async {
    setState(() {
      _starting = true;
      _errorMsg = null;
      _albusState = AlbusState.thinking;
      _albusMessage = 'Creando tu viaje compartido...';
    });

    try {
      // Permisos GPS antes de empezar.
      final ok = await _ensureLocationPermission();
      if (!ok) {
        setState(() {
          _starting = false;
          _errorMsg = 'Sin permiso de ubicación no puedo compartir el viaje.';
          _albusState = AlbusState.sad;
          _albusMessage = '¡Necesito permiso para ver dónde estás!';
        });
        return;
      }

      final service = ref.read(liveTripServiceProvider);
      final trip = await service.start(
        line: widget.line,
        destinationStopId: widget.destinationStop?.id,
        destinationStopName: widget.destinationStop?.name,
        destinationLat: widget.destinationStop?.lat,
        destinationLng: widget.destinationStop?.lng,
      );

      if (!mounted) return;
      setState(() {
        _trip = trip;
        _starting = false;
        _albusState = AlbusState.happy;
        _albusMessage =
            '¡Listo! Comparte el enlace y la gente verá dónde vas en tiempo real.';
      });

      // Persistimos el ID para que el worker en background sepa qué pinguear
      // cuando la app esté minimizada.
      await _setActiveTripIdInPrefs(trip.id);
      await _setUiSuspended(true); // UI viva → worker en pausa

      _startPinging();
      // Abrimos el share sheet inmediatamente para no perder el momentum.
      await _share();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _errorMsg = 'No pude crear el viaje: $e';
        _albusState = AlbusState.sad;
        _albusMessage = 'Algo se torció. ¿Probamos de nuevo?';
      });
    }
  }

  Future<void> _endTrip() async {
    final trip = _trip;
    if (trip == null) return;

    setState(() {
      _ending = true;
      _albusState = AlbusState.thinking;
      _albusMessage = 'Terminando el compartido...';
    });

    try {
      await ref.read(liveTripServiceProvider).end(trip.id);
    } catch (e) {
      // Aún si falla en servidor, paramos los pings cliente.
      debugPrint('end() error (no bloqueante): $e');
    }

    _stopPinging();
    // Limpiamos el ID del worker — ya no hay nada activo que pinguear.
    await _setActiveTripIdInPrefs(null);
    await _setUiSuspended(false);

    if (!mounted) return;
    setState(() {
      _trip = null;
      _ending = false;
      _albusState = AlbusState.idle;
      _albusMessage = '¡Viaje terminado! Buen camino 👋';
    });
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  void _startPinging() {
    _pingTimer?.cancel();
    _positionSub?.cancel();

    // Subscripción al stream de posición (continuo y eficiente en batería).
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // metros mínimos para emitir
      ),
    ).listen((pos) {
      _lastPosition = pos;
    });

    // Ping al backend cada 30s con la última posición conocida.
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _sendPing();
    });

    // Primer ping inmediato.
    _sendPing();
  }

  Future<void> _sendPing() async {
    final trip = _trip;
    if (trip == null) return;

    var pos = _lastPosition;
    if (pos == null) {
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        _lastPosition = pos;
      } catch (_) {
        return; // sin posición no podemos pingar
      }
    }

    try {
      final updated = await ref.read(liveTripServiceProvider).ping(
            tripId: trip.id,
            lat: pos.latitude,
            lng: pos.longitude,
            speedMps: pos.speed >= 0 ? pos.speed : null,
            accuracyM: pos.accuracy,
          );
      if (mounted) setState(() => _trip = updated);
    } on LiveTripException catch (e) {
      // Si el viaje ya no está activo, paramos y limpiamos las prefs para
      // que el worker en background tampoco siga intentando.
      debugPrint('[ShareTrip] ping fallido: $e');
      _stopPinging();
      await _setActiveTripIdInPrefs(null);
      await _setUiSuspended(false);
      if (mounted) {
        setState(() {
          _trip = null;
          _albusState = AlbusState.sad;
          _albusMessage = 'El viaje compartido ha terminado.';
        });
      }
    }
  }

  void _stopPinging() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _positionSub?.cancel();
    _positionSub = null;
  }

  /// Abre el share sheet nativo del sistema para que el usuario elija
  /// destino (WhatsApp, Telegram, mail, etc.). El texto del mensaje incluye
  /// la URL y un copy enganchador.
  ///
  /// Si el share sheet falla por cualquier razón (raro pero ha pasado en
  /// algunos OEMs), caemos a portapapeles + SnackBar como fallback.
  Future<void> _share() async {
    final trip = _trip;
    if (trip == null || trip.shareUrl == null) return;

    // Construir mensaje del share: enganchador en castellano + URL.
    // El destino (si lo tenemos) lo metemos en el subject para apps tipo
    // mail que separan asunto y cuerpo.
    final destination = trip.destinationStopName;
    final messageBody = destination != null
        ? '¡Voy en el bus! Mira por dónde voy en vivo: ${trip.shareUrl}'
        : '¡Sigue mi viaje en bus en vivo! ${trip.shareUrl}';
    final messageSubject = destination != null
        ? 'Voy hacia $destination · Alzitrans'
        : 'Mi viaje en vivo · Alzitrans';

    try {
      // Share.share() en share_plus 10.x devuelve ShareResult — sabemos si
      // el usuario llegó a compartir de verdad (success) o canceló. Si fue
      // success, mostramos confirmación; si canceló, no hacemos nada
      // (UX no intrusiva).
      final result = await Share.share(
        messageBody,
        subject: messageSubject,
      );
      if (result.status == ShareResultStatus.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Enlace compartido! 🚌'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Fallback: si share_plus falla (raro pero pasa en algunos OEMs),
      // copiamos al portapapeles para que al menos el usuario tenga la URL.
      debugPrint('[ShareTrip] share_plus falló, fallback a clipboard: $e');
      await Clipboard.setData(ClipboardData(text: trip.shareUrl!));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enlace copiado: ${trip.shareUrl}')),
      );
    }
  }

  /// Abre el shareUrl en el navegador externo del sistema. La pantalla que
  /// se muestra ahí es EXACTAMENTE la que verán los destinatarios — usar
  /// como preview antes de compartir, o por curiosidad.
  Future<void> _openViewerPreview(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[ShareTrip] No se pudo abrir el preview: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pude abrir el navegador.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AlzitransColors.background,
      appBar: AppBar(
        title: const Text('Compartir mi viaje'),
        backgroundColor: AlzitransColors.burgundy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Ver mis viajes compartidos pasados',
            onPressed: () => const LiveTripHistoryRoute().push(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAlbusHeader(),
            const SizedBox(height: 20),
            if (_trip == null) _buildIdleState() else _buildActiveTripState(),
            if (_errorMsg != null) ...[
              const SizedBox(height: 12),
              _ErrorBanner(message: _errorMsg!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAlbusHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AlbusMascot(state: _albusState, size: 110),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 18),
            child: AlbusBubble(text: _albusMessage),
          ),
        ),
      ],
    );
  }

  Widget _buildIdleState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.destinationStop != null) ...[
                  Text('Destino: ${widget.destinationStop!.name}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                ],
                if (widget.line != null) ...[
                  Row(
                    children: [
                      const Text('Línea: ',
                          style: TextStyle(color: Colors.grey)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _lineColor(widget.line!),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(widget.line!,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                const Text(
                  'Al empezar, se generará un enlace público que puedes mandar '
                  'a quien quieras. Verán tu posición y la hora estimada de '
                  'llegada actualizadas cada 30 segundos.',
                  style: TextStyle(color: Colors.black87, height: 1.35),
                ),
                const SizedBox(height: 8),
                Text(
                  'El enlace caduca solo a las 6 horas.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _starting ? null : _startTrip,
          style: ElevatedButton.styleFrom(
            backgroundColor: AlzitransColors.burgundy,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: _starting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Icon(Icons.share_location),
          label: Text(_starting ? 'Iniciando...' : 'Empezar a compartir',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildActiveTripState() {
    final trip = _trip!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AlzitransColors.burgundy, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10, height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Compartiendo en vivo',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.green)),
                  ],
                ),
                const SizedBox(height: 12),
                if (trip.destinationStopName != null)
                  _infoRow(Icons.flag, 'Destino', trip.destinationStopName!),
                if (trip.line != null)
                  _infoRow(Icons.directions_bus, 'Línea', trip.line!,
                      valueColor: _lineColor(trip.line!)),
                if (trip.etaMin != null)
                  _infoRow(Icons.access_time, 'Llegada estimada',
                      '${trip.etaMin} min'),
                if (trip.lastPingAt != null)
                  _infoRow(Icons.gps_fixed, 'Última posición',
                      _formatRelativeTime(trip.lastPingAt!)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (trip.shareUrl != null) ...[
          Card(
            color: AlzitransColors.background,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const Icon(Icons.link, color: AlzitransColors.burgundy),
              title: const Text('Enlace para compartir',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              subtitle: Text(trip.shareUrl!,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                icon: const Icon(Icons.copy),
                tooltip: 'Copiar',
                onPressed: _share,
              ),
              onTap: _share,
            ),
          ),
          const SizedBox(height: 8),
          // Botón secundario: abre el shareUrl en el navegador del sistema,
          // que es exactamente lo que ve la gente con la que compartes.
          // Útil para asegurarte que se ve bien antes de mandar el link.
          TextButton.icon(
            onPressed: () => _openViewerPreview(trip.shareUrl!),
            icon: const Icon(Icons.preview, size: 18),
            label: const Text('Ver como lo ven los demás'),
            style: TextButton.styleFrom(
              foregroundColor: AlzitransColors.burgundy,
            ),
          ),
          const SizedBox(height: 8),
        ],
        ElevatedButton.icon(
          onPressed: _ending ? null : _endTrip,
          style: ElevatedButton.styleFrom(
            backgroundColor: AlzitransColors.error,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: _ending
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Icon(Icons.stop_circle),
          label: Text(_ending ? 'Terminando...' : 'Terminar de compartir',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 16),
        // Aviso sobre la limitación foreground
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AlzitransColors.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AlzitransColors.warning.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: AlzitransColors.warning, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Puedes minimizar la app sin problema: los pings de '
                  'ubicación siguen mandándose en segundo plano cada 30 s.',
                  style: TextStyle(fontSize: 13, height: 1.3),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text('$label: ',
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? Colors.black87),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Color _lineColor(String line) => switch (line) {
        'L1' => AlzitransColors.lineL1,
        'L2' => AlzitransColors.lineL2,
        'L3' => AlzitransColors.lineL3,
        _ => AlzitransColors.burgundy,
      };

  String _formatRelativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 5) return 'ahora mismo';
    if (diff.inSeconds < 60) return 'hace ${diff.inSeconds}s';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    return 'hace ${diff.inHours}h';
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AlzitransColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AlzitransColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AlzitransColors.error),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
