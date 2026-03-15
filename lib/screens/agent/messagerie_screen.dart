import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/services.dart';

class MessagerieScreen extends StatefulWidget {
  final AppUser user;
  const MessagerieScreen({super.key, required this.user});
  @override
  State<MessagerieScreen> createState() => _MessagerieScreenState();
}

class _MessagerieScreenState extends State<MessagerieScreen> {
  final _svc = ElectionService();
  List<Message> _messages = [];
  bool _loading = true;
  final _ctrl = TextEditingController();
  final _destCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final msgs = await _svc.getMessages(widget.user.code);
    setState(() { _messages = msgs; _loading = false; });
  }

  Future<void> _send() async {
    final msg = _ctrl.text.trim();
    if (msg.isEmpty) return;
    String dest;
    if (widget.user.isAgent) {
      dest = 'SUPERVISEUR';
    } else {
      dest = _destCtrl.text.trim().isEmpty ? 'TOUS' : _destCtrl.text.trim().toUpperCase();
    }
    await _svc.envoyerMessage(widget.user.code, dest, msg);
    _ctrl.clear();
    _destCtrl.clear();
    await _load();
  }

  Future<void> _broadcast() async {
    final msg = _ctrl.text.trim();
    if (msg.isEmpty) return;
    await _svc.broadcastMessage(widget.user.code, msg);
    _ctrl.clear();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message diffusé à tous les agents'),
            backgroundColor: Colors.green));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messagerie'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load)
        ],
      ),
      body: Column(children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? const Center(child: Text('Aucun message envoyé'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, i) {
                          final m = _messages[i];
                          final isMine = m.expediteur == widget.user.code;
                          return Align(
                            alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(12),
                              constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.75),
                              decoration: BoxDecoration(
                                color: isMine ? const Color(0xFF1B5E20) : Colors.grey[200],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: isMine
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  if (!isMine)
                                    Text(m.expediteur,
                                        style: TextStyle(
                                            fontSize: 11, color: Colors.grey[600],
                                            fontWeight: FontWeight.bold)),
                                  Text(m.contenu,
                                      style: TextStyle(
                                          color: isMine ? Colors.white : Colors.black)),
                                  Text(
                                      '${m.createdAt.hour}:${m.createdAt.minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: isMine ? Colors.white60 : Colors.grey)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),

        // Zone de saisie
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.white,
          child: Column(children: [
            if (widget.user.isSuperviseur) ...[
              TextField(
                controller: _destCtrl,
                decoration: const InputDecoration(
                  hintText: 'Destinataire (vide = TOUS)',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  decoration: const InputDecoration(
                    hintText: 'Votre message...',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              if (widget.user.isSuperviseur)
                IconButton(
                  icon: const Icon(Icons.campaign, color: Colors.orange),
                  tooltip: 'Diffuser à tous',
                  onPressed: _broadcast,
                ),
              IconButton(
                icon: const Icon(Icons.send, color: Color(0xFF1B5E20)),
                onPressed: _send,
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}
