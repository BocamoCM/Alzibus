import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/network/api_client.dart';

/// Resultado de comprobar si hay actualización disponible.
enum UpdateStatus { none, optional, forced }

class UpdateCheckResult {
  final UpdateStatus status;
  final String url;
  final String? latest;
  const UpdateCheckResult(this.status, this.url, this.latest);
}

/// Comprueba contra `GET /api/app/version` si la app está desactualizada.
///
/// El backend devuelve `{ latest, min, url }` (leídos de las variables de
/// entorno APP_LATEST_VERSION / APP_MIN_VERSION / APP_STORE_URL). Si la
/// versión instalada es menor que `min` → actualización FORZADA; si es menor
/// que `latest` → aviso OPCIONAL. Sin push ni Firebase: solo al abrir la app.
class UpdateService {
  UpdateService._();

  static const _defaultUrl =
      'https://play.google.com/store/apps/details?id=com.alzitrans.app';

  /// Compara versiones tipo "X.Y.Z+B". <0 si a<b, 0 igual, >0 si a>b.
  static int _cmp(String a, String b) {
    List<int> parse(String v) => v
        .replaceAll('+', '.')
        .split('.')
        .map((p) => int.tryParse(p.trim()) ?? 0)
        .toList();
    final pa = parse(a), pb = parse(b);
    final n = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < n; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x - y;
    }
    return 0;
  }

  static Future<UpdateCheckResult> check() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = '${info.version}+${info.buildNumber}';
      final res = await ApiClient().get('/app/version');
      final data = (res.data is Map)
          ? Map<String, dynamic>.from(res.data)
          : <String, dynamic>{};
      final latest = data['latest']?.toString();
      final min = data['min']?.toString();
      final url = (data['url']?.toString().isNotEmpty ?? false)
          ? data['url'].toString()
          : _defaultUrl;

      if (min != null && min.isNotEmpty && _cmp(current, min) < 0) {
        return UpdateCheckResult(UpdateStatus.forced, url, latest);
      }
      if (latest != null && latest.isNotEmpty && _cmp(current, latest) < 0) {
        return UpdateCheckResult(UpdateStatus.optional, url, latest);
      }
      return UpdateCheckResult(UpdateStatus.none, url, latest);
    } catch (_) {
      return const UpdateCheckResult(UpdateStatus.none, _defaultUrl, null);
    }
  }

  static Future<void> _openStore(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Llamar UNA VEZ al entrar (p.ej. en el home, tras el primer frame):
  ///   WidgetsBinding.instance.addPostFrameCallback((_) =>
  ///       UpdateService.maybePrompt(context));
  /// Muestra un banner si hay versión nueva (opcional) o un diálogo
  /// bloqueante si la versión ya no es compatible (forzada).
  static Future<void> maybePrompt(BuildContext context) async {
    final r = await check();
    if (!context.mounted) return;
    if (r.status == UpdateStatus.optional) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Hay una nueva versión de Alzitrans disponible.'),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
            label: 'Actualizar', onPressed: () => _openStore(r.url)),
      ));
    } else if (r.status == UpdateStatus.forced) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Actualización necesaria'),
          content: const Text(
              'Tu versión ya no es compatible. Actualiza para seguir usando Alzitrans.'),
          actions: [
            FilledButton(
              onPressed: () => _openStore(r.url),
              child: const Text('Actualizar'),
            ),
          ],
        ),
      );
    }
  }
}
