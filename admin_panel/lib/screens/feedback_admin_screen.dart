import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';

class FeedbackAdminScreen extends StatefulWidget {
  const FeedbackAdminScreen({super.key});

  @override
  State<FeedbackAdminScreen> createState() => _FeedbackAdminScreenState();
}

class _FeedbackAdminScreenState extends State<FeedbackAdminScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _tickets = [];
  List<Map<String, dynamic>> _filteredTickets = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _statusFilter = 'Todos';

  final List<String> _statuses = ['Todos', 'Abierto', 'En progreso', 'Resuelto', 'Desestimado'];

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
      final matchesStatus = _statusFilter == 'Todos' || ticket['status'] == _statusFilter;
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
                  items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
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
                        return ListTile(
                          leading: _buildStatusIcon(ticket['status']),
                          title: Text(ticket['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${ticket['user_email']} - ${ticket['tag']}'),
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

  Widget _buildStatusIcon(String status) {
    IconData icon;
    Color color;
    switch (status) {
      case 'Abierto':
        icon = Icons.mark_email_unread;
        color = Colors.blue;
        break;
      case 'En progreso':
        icon = Icons.autorenew;
        color = Colors.orange;
        break;
      case 'Resuelto':
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 'Desestimado':
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

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.ticket['status'] as String;
    _loadMessages();
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

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    final success = await _api.replyToFeedbackTicket(widget.ticket['id'], text);
    if (success) {
      _msgController.clear();
      _loadMessages();
      // Si estaba resuelto, el backend lo pasa a En progreso. Lo refrejamos en UI.
      if (_currentStatus == 'Resuelto' || _currentStatus == 'Cerrado') {
        setState(() => _currentStatus = 'En progreso');
        widget.onStatusChanged();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error enviando respuesta')));
      }
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    final success = await _api.updateFeedbackTicketStatus(widget.ticket['id'], newStatus);
    if (success) {
      setState(() => _currentStatus = newStatus);
      widget.onStatusChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Estado actualizado a $newStatus')));
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
                  items: ['Abierto', 'En progreso', 'Resuelto', 'Desestimado'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
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
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isAdmin = msg['sender_type'] == 'admin';
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
                                Text(isAdmin ? 'Administrador' : 'Usuario', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                Text(msg['message']),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
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
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
