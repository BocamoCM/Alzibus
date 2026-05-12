// El admin panel es una app exclusivamente web, así que dart:html es la
// elección más simple para el file picker nativo. Silenciamos los lints
// pensados para apps multiplataforma.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';

class FeedbackAdminScreen extends StatefulWidget {
  const FeedbackAdminScreen({super.key});

  @override
  State<FeedbackAdminScreen> createState() => _FeedbackAdminScreenState();
}

// Códigos de estado canónicos del backend (inglés) y sus etiquetas en español
// para mostrarlas en la UI. Antes el panel enviaba directamente la etiqueta
// en español al backend, que la rechazaba con 400.
const String _kStatusAll = 'all';
const Map<String, String> _statusLabels = {
  _kStatusAll:   'Todos',
  'open':        'Abierto',
  'in_progress': 'En progreso',
  'resolved':    'Resuelto',
  'dismissed':   'Desestimado',
};
// Aliases para tickets antiguos que en BD todavía tengan etiquetas en español.
// La migración del backend los normaliza, pero por si acaso el panel los
// recibe antes del primer arranque post-migración.
String _normalizeStatusCode(String? raw) {
  switch (raw) {
    case 'Abierto':      return 'open';
    case 'En progreso':  return 'in_progress';
    case 'Resuelto':     return 'resolved';
    case 'Desestimado':
    case 'Cerrado':
    case 'closed':       return 'dismissed';
    case 'open':
    case 'in_progress':
    case 'resolved':
    case 'dismissed':    return raw!;
    default:             return 'open';
  }
}
String _labelFor(String code) => _statusLabels[code] ?? code;

