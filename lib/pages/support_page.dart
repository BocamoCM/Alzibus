import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:alzitrans/l10n/app_localizations.dart';
import '../theme/app_theme.dart';

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.supportTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // SECCIÓN FAQ
          Text(
            l.supportFaqHeading,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AlzitransColors.burgundy),
          ),
          const SizedBox(height: 16),
          _buildFaqItem(l.supportFaqAlertsQ, l.supportFaqAlertsA),
          _buildFaqItem(l.supportFaqLocationQ, l.supportFaqLocationA),
          _buildFaqItem(l.supportFaqRechargeQ, l.supportFaqRechargeA),
          _buildFaqItem(l.supportFaqPointsQ, l.supportFaqPointsA),

          const SizedBox(height: 32),

          // SECCIÓN CONTACTO
          Text(
            l.supportSuggestionsHeading,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AlzitransColors.burgundy),
          ),
          const SizedBox(height: 8),
          Text(
            l.supportSuggestionsBody,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: () => _launchEmail(context, l),
            icon: const Icon(Icons.email),
            label: Text(l.supportSendButton),
            style: ElevatedButton.styleFrom(
              backgroundColor: AlzitransColors.burgundy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),

          const SizedBox(height: 32),

          // VERSIÓN
          Center(
            child: Text(
              l.supportVersion('5.1.2'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              answer,
              style: TextStyle(color: Colors.grey[700], height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchEmail(BuildContext context, AppLocalizations l) async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'bcarreres55@gmail.com', // Uso tu correo vinculado por seguridad
      query: encodeQueryParameters(<String, String>{
        'subject': l.supportEmailSubject,
        'body': l.supportEmailBody,
      }),
    );

    try {
      await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.supportEmailError)),
        );
      }
    }
  }

  String encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((MapEntry<String, String> e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }
}
