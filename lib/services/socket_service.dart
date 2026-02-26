import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/material.dart';
import 'package:alzitrans/l10n/app_localizations.dart';
import '../constants/app_config.dart';
import '../theme/app_theme.dart';
import '../main.dart'; // Para navigatorKey

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;

  void initialize() {
    if (_socket != null && _socket!.connected) return;

    // Remueve '/api' de la URL base para conectar al servidor raíz de WebSockets.
    final wsUrl = AppConfig.baseUrl.replaceAll('/api', '');
    
    _socket = IO.io(wsUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    _socket!.onConnect((_) {
      debugPrint('[SocketService] Conectado a WebSockets');
    });

    _socket!.on('new_notice', (data) {
      debugPrint('[SocketService] Nuevo aviso recibido: $data');
      _showNoticeDialog(data);
    });

    _socket!.onDisconnect((_) {
      debugPrint('[SocketService] Desconectado de WebSockets');
    });
  }

  void _showNoticeDialog(dynamic data) {
    if (navigatorKey.currentContext == null) return;
    
    final context = navigatorKey.currentContext!;
    final l = AppLocalizations.of(context)!;
    
    // Extraer datos del aviso
    final title = data['title'] ?? l.newNoticePopupTitle;
    final body = data['body'] ?? '';
    final line = data['line'];
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.campaign, color: AlzitransColors.burgundy, size: 28),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (line != null && line.toString().trim().isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AlzitransColors.coral,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${l.line} $line',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(body),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.understood),
          ),
        ],
      ),
    );
  }

  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
