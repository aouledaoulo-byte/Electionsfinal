import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/services.dart';

class AnomaliesScreen extends StatefulWidget {
  final AppUser user;
  const AnomaliesScreen({super.key, required this.user});
  @override
  State<AnomaliesScreen> createState() => _AnomaliesScreenState();
}

class _AnomaliesScreenState extends State<AnomaliesScreen> {
  final _svc = ElectionService();
  List<Anomalie> _anomalies = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final region = widget.user.isSuperviseurRegional ? widget.user.region : null;
    final a = await _svc.getAnomalies(region: region);
    setState(() { _anomalies = a; _loading = false; });
  }

  Color _niveauColor(String niveau) {
    switch (niveau) {
      case 'CRITIQUE': return Colors.red;
      case 'WARNING': return Colors.orange;
      default: return Colors.blue;
    }
  }

  IconData _niveauIcon(String niveau) {
    switch (niveau) {
      case 'CRITIQUE': return Icons.error;
      case 'WARNING': return Icons.warning;
      default: return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final critiques = _anomalies.where((a) => a.niveau == 'CRITIQUE').length;
    final warnings = _anomalies.where((a) => a.niveau == 'WARNING').length;

    return Column(children: [
      if (critiques > 0)
        Container(
          color: Colors.red[50],
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            const Icon(Icons.error, color: Colors.red, size: 18),
            const SizedBox(width: 8),
            Text('$critiques anomalie(s) critique(s) !',
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ]),
        ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _anomalies.isEmpty
                ? const Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 48),
                      SizedBox(height: 12),
                      Text('Aucune anomalie détectée',
                          style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ]))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _anomalies.length,
                      itemBuilder: (ctx, i) {
                        final a = _anomalies[i];
                        final color = _niveauColor(a.niveau);
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Icon(_niveauIcon(a.niveau), color: color, size: 18),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: color.withOpacity(0.4)),
                                    ),
                                    child: Text(a.niveau,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: color,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  const Spacer(),
                                  Text(a.bureauId,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1B5E20))),
                                ]),
                                const SizedBox(height: 8),
                                Text(a.description,
                                    style: const TextStyle(fontSize: 13)),
                                const SizedBox(height: 4),
                                Row(children: [
                                  Text(a.agentCode,
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.grey)),
                                  const Spacer(),
                                  Text(
                                      '${a.createdAt.day}/${a.createdAt.month} ${a.createdAt.hour}:${a.createdAt.minute.toString().padLeft(2, '0')}',
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.grey)),
                                ]),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.check, size: 16),
                                    label: const Text('Marquer comme traitée'),
                                    style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.green,
                                        side: const BorderSide(color: Colors.green)),
                                    onPressed: () async {
                                      await _svc.traiterAnomalie(a.id);
                                      _load();
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    ]);
  }
}
