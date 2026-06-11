import 'package:flutter/material.dart';
import '../models/bus_card.dart';
import '../theme/app_theme.dart';

/// Tarjeta visual NFC (Alzira o SUMA). Widget puro y sin estado:
/// recibe el [BusCard] que tiene que pintar y devuelve la "carátula"
/// con su gradient, branding e información (viajes, zona, UID).
///
/// La animación de pulso del icono NFC vive aquí, controlada por la
/// página padre vía [scanning] + [pulseAnimation] para que solo lata
/// la tarjeta de delante cuando se está escaneando.
class NfcCardVisual extends StatelessWidget {
  final BusCard card;
  final bool scanning;
  final Animation<double>? pulseAnimation;

  const NfcCardVisual({
    super.key,
    required this.card,
    this.scanning = false,
    this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final isSuma = card.kind == BusCardKind.sumaValencia;

    final gradient = isSuma
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE63946), Color(0xFFB81D2C)],
          )
        : card.isUnlimited
            ? AlzitransColors.primaryGradient
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF4CAF50), Color(0xFFFF9800)],
              );

    final headerLabel = isSuma ? 'SUMA' : 'Alzitrans NFC';
    final subtitle = isSuma ? 'Generalitat Valenciana · ATMV' : card.cardTypeName;
    final mainLabel = card.isUnlimited ? 'CONTRATO' : 'VIAJES DISPONIBLES';
    final mainValue = card.isUnlimited ? 'ILIMITADO' : '${card.trips}';
    final mainFontSize = card.isUnlimited ? 36.0 : 48.0;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Container(
        width: double.infinity,
        height: 220,
        decoration: BoxDecoration(
          gradient: gradient,
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
                          Icon(
                            isSuma ? Icons.train : Icons.directions_bus,
                            color: Colors.white.withOpacity(0.9),
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            headerLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    mainLabel,
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
                        mainValue,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: mainFontSize,
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (isSuma && card.sumaZone != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'ZONA ${card.sumaZone}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      Text(
                        'ID: ${card.uid}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 9,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              top: 15,
              right: 15,
              child: Opacity(
                opacity: 0.8,
                child: scanning && pulseAnimation != null
                    ? AnimatedBuilder(
                        animation: pulseAnimation!,
                        builder: (context, _) => Transform.scale(
                          scale: pulseAnimation!.value,
                          child: const Icon(Icons.nfc, color: Colors.white, size: 36),
                        ),
                      )
                    : const Icon(Icons.nfc, color: Colors.white, size: 36),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
