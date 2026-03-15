import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/services.dart';

class DocumentsScreen extends StatefulWidget {
  final AppUser user;
  final Bureau bureau;
  const DocumentsScreen({super.key, required this.user, required this.bureau});
  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _svc = ElectionService();
  Document? _docExist;
  bool _loading = true;
  bool _modeModif = false;
  final _omCtrl = TextEditingController();
  final _ordCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final docs = await _svc.getDocuments();
    Document? d;
    try { d = docs.firstWhere((doc) => doc.bureauId == widget.bureau.id); }
    catch (_) {}
    setState(() { _docExist = d; _loading = false; });
  }

  Future<void> _submit() async {
    final om = int.tryParse(_omCtrl.text);
    final ord = int.tryParse(_ordCtrl.text);
    if (om == null || ord == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Remplissez tous les champs')));
      return;
    }
    setState(() => _loading = true);
    final ok = await _svc.soumettreDocuments(
        widget.bureau.id, widget.user.code, om, ord);
    if (ok) {
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Documents soumis'), backgroundColor: Colors.green));
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Documents'),
          backgroundColor: const Color(0xFF1B5E20), foregroundColor: Colors.white),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              Card(color: Colors.orange[50],
                  child: Padding(padding: const EdgeInsets.all(12),
                      child: Text(widget.bureau.nom,
                          style: const TextStyle(fontWeight: FontWeight.bold)))),
              const SizedBox(height: 16),
              if (_docExist != null)
                Card(color: _docExist!.valide ? Colors.green[50] : Colors.orange[50],
                    child: ListTile(
                      leading: Icon(_docExist!.valide ? Icons.verified : Icons.pending,
                          color: _docExist!.valide ? Colors.green : Colors.orange),
                      title: Text(_docExist!.valide ? 'Documents validés ✓' : 'En attente'),
                      subtitle: Text('OM: ${_docExist!.nbOm} | Ordonnances: ${_docExist!.nbOrdonnances}'),
                    )),
              if (_docExist == null || _modeModif) ...[
                Card(child: Padding(padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Saisir les documents',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      TextField(controller: _omCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Nombre d\'OM', border: OutlineInputBorder(), isDense: true)),
                      const SizedBox(height: 12),
                      TextField(controller: _ordCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Nombre d\'ordonnances', border: OutlineInputBorder(), isDense: true)),
                      const SizedBox(height: 16),
                      SizedBox(width: double.infinity,
                          child: ElevatedButton.icon(
                              icon: const Icon(Icons.upload),
                              label: const Text('Soumettre'),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1B5E20),
                                  foregroundColor: Colors.white),
                              onPressed: _submit)),
                    ]))),
              ],
            ]),
    );
  }
}
