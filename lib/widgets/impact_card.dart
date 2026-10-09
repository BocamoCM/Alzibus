import 'package:flutter/material.dart';
import 'package:alzitrans/l10n/app_localizations.dart';

import '../services/impact_calculator.dart';
import 'albus_mascot.dart';

/// Tarjeta "Tu impacto": muestra, a partir de los viajes del mes, el CO₂
/// evitado, los km en bus y lo que habría costado en coche. Pensada para
/// motivar (mensaje verde) y dar sensación de recompensa por usar el bus.
class ImpactCard extends StatelessWidget {
  /// Viajes realizados en el mes en curso (viene del backend en el perfil).
  final int monthTrips;

  const ImpactCard({super.key, required this.monthTrips});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final impact = ImpactCalculator(monthTrips);

    const green = Color(0xFF2E7D32);
    const greenSoft = Color(0xFFE8F5E9);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [greenSoft, Color(0xFFF3FBF4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: green.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.eco, color: green, size: 20),
              const SizedBox(width: 8),
              Text(
                l.impactCardTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: AlbusMascot(
                  state: AlbusState.happy,
                  size: 64,
                  animated: false,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _metric(
                        theme, impact.co2Formatted, l.impactCo2Label, green),
                    _metric(theme, impact.kmFormatted, l.impactKmLabel, green),
                    _metric(theme, impact.carCostFormatted, l.impactMoneyLabel,
                        green),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            monthTrips > 0
                ? l.impactAlbusLine(impact.co2Formatted)
                : l.impactEmptyLine,
            style: theme.textTheme.bodySmall?.copyWith(
              color: green.withValues(alpha: 0.9),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(ThemeData theme, String value, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }
}
