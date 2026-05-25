import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// Pantalla de créditos / fuentes de datos.
///
/// Su única misión: dejar constancia visible de la procedencia de los
/// horarios de bus (Autocares Lozano S.L.U.) y de los trenes (Renfe),
/// más un disclaimer explícito de no-afiliación. Esto cubre:
///   1. Buenas prácticas con la fuente — atribución visible al usuario.
///   2. Defensa jurídica frente a una hipotética reclamación: dejamos
///      escrito que la app NO almacena ni redistribuye los datos, sino
///      que cada usuario los consulta desde su dispositivo.
///   3. Memoria del TFC: una pantalla concreta y referenciable como
///      "consideraciones legales".
class CreditsPage extends StatelessWidget {
  const CreditsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.dataCreditsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Bloque buses (Autocares Lozano) ───────────────────────
          _SourceCard(
            icon: Icons.directions_bus,
            iconColor: AlzitransColors.burgundy,
            title: l.dataCreditsBusOperator,
            body: l.dataCreditsBusOperatorBody,
            link: 'https://www.autocareslozano.com',
            linkLabel: 'autocareslozano.com',
          ),
          const SizedBox(height: 12),

          // ── Bloque trenes (Renfe) ─────────────────────────────────
          _SourceCard(
            icon: Icons.train,
            iconColor: const Color(0xFFF79529),
            title: l.dataCreditsRenfe,
            body: l.dataCreditsRenfeBody,
            link: 'https://www.renfe.com/es/es/cercanias/cercanias-valencia',
            linkLabel: 'renfe.com',
          ),

          const SizedBox(height: 24),

          // ── Agradecimiento ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AlzitransColors.burgundy.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AlzitransColors.burgundy.withOpacity(0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.favorite, color: AlzitransColors.burgundy, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l.dataCreditsThanks,
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  final String link;
  final String linkLabel;

  const _SourceCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    required this.link,
    required this.linkLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(body, style: const TextStyle(fontSize: 13, height: 1.45)),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => launchUrl(
                Uri.parse(link),
                mode: LaunchMode.externalApplication,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.link, size: 16, color: iconColor),
                    const SizedBox(width: 6),
                    Text(
                      linkLabel,
                      style: TextStyle(
                        fontSize: 13,
                        color: iconColor,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
