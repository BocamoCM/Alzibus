import 'package:flutter/material.dart';
import 'package:alzitrans/l10n/app_localizations.dart';

import '../models/albus_skin.dart';
import '../services/weather_service.dart';
import 'albus_mascot.dart';

/// Banner que aparece SOLO cuando llueve en Alzira: Albus (con el chubasquero
/// y paraguas puestos) avisa de que puede haber algún retraso por el clima.
///
/// Se autoconsulta al construirse y no ocupa espacio si no llueve o no se
/// pudo consultar el tiempo.
class WeatherAlbusBanner extends StatefulWidget {
  const WeatherAlbusBanner({super.key});

  @override
  State<WeatherAlbusBanner> createState() => _WeatherAlbusBannerState();
}

class _WeatherAlbusBannerState extends State<WeatherAlbusBanner> {
  WeatherStatus? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final status = await WeatherService().fetchAlzira();
    if (mounted) setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    if (status == null || !status.isRaining) return const SizedBox.shrink();

    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    const rainBlue = Color(0xFF1565C0);
    const rainSoft = Color(0xFFE3F2FD);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: rainSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: rainBlue.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: AlbusMascot(
              state: AlbusState.idle,
              size: 56,
              animated: false,
              // Albus aparece con el skin de lluvia (paraguas + chubasquero),
              // sin cambiar el que el usuario tiene equipado.
              skinOverride: AlbusSkin.findById('lluvia'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l.weatherRainLine,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: rainBlue,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
