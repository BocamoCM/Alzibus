import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/live_trip_provider.dart';
import '../models/live_trip.dart';
import '../screens/share_trip_screen.dart';
import '../theme/app_theme.dart';

/// Banner persistente que aparece en home cuando el usuario tiene un viaje
/// compartido en vivo activo. Permite reabrir la pantalla de compartir sin
/// tener que volver al planificador.
///
/// Auto-poll cada 60s mientras esté montado, para refrescar ETA y datos.
/// Si la API responde null (no hay viaje activo), el banner desaparece.
class ActiveLiveTripBanner extends ConsumerStatefulWidget {
  const ActiveLiveTripBanner({super.key});

  @override
  ConsumerState<ActiveLiveTripBanner> createState() => _ActiveLiveTripBannerState();
}

class _ActiveLiveTripBannerState extends ConsumerState<ActiveLiveTripBanner>
    with WidgetsBindingObserver {
  LiveTrip? _activeTrip;
  Timer? _pollTimer;
  bool _firstLoadDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _pollTimer = Timer.periodic(const Duration(seconds: 60), (_) => _refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Cuando la app vuelve a primer plano, refrescamos inmediatamente — el
    // usuario puede haber terminado el viaje desde la web o desde otra app.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final svc = ref.read(liveTripServiceProvider);
      final trip = await svc.getActive();
      if (!mounted) return;
      setState(() {
        _activeTrip = trip;
        _firstLoadDone = true;
      });
    } catch (_) {
      // Silencioso — si fallan los polls, no mostramos banner.
      if (!mounted) return;
      setState(() => _firstLoadDone = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mientras no haya terminado la primera carga, no ocupamos espacio en home.
    if (!_firstLoadDone || _activeTrip == null || !_activeTrip!.isActive) {
      return const SizedBox.shrink();
    }

    final trip = _activeTrip!;
    final eta = trip.etaMin;
    final destination = trip.destinationStopName;

    return Material(
      color: AlzitransColors.burgundy,
      child: InkWell(
        onTap: () async {
          // Abre la pantalla de share — recargará el viaje activo al montarse.
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ShareTripScreen()),
          );
          // Al volver, refresca por si el usuario lo terminó allá dentro.
          _refresh();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Puntito verde parpadeante para indicar "en vivo".
              _PulsingDot(),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Compartiendo en vivo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _buildSubtitle(destination, eta),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  String _buildSubtitle(String? destination, int? eta) {
    final parts = <String>[];
    if (destination != null && destination.isNotEmpty) {
      parts.add('hacia $destination');
    }
    if (eta != null) parts.add('llegada en $eta min');
    if (parts.isEmpty) return 'Toca para gestionar';
    return parts.join(' · ');
  }
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.4, end: 1.0).animate(_controller),
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: Colors.greenAccent,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
