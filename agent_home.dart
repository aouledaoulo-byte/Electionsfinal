import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../services/services.dart';
import '../../models/models.dart';
import '../../utils/constants.dart';
import '../login_screen.dart';
import 'agent_bureau_detail.dart';

class AgentHome extends StatefulWidget {
  const AgentHome({super.key});
  @override
  State<AgentHome> createState() => _AgentHomeState();
}

class _AgentHomeState extends State<AgentHome> {
  final _data = DataService();
  final _auth = AuthService();
  List<Bureau> _bureaux = [];
  bool _loading = true;
  bool _online = true;
  String _nomAgent = '';
  String _agentId = '';

  @override
  void initState() {
    super.initState();
    _init();
    Connectivity().onConnectivityChanged.listen((result) {
      setState(() => _online = result != ConnectivityResult.none);
    });
  }

  Future<void> _init() async {
    _nomAgent = await _auth.getUserNom() ?? '';
    _agentId = await _auth.getUserId() ?? '';
    await _chargerBureaux();
  }

  Future<void> _chargerBureaux() async {
    setState(() => _loading = true);
    try {
      final b = await _data.getBureauxAgent(_agentId);
      setState(() { _bureaux = b; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Bureaux'),
        actions: [
          if (!_online)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(12)),
              child: const Row(children: [
                Icon(Icons.wifi_off, size: 14, color: Colors.white),
                SizedBox(width: 4),
                Text('Hors ligne', style: TextStyle(color: Colors.white, fontSize: 12)),
              ]),
            ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: Column(
        children: [
          // En-tête agent
          Container(
            width: double.infinity,
            color: const Color(0xFF1B5E20),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Agent terrain', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                  Text(_nomAgent, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ]),
              ],
            ),
          ),

          // Liste bureaux
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _bureaux.isEmpty
                    ? _emptyState()
                    : RefreshIndicator(
                        onRefresh: _chargerBureaux,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _bureaux.length,
                          itemBuilder: (_, i) => _bureauCard(_bureaux[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _bureauCard(Bureau b) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => AgentBureauDetail(bureau: b, agentId: _agentId))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.ballot, color: Color(0xFF1B5E20)),
              const SizedBox(width: 8),
              Expanded(child: Text(b.nom,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 6, children: [
              _chip(Icons.location_on, b.region, Colors.blue),
              _chip(Icons.location_city, b.commune, Colors.teal),
              _chip(Icons.school, b.centre, Colors.purple),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _infoBox('Inscrits', b.inscrits.toString(), Colors.grey.shade100),
              const SizedBox(width: 8),
              _infoBox('Corrigés', b.inscritsCorriges.toString(), const Color(0xFFE8F5E9)),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Chip(
      avatar: Icon(icon, size: 14, color: color),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _infoBox(String label, String value, Color bg) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ]),
    ));
  }

  Widget _emptyState() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.ballot_outlined, size: 64, color: Colors.grey.shade300),
      const SizedBox(height: 16),
      const Text('Aucun bureau affecté', style: TextStyle(color: Colors.grey, fontSize: 16)),
      const SizedBox(height: 8),
      const Text('Contactez votre superviseur', style: TextStyle(color: Colors.grey, fontSize: 13)),
    ]),
  );
}
