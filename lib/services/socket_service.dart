import 'dart:async';
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
  final _attendeesController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onAttendeesUpdate => _attendeesController.stream;

  void initialize() {
    if (_socket != null && _socket!.connected) return;

    // Remueve '/api' de la URL base para conectar al servidor raíz de WebSockets.
    final wsUrl = AppConfig.baseUrl.replaceAll('/api', '');
    
    _socket = IO.io(wsUrl, <String, dynamic>{
      // 'transports': ['websocket'], // Permite negociación (polling -> websocket) para mayor compatibilidad
      'autoConnect': true,
    });

    _socket!.onConnect((_) {
      debugPrint('[SocketService] Conectado a WebSockets');
    });

    _socket!.on('new_notice', (data) {
      debugPrint('[SocketService] Nuevo aviso recibido: $data');
      _showNoticeDialog(data);
    });

    _socket!.on('bus_attendees_update', (data) {
      debugPrint('[SocketService] Actualización de pasajeros: $data');
      _attendeesController.add(Map<String, dynamic>.from(data));
    });

    _socket!.onDisconnect((_) {
      debugPrint('[SocketService] Desconectado de WebSockets');
      // Fix #5: Auto-reconexión tras 5 segundos (evita perder avisos por caídas de 4G)
      Future.delayed(const Duration(seconds: 5), () {
        if (_socket != null && !_socket!.connected) {
          debugPrint('[SocketService] Intentando reconexión...');
          _socket!.connect();
        }
      });
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

  void emitAttendBus(String line, String stopId) {
    if (_socket == null || !_socket!.connected) return;
    _socket!.emit('attend_bus', {
      'line': line,
      'stopId': stopId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    // Fix #1: Cerrar el StreamController para liberar la memoria correctamente
    if (!_attendeesController.isClosed) {
      _attendeesController.close();
    }
  }
}
