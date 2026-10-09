import 'package:flutter/material.dart';
import 'package:alzitrans/l10n/app_localizations.dart';

import '../services/traffic_service.dart';
import 'albus_mascot.dart';

/// Banner que aparece SOLO cuando hay incidencias de tráfico en Alzira:
/// Albus avisa de que el bus podría llegar con algún retraso.
///
/// Se autoconsulta al construirse (a nuestro backend cacheado) y no ocupa
/// espacio si no hay incidencias o no se pudo consultar.
class TrafficAlbusBanner extends StatefulWidget {
  const TrafficAlbusBanner({super.key});

  @override
  State<TrafficAlbusBanner> createState() => _TrafficAlbusBannerState();
}

class _TrafficAlbusBannerState extends State<TrafficAlbusBanner> {
  TrafficStatus? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final status = await TrafficService().fetchAlzira();
    if (mounted) setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    if (status == null || !status.hasIncidents) return const SizedBox.shrink();

    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    const amber = Color(0xFFB26A00);
    const amberSoft = Color(0xFFFFF3E0);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: amberSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: amber.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: AlbusMascot(
                state: AlbusState.thinking,
                size: 52,
                animated: false,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l.trafficDelayLine,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: amber,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
