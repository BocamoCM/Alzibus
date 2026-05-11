import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../services/feedback_service.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FeedbackService _feedbackService = FeedbackService.instance;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() => _isLoading = true);
    await _feedbackService.loadMyTickets();
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Ayuda y Soporte'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AlzitransColors.burgundy,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AlzitransColors.burgundy,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AlzitransColors.burgundy,
          tabs: const [
            Tab(text: 'Mis Tickets'),
            Tab(text: 'Abrir Ticket'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTicketsList(),
          _NewTicketForm(
            onSuccess: () {
              _loadTickets();
              _tabController.animateTo(0);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTicketsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_feedbackService.tickets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.help_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No tienes tickets abiertos',
              style: TextStyle(fontSize: 18, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AlzitransColors.burgundy),
              onPressed: () => _tabController.animateTo(1),
              child: const Text('Abrir nuevo ticket'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTickets,
      color: AlzitransColors.burgundy,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _feedbackService.tickets.length,
        itemBuilder: (context, index) {
          final ticket = _feedbackService.tickets[index];
          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Text(
                ticket.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildBadge(ticket.tag, Colors.blueGrey),
                        const SizedBox(width: 8),
                        _buildStatusBadge(ticket.status),
                      ],
                    ),
                  ],
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (ticket.unreadAdminCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AlzitransColors.burgundy,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        ticket.unreadAdminCount > 9 ? '9+' : '${ticket.unreadAdminCount}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => _FeedbackChatScreen(ticket: ticket)),
                ).then((_) => _loadTickets());
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    // El backend devuelve códigos en inglés (open/in_progress/resolved/dismissed),
    // pero por compatibilidad con tickets antiguos también aceptamos las
    // etiquetas en español que pudieran quedar antes de la migración.
    Color color;
    String label;
    switch (status) {
      case 'resolved':
      case 'Resuelto':
        color = Colors.green;
        label = 'Resuelto';
        break;
      case 'in_progress':
      case 'En progreso':
        color = Colors.orange;
        label = 'En progreso';
        break;
      case 'dismissed':
      case 'Desestimado':
      case 'Cerrado':
      case 'closed':
        color = Colors.red;
        label = 'Desestimado';
        break;
      case 'open':
      case 'Abierto':
        color = Colors.blue;
        label = 'Abierto';
        break;
      default:
        color = Colors.blue;
        label = status;
    }
    return _buildBadge(label, color);
  }
}

class _NewTicketForm extends StatefulWidget {
  final VoidCallback onSuccess;
  const _NewTicketForm({required this.onSuccess});

  @override
  State<_NewTicketForm> createState() => _NewTicketFormState();
}

class _NewTicketFormState extends State<_NewTicketForm> {
  final _formKey = GlobalKey<FormState>();
  String _selectedTag = 'Sugerencia';
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  bool _isSubmitting = false;

  final List<String> _tags = ['Bug', 'Queja', 'Sugerencia', 'Ayuda/Duda', 'Otro'];

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final ticket = await FeedbackService.instance.createTicket(
      _selectedTag,
      _titleController.text.trim(),
      _descController.text.trim(),
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (ticket != null) {
        widget.onSuccess();
        _titleController.clear();
        _descController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket enviado correctamente')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al enviar el ticket. Por favor, reintenta.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '¿En qué podemos ayudarte?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedTag,
              decoration: const InputDecoration(
                labelText: 'Categoría',
                border: OutlineInputBorder(),
              ),
              items: _tags.map((tag) {
                return DropdownMenuItem(value: tag, child: Text(tag));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedTag = val);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Resumen breve (Asunto)',
                border: OutlineInputBorder(),
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'El asunto es obligatorio' : null,
              maxLength: 100,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Descripción detallada',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 6,
              validator: (val) => val == null || val.trim().isEmpty ? 'La descripción es obligatoria' : null,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AlzitransColors.burgundy,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Enviar Ticket', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackChatScreen extends StatefulWidget {
  final FeedbackTicket ticket;
  const _FeedbackChatScreen({required this.ticket});

  @override
  State<_FeedbackChatScreen> createState() => _FeedbackChatScreenState();
}

class _FeedbackChatScreenState extends State<_FeedbackChatScreen> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  List<FeedbackMessage> _messages = [];
  bool _isLoading = true;
  Timer? _pollingTimer;
  // Adjuntos pendientes de enviar con el próximo mensaje.
  final List<FeedbackAttachmentUpload> _pendingAttachments = [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
    // Marcar el ticket como leído nada más abrirlo. El backend lo hace
    // automáticamente al pedir /messages, pero llamamos también al endpoint
    // explícito por si el polling fuera más tarde y el badge tarde en bajar.
    FeedbackService.instance.markTicketRead(widget.ticket.id);
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
    final msgs = await FeedbackService.instance.getTicketMessages(widget.ticket.id);
    if (mounted) {
      final isNewMessage = msgs.length > _messages.length;
      setState(() {
        _messages = msgs;
        _isLoading = false;
      });
      if (isNewMessage) {
        _scrollToBottom();
      }
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

  Future<void> _pickAttachment() async {
    // Selector restringido a imágenes (PNG/JPG/WebP). El backend valida
    // los magic bytes igualmente; esto es solo para mejor UX.
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      withData: true, // Necesario para web (no hay path en navegador).
    );
    if (result == null || result.files.isEmpty) return;

    setState(() {
      for (final f in result.files) {
        if (_pendingAttachments.length >= 3) break;
        if (f.bytes != null) {
          _pendingAttachments.add(
            FeedbackAttachmentUpload.fromBytes(f.bytes!, f.name),
          );
        } else if (f.path != null) {
          _pendingAttachments.add(
            FeedbackAttachmentUpload.fromPath(f.path!, filename: f.name),
          );
        }
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty && _pendingAttachments.isEmpty) return;

    final attachmentsToSend = List<FeedbackAttachmentUpload>.from(_pendingAttachments);
    setState(() {
      _msgController.clear();
      _pendingAttachments.clear();
    });

    final result = await FeedbackService.instance.replyToTicket(
      widget.ticket.id,
      text,
      attachments: attachmentsToSend,
    );
    if (result.ok) {
      _loadMessages();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'Error al enviar el mensaje')),
        );
        setState(() {
          // Restauramos el texto para que el usuario no lo pierda.
          _msgController.text = text;
          _pendingAttachments.addAll(attachmentsToSend);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Ticket #${widget.ticket.id}'),
        backgroundColor: Colors.white,
        foregroundColor: AlzitransColors.burgundy,
        elevation: 1,
      ),
      body: Column(
        children: [
          // Cabecera descriptiva
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.ticket.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.ticket.description,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Chat area
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return _buildMessageBubble(msg);
                    },
                  ),
          ),
          // Lista de adjuntos pendientes (si los hay)
          if (_pendingAttachments.isNotEmpty)
            Container(
              color: Colors.grey[200],
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_pendingAttachments.length, (i) {
                  return Chip(
                    avatar: const Icon(Icons.image, size: 18, color: AlzitransColors.burgundy),
                    label: Text(_pendingAttachments[i].filename, overflow: TextOverflow.ellipsis),
                    onDeleted: () => setState(() => _pendingAttachments.removeAt(i)),
                  );
                }),
              ),
            ),
          // Input area
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, -2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file, color: AlzitransColors.burgundy),
                  tooltip: 'Adjuntar imagen',
                  onPressed: _pendingAttachments.length >= 3 ? null : _pickAttachment,
                ),
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    decoration: InputDecoration(
                      hintText: 'Añadir un comentario...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: AlzitransColors.burgundy,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(FeedbackMessage msg) {
    final isMe = !msg.isFromAdmin;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AlzitransColors.burgundy : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('Administrador',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AlzitransColors.burgundy)),
              ),
            if (msg.message.isNotEmpty)
              Text(
                msg.message,
                style: TextStyle(color: isMe ? Colors.white : Colors.black87),
              ),
            // Adjuntos del mensaje (si los hay).
            if (msg.attachments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: msg.attachments
                      .map((a) => _buildAttachmentPreview(a, isMe: isMe))
                      .toList(),
                ),
              ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('HH:mm').format(msg.createdAt.toLocal()),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe ? Colors.white70 : Colors.black54,
                  ),
                ),
                // Doble check estilo WhatsApp solo para mis mensajes:
                // - Un check gris = enviado, pero el admin no lo ha abierto.
                // - Doble check blanco = el admin abrió el ticket → leído.
                if (isMe && msg.id > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      msg.readAt != null ? Icons.done_all : Icons.done,
                      size: 14,
                      color: msg.readAt != null ? Colors.white : Colors.white70,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentPreview(FeedbackAttachment a, {required bool isMe}) {
    if (a.isImage) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220, maxHeight: 220),
            child: _AuthenticatedImage(attachmentId: a.id),
          ),
        ),
      );
    }
    // PDF u otros: tile con icono y nombre.
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isMe ? Colors.white24 : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file,
                size: 18,
                color: isMe ? Colors.white : AlzitransColors.burgundy),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                a.originalName,
                style: TextStyle(
                  fontSize: 12,
                  color: isMe ? Colors.white : Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carga una imagen adjunta con el header de autorización de la sesión.
/// Cachea los bytes en memoria mientras viva el State para no refetchear
/// en cada rebuild del ListView.
class _AuthenticatedImage extends StatefulWidget {
  final int attachmentId;
  const _AuthenticatedImage({required this.attachmentId});

  @override
  State<_AuthenticatedImage> createState() => _AuthenticatedImageState();
}

class _AuthenticatedImageState extends State<_AuthenticatedImage> {
  Uint8List? _bytes;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await ApiClient().dio.get(
        '/feedback/attachments/${widget.attachmentId}',
        options: Options(responseType: ResponseType.bytes),
      );
      if (!mounted) return;
      if (response.statusCode == 200 && response.data is List<int>) {
        setState(() {
          _bytes = Uint8List.fromList(response.data as List<int>);
          _loading = false;
        });
      } else {
        setState(() {
          _error = true;
          _loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
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