class _FeedbackAdminScreenState extends State<FeedbackAdminScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _tickets = [];
  List<Map<String, dynamic>> _filteredTickets = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _statusFilter = _kStatusAll;

  // Códigos válidos del filtro (incluye 'all' como "Todos").
  final List<String> _statusCodes = const [
    _kStatusAll, 'open', 'in_progress', 'resolved', 'dismissed',
  ];

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() => _isLoading = true);
    try {
      final data = await _api.getFeedbackTickets();
      setState(() {
        _tickets = data;
        _applyFilters();
      });
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    _filteredTickets = _tickets.where((ticket) {
      final matchesSearch = ticket['user_email'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
                            ticket['title'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final ticketStatus = _normalizeStatusCode(ticket['status'] as String?);
      final matchesStatus = _statusFilter == _kStatusAll || ticketStatus == _statusFilter;
      return matchesSearch && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Gestión de Soporte y Feedback',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadTickets,
                tooltip: 'Actualizar',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Buscar por usuario o asunto...',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                      _applyFilters();
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<String>(
                  value: _statusFilter,
                  decoration: const InputDecoration(
                    labelText: 'Estado',
                    border: OutlineInputBorder(),
                  ),
                  items: _statusCodes.map((code) => DropdownMenuItem(value: code, child: Text(_labelFor(code)))).toList(),
                  onChanged: (val) {
                    setState(() {
                      _statusFilter = val!;
                      _applyFilters();
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Card(
                    elevation: 4,
                    child: ListView.separated(
                      itemCount: _filteredTickets.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final ticket = _filteredTickets[index];
                        final statusCode = _normalizeStatusCode(ticket['status'] as String?);
                        final unread = (ticket['unread_user_count'] as num?)?.toInt() ?? 0;
                        return ListTile(
                          leading: _buildStatusIcon(statusCode),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(ticket['title'],
                                    style: TextStyle(
                                      fontWeight: unread > 0 ? FontWeight.w900 : FontWeight.bold,
                                    )),
                              ),
                              if (unread > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    unread > 9 ? '9+ nuevos' : '$unread nuevo${unread > 1 ? 's' : ''}',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text('${ticket['user_email']} · ${ticket['tag']} · ${_labelFor(statusCode)}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openTicketDialog(ticket),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(String statusCode) {
    IconData icon;
    Color color;
    switch (statusCode) {
      case 'open':
        icon = Icons.mark_email_unread;
        color = Colors.blue;
        break;
      case 'in_progress':
        icon = Icons.autorenew;
        color = Colors.orange;
        break;
      case 'resolved':
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 'dismissed':
        icon = Icons.cancel;
        color = Colors.red;
        break;
      default:
        icon = Icons.help;
        color = Colors.grey;
    }
    return CircleAvatar(backgroundColor: color.withOpacity(0.2), child: Icon(icon, color: color));
  }

  void _openTicketDialog(Map<String, dynamic> ticket) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _FeedbackChatDialog(
        ticket: ticket,
        onStatusChanged: () => _loadTickets(),
      ),
    );
  }
}

class _FeedbackChatDialog extends StatefulWidget {
  final Map<String, dynamic> ticket;
  final VoidCallback onStatusChanged;
  const _FeedbackChatDialog({required this.ticket, required this.onStatusChanged});

  @override
  State<_FeedbackChatDialog> createState() => _FeedbackChatDialogState();
}

class _FeedbackChatDialogState extends State<_FeedbackChatDialog> {
  final ApiService _api = ApiService();
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  Timer? _pollingTimer;
  late String _currentStatus;
  // Archivos seleccionados pendientes de subir con la próxima respuesta.
  final List<({String filename, Uint8List bytes})> _pendingAttachments = [];
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _currentStatus = _normalizeStatusCode(widget.ticket['status'] as String?);
    _loadMessages();
    // Marcar como leídos los mensajes del usuario al abrir el chat. El
    // backend ya lo hace al pedir /replies pero llamamos también al endpoint
    // explícito para refrescar el badge de la lista cuanto antes.
    _api.markFeedbackTicketRead(widget.ticket['id'] as int)
        .then((_) => widget.onStatusChanged());
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) => _loadMessages());
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final msgs = await _api.getFeedbackReplies(widget.ticket['id']);
      if (mounted) {
        final isNew = msgs.length > _messages.length;
        setState(() {
          _messages = msgs;
          _isLoading = false;
        });
        if (isNew) _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  // Selector de ficheros vía API nativa del navegador. Evitamos el plugin
  // file_picker porque su build de Flutter Web tiene un bug de inicialización
  // late en la versión 8.x. El admin panel es web-only, así que usar
  // dart:html es la solución más simple y robusta.
  Future<void> _pickAttachment() async {
    final input = html.FileUploadInputElement()
      ..accept = '.png,.jpg,.jpeg,.webp,.pdf,image/png,image/jpeg,image/webp,application/pdf'
      ..multiple = true;
    input.click();

    // Esperamos a que el usuario elija algo (evento change) o cancele
    // (no se dispara change si cierra el diálogo — el future queda colgado,
    // por eso usamos también onCancel cuando esté disponible).
    await input.onChange.first;
    final files = input.files;
    if (files == null || files.isEmpty) return;

    for (final file in files) {
      if (_pendingAttachments.length >= 3) break;
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      await reader.onLoad.first;
      final bytes = reader.result;
      if (bytes is Uint8List) {
        setState(() {
          _pendingAttachments.add((filename: file.name, bytes: bytes));
        });
      } else if (bytes is List<int>) {
        setState(() {
          _pendingAttachments.add((filename: file.name, bytes: Uint8List.fromList(bytes)));
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty && _pendingAttachments.isEmpty) return;
    if (_isSending) return;

    setState(() => _isSending = true);
    final toSend = List<({String filename, List<int> bytes})>.from(
      _pendingAttachments.map((a) => (filename: a.filename, bytes: a.bytes.toList())),
    );

    final success = await _api.replyToFeedbackTicket(
      widget.ticket['id'] as int,
      text,
      attachments: toSend,
    );

    if (!mounted) return;
    if (success) {
      _msgController.clear();
      _pendingAttachments.clear();
      _loadMessages();
      // Si estaba resuelto/desestimado, el backend lo pasa a in_progress
      // automáticamente al responder. Reflejamos el cambio en la UI.
      if (_currentStatus == 'resolved' || _currentStatus == 'dismissed') {
        setState(() => _currentStatus = 'in_progress');
        widget.onStatusChanged();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error enviando respuesta')),
      );
    }
    setState(() => _isSending = false);
  }

  Future<void> _editMessage(int replyId, String currentText) async {
    final ctrl = TextEditingController(text: currentText);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Editar mensaje'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 5,
          minLines: 2,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty || result == currentText) return;

    final ok = await _api.editAdminReply(replyId, result);
    if (!mounted) return;
    if (ok) {
      _loadMessages();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mensaje editado')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo editar el mensaje')),
      );
    }
  }

  Future<void> _deleteMessage(int replyId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Borrar mensaje'),
        content: const Text('¿Borrar este mensaje y sus adjuntos? No se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Borrar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final ok = await _api.deleteAdminReply(replyId);
    if (!mounted) return;
    if (ok) {
      _loadMessages();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo borrar el mensaje')),
      );
    }
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final isAdmin = msg['sender_type'] == 'admin';
    final createdAt = DateTime.tryParse(msg['created_at']?.toString() ?? '')?.toLocal();
    final readAt = msg['read_at'] == null ? null : DateTime.tryParse(msg['read_at'].toString());
    final editedAt = msg['edited_at'] == null ? null : DateTime.tryParse(msg['edited_at'].toString());
    final attachments = (msg['attachments'] as List?)?.cast<dynamic>() ?? const [];
    final messageText = msg['message']?.toString() ?? '';
    final replyId = (msg['id'] as num?)?.toInt();

    return Align(
      alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: isAdmin ? Colors.blue[100] : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: Text(isAdmin ? 'Administrador' : 'Usuario',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                // Menú de acciones solo en MIS mensajes (admin) y solo si
                // tenemos id (no en optimistic updates sin persistir).
                if (isAdmin && replyId != null)
                  SizedBox(
                    height: 20,
                    width: 24,
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      iconSize: 16,
                      tooltip: 'Acciones',
                      onSelected: (a) {
                        if (a == 'edit') _editMessage(replyId, messageText);
                        if (a == 'delete') _deleteMessage(replyId);
                      },
                      itemBuilder: (ctx) => const [
                        PopupMenuItem(value: 'edit', child: Row(children: [
                          Icon(Icons.edit, size: 16), SizedBox(width: 8), Text('Editar'),
                        ])),
                        PopupMenuItem(value: 'delete', child: Row(children: [
                          Icon(Icons.delete_outline, size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Borrar', style: TextStyle(color: Colors.red)),
                        ])),
                      ],
                    ),
                  ),
              ],
            ),
            if (messageText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(messageText),
              ),
            if (attachments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: attachments
                      .whereType<Map>()
                      .map((a) => _buildAttachmentPreview(Map<String, dynamic>.from(a)))
                      .toList(),
                ),
              ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (createdAt != null)
                  Text(
                    DateFormat('HH:mm').format(createdAt),
                    style: const TextStyle(fontSize: 10, color: Colors.black54),
                  ),
                if (editedAt != null) ...[
                  const SizedBox(width: 4),
                  const Text('(editado)', style: TextStyle(fontSize: 10, color: Colors.black54, fontStyle: FontStyle.italic)),
                ],
                // Doble check WhatsApp para mis mensajes (admin → usuario).
                if (isAdmin)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      readAt != null ? Icons.done_all : Icons.done,
                      size: 14,
                      color: readAt != null ? Colors.blue : Colors.black45,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentPreview(Map<String, dynamic> a) {
    final id = (a['id'] as num?)?.toInt();
    final mime = a['mime_type']?.toString() ?? '';
    final name = a['original_name']?.toString() ?? 'archivo';
    if (id == null) return const SizedBox.shrink();

    if (mime.startsWith('image/')) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260, maxHeight: 260),
            child: _AdminAuthImage(attachmentId: id),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf, size: 18, color: Colors.red),
            const SizedBox(width: 6),
            Flexible(child: Text(name, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(String newStatusCode) async {
    // Enviamos siempre el código en inglés al backend (lo que ahora espera).
    final success = await _api.updateFeedbackTicketStatus(widget.ticket['id'], newStatusCode);
    if (success) {
      setState(() => _currentStatus = newStatusCode);
      widget.onStatusChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Estado actualizado a ${_labelFor(newStatusCode)}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 800,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ticket #${widget.ticket['id']} - ${widget.ticket['user_email']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                      Text('${widget.ticket['title']} [${widget.ticket['tag']}]', style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
                DropdownButton<String>(
                  value: _currentStatus,
                  items: const ['open', 'in_progress', 'resolved', 'dismissed']
                      .map((code) => DropdownMenuItem(value: code, child: Text(_labelFor(code))))
                      .toList(),
                  onChanged: (val) {
                    if (val != null && val != _currentStatus) {
                      _updateStatus(val);
                    }
                  },
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(),
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              color: Colors.grey[100],
              child: Text(widget.ticket['description'], style: const TextStyle(fontStyle: FontStyle.italic)),
            ),
            const Divider(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: _messages.length,
                      itemBuilder: (context, index) => _buildMessageBubble(_messages[index]),
                    ),
            ),
            if (_pendingAttachments.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Wrap(
                  spacing: 8,
                  children: List.generate(_pendingAttachments.length, (i) {
                    return Chip(
                      avatar: const Icon(Icons.attach_file, size: 18),
                      label: Text(_pendingAttachments[i].filename),
                      onDeleted: () => setState(() => _pendingAttachments.removeAt(i)),
                    );
                  }),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  tooltip: 'Adjuntar (imágenes o PDF)',
                  onPressed: _pendingAttachments.length >= 3 ? null : _pickAttachment,
                ),
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    decoration: const InputDecoration(
                      hintText: 'Escribir respuesta al usuario...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: _isSending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send, color: Colors.blue),
                  onPressed: _isSending ? null : _sendMessage,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Carga una imagen de adjunto con la sesión admin (X-API-Key + Bearer).
/// Cachea los bytes en memoria mientras viva el State para no refetchear.
class _AdminAuthImage extends StatefulWidget {
  final int attachmentId;
  const _AdminAuthImage({required this.attachmentId});

  @override
  State<_AdminAuthImage> createState() => _AdminAuthImageState();
}

class _AdminAuthImageState extends State<_AdminAuthImage> {
  Uint8List? _bytes;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bytes = await ApiService().downloadFeedbackAttachment(widget.attachmentId);
    if (!mounted) return;
    setState(() {
      _bytes = bytes;
      _loading = false;
      _error = bytes == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        width: 80,
        height: 80,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_error || _bytes == null) {
      return Container(
        width: 80,
        height: 80,
        color: Colors.grey[300],
        child: const Icon(Icons.broken_image, color: Colors.grey),
      );
    }
    return Image.memory(_bytes!, fit: BoxFit.cover);
  }
}
