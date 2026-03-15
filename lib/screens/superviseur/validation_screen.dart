import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/services.dart';

class ValidationScreen extends StatefulWidget {
  final AppUser user;
  const ValidationScreen({super.key, required this.user});
  @override
  State<ValidationScreen> createState() => _ValidationScreenState();
}

class _ValidationScreenState extends State<ValidationScreen>
    with SingleTickerProviderStateMixin {
  final _svc = ElectionService();
  late TabController _tabs;
  List<PvResult> _pvs = [];
  List<Document> _docs = [];
  bool _loading = true;
  Timer? _timer;

  bool get _isNational => widget.user.isSuperviseurNational;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
    // Auto-refresh toutes les 30s
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() { _timer?.cancel(); _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final region = widget.user.isSuperviseurRegional ? widget.user.region : null;
    final pvs = await _svc.getPvResults(region: region);
    final docs = await _svc.getDocuments(region: region);
    setState(() { _pvs = pvs; _docs = docs; _loading = false; });
  }

  // ─── Listes filtrées par rôle ─────────────────────────────
  List<PvResult> get _aValider {
    if (_isNational) {
      return _pvs.where((p) => p.statut == 'valide_reg' || p.statut == 'rejete_nat').toList();
    } else {
      // Régional voit les PV soumis ET les PV resoumis après rejet
      return _pvs.where((p) => p.statut == 'soumis').toList();
    }
  }

  // PV que le superviseur peut corriger manuellement
  List<PvResult> get _modifiables {
    if (_isNational) {
      return _pvs.where((p) => p.rejeteNat || p.valideReg).toList();
    } else {
      return _pvs.where((p) => p.rejeteReg || p.valideReg).toList();
    }
  }

  List<PvResult> get _valides {
    if (_isNational) {
      return _pvs.where((p) => p.publie).toList();
    } else {
      return _pvs.where((p) => p.valideReg).toList();
    }
  }

  List<PvResult> get _rejetes {
    if (_isNational) {
      return _pvs.where((p) => p.rejeteNat).toList();
    } else {
      return _pvs.where((p) => p.rejeteReg).toList();
    }
  }

  List<PvResult> get _enAttenteRegion {
    // Pour national: voir les PV pas encore validés par les régionaux
    return _pvs.where((p) => p.statut == 'soumis').toList();
  }

  // ─── Actions ─────────────────────────────────────────────
  Future<void> _valider(PvResult pv) async {
    if (_isNational) {
      await _svc.validerPvNational(pv.id);
    } else {
      await _svc.validerPvRegional(pv.id);
    }
    _load();
  }

  Future<void> _rejeter(PvResult pv) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(context: context,
      builder: (_) => AlertDialog(
        title: const Text('Motif de rejet'),
        content: TextField(controller: ctrl, autofocus: true, maxLines: 2,
            decoration: const InputDecoration(hintText: 'Expliquez le motif...',
                border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rejeter'),
          ),
        ],
      ));
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      if (_isNational) {
        await _svc.rejeterPvNational(pv.id, ctrl.text.trim());
      } else {
        await _svc.rejeterPvRegional(pv.id, ctrl.text.trim());
      }
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Bandeau rôle
      Container(
        color: _isNational ? const Color(0xFF0D47A1) : const Color(0xFF1B5E20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Icon(_isNational ? Icons.public : Icons.location_on,
              color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(
            _isNational
                ? 'Validation nationale — PV validés par les régions'
                : 'Validation régionale ${widget.user.region} — PV soumis par agents',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          )),
          // Stats rapides
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${_aValider.length} en attente',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ]),
      ),

      // Info workflow
      if (!_loading) _workflowBanner(),

      TabBar(
        controller: _tabs,
        labelColor: const Color(0xFF1B5E20),
        indicatorColor: const Color(0xFF1B5E20),
        tabs: [
          Tab(text: 'PV (${_aValider.length} en attente)'),
          Tab(text: 'Documents (${_docs.where((d) => !d.valide).length} en attente)'),
        ],
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(controller: _tabs, children: [_pvTab(), _docTab()]),
      ),
    ]);
  }

  Widget _workflowBanner() {
    if (_isNational) {
      return Container(
        color: Colors.blue[50],
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          const Icon(Icons.info_outline, color: Colors.blue, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(
            'Vous voyez uniquement les PV déjà validés par les superviseurs régionaux. '
            'Après votre validation, les résultats sont publiés sur le Live.',
            style: TextStyle(fontSize: 11, color: Colors.blue[700]),
          )),
        ]),
      );
    }
    // Régional: montrer aussi les PV encore non traités par nat
    if (_enAttenteRegion.isEmpty && _valides.isNotEmpty) {
      return Container(
        color: Colors.green[50],
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Text('${_valides.length} PV transmis au Superviseur National',
              style: TextStyle(fontSize: 11, color: Colors.green[700])),
        ]),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _pvTab() {
    if (_pvs.isEmpty) return const Center(child: Text('Aucun PV reçu'));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(12), children: [

        // En attente de validation
        if (_aValider.isNotEmpty) ...[
          _sectionHeader(
            _isNational ? 'À valider (soumis par régions)' : 'À valider (soumis par agents)',
            _aValider.length, Colors.orange),
          ..._aValider.map((pv) => _pvCard(pv, showActions: true)),
        ],

        // Déjà validés
        if (_valides.isNotEmpty) ...[
          _sectionHeader(
            _isNational ? 'Publiés ✓' : 'Validés — en attente Superviseur National',
            _valides.length, Colors.green),
          ..._valides.map((pv) => _pvCard(pv, showActions: false)),
        ],

        // Rejetés
        if (_rejetes.isNotEmpty) ...[
          _sectionHeader('Rejetés', _rejetes.length, Colors.red),
          ..._rejetes.map((pv) => _pvCard(pv, showActions: false)),
        ],

        // Pour national: voir l'état des validations régionales
        if (_isNational && _enAttenteRegion.isNotEmpty) ...[
          _sectionHeader('En attente de validation régionale', _enAttenteRegion.length, Colors.grey),
          ..._enAttenteRegion.map((pv) => _pvCard(pv, showActions: false, gris: true)),
        ],
      ]),
    );
  }

  Widget _pvCard(PvResult pv, {required bool showActions, bool gris = false}) {
    Color couleur;
    IconData icone;
    String label;

    if (pv.publie) {
      couleur = Colors.green; icone = Icons.public; label = 'Publié ✓';
    } else if (pv.valideReg) {
      couleur = Colors.blue; icone = Icons.verified; label = 'Validé région';
    } else if (pv.rejeteNat) {
      couleur = Colors.red; icone = Icons.cancel; label = 'Rejeté (national)';
    } else if (pv.rejeteReg) {
      couleur = Colors.red; icone = Icons.cancel; label = 'Rejeté (région)';
    } else if (gris) {
      couleur = Colors.grey; icone = Icons.hourglass_empty; label = 'Attente région';
    } else {
      couleur = Colors.orange; icone = Icons.pending; label = 'À valider';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: gris ? Colors.grey[50] : null,
      child: Padding(padding: const EdgeInsets.all(12), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icone, color: couleur, size: 18),
            const SizedBox(width: 8),
            Text(pv.bureauId,
                style: TextStyle(fontWeight: FontWeight.bold, color: couleur, fontSize: 14)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: couleur.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: couleur.withOpacity(0.3)),
              ),
              child: Text(label,
                  style: TextStyle(fontSize: 10, color: couleur, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 6),
            Text(pv.agentCode, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ]),
          const SizedBox(height: 8),
          // Données PV
          Wrap(spacing: 6, runSpacing: 4, children: [
            _chip2('Total: ${pv.totalVotants}', Colors.grey[700]!),
            _chip2('A: ${pv.voixCandidatA}', Colors.blue),
            _chip2('B: ${pv.voixCandidatB}', Colors.red),
            _chip2('Nuls: ${pv.bulletinsNuls}', Colors.grey),
            _chip2('Abst: ${pv.abstentions}', Colors.grey),
          ]),
          if (pv.motifRejet != null) ...[
            const SizedBox(height: 6),
            Text('Motif rejet : ${pv.motifRejet}',
                style: const TextStyle(color: Colors.red, fontSize: 11)),
          ],
          if (showActions) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.cancel, size: 16, color: Colors.red),
                  label: const Text('Rejeter', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                  onPressed: () => _rejeter(pv),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  icon: Icon(_isNational ? Icons.public : Icons.verified, size: 16),
                  label: Text(_isNational ? 'Publier' : 'Valider'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isNational ? const Color(0xFF0D47A1) : Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _valider(pv),
                ),
              ),
            ]),
          ],
        ],
      )),
    );
  }

  Widget _docTab() {
    if (_docs.isEmpty) return const Center(child: Text('Aucun document'));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _docs.length,
        itemBuilder: (ctx, i) {
          final d = _docs[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: d.valide ? Colors.green : Colors.orange,
                child: Icon(d.valide ? Icons.check : Icons.file_copy,
                    color: Colors.white, size: 18)),
              title: Text(d.bureauId, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('OM: ${d.nbOm} | Ordonnances: ${d.nbOrdonnances}\n${d.agentCode}'),
              isThreeLine: true,
              trailing: d.valide
                  ? const Icon(Icons.verified, color: Colors.green)
                  : ElevatedButton(
                      onPressed: () async {
                        await _svc.validerDocument(d.id);
                        _load();
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green, foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                      child: const Text('Valider', style: TextStyle(fontSize: 12)),
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String title, int count, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Icon(Icons.circle, color: color, size: 10),
      const SizedBox(width: 8),
      Text('$title ($count)', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
    ]),
  );

  Widget _chip2(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
    child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
  );
}
