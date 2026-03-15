import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/services.dart';

/// Permet au superviseur de saisir ou corriger des données pour n'importe quel bureau
class SaisieManuelleScreen extends StatefulWidget {
  final AppUser user;
  const SaisieManuelleScreen({super.key, required this.user});
  @override
  State<SaisieManuelleScreen> createState() => _SaisieManuelleScreenState();
}

class _SaisieManuelleScreenState extends State<SaisieManuelleScreen>
    with SingleTickerProviderStateMixin {
  final _svc = ElectionService();
  late TabController _tabs;
  List<Bureau> _bureaux = [];
  Bureau? _bureauSelect;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final region = widget.user.isSuperviseurRegional ? widget.user.region : null;
    final b = await _svc.getBureaux(region: region);
    setState(() { _bureaux = b; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saisie manuelle'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.credit_card, size: 16), text: 'Cartes'),
            Tab(icon: Icon(Icons.bar_chart, size: 16), text: 'Relevé'),
            Tab(icon: Icon(Icons.how_to_vote, size: 16), text: 'PV'),
            Tab(icon: Icon(Icons.file_copy, size: 16), text: 'Documents'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              // Sélecteur de bureau
              Container(
                color: Colors.grey[100],
                padding: const EdgeInsets.all(12),
                child: DropdownButtonFormField<Bureau>(
                  value: _bureauSelect,
                  decoration: InputDecoration(
                    labelText: 'Choisir le bureau',
                    prefixIcon: const Icon(Icons.location_on),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  hint: const Text('Sélectionner un bureau...'),
                  items: _bureaux.map((b) => DropdownMenuItem(
                    value: b,
                    child: Text('${b.id} — ${b.nom}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13)),
                  )).toList(),
                  onChanged: (v) => setState(() => _bureauSelect = v),
                ),
              ),
              Expanded(
                child: _bureauSelect == null
                    ? const Center(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.touch_app, size: 48, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('Sélectionnez un bureau ci-dessus',
                              style: TextStyle(color: Colors.grey)),
                        ]))
                    : TabBarView(
                        controller: _tabs,
                        children: [
                          _CartesTab(user: widget.user, bureau: _bureauSelect!, svc: _svc),
                          _ReleveTab(user: widget.user, bureau: _bureauSelect!, svc: _svc),
                          _PvTab(user: widget.user, bureau: _bureauSelect!, svc: _svc),
                          _DocTab(user: widget.user, bureau: _bureauSelect!, svc: _svc),
                        ],
                      ),
              ),
            ]),
    );
  }
}

// ─── Onglet Relevé ────────────────────────────────────────────
class _ReleveTab extends StatefulWidget {
  final AppUser user;
  final Bureau bureau;
  final ElectionService svc;
  const _ReleveTab({required this.user, required this.bureau, required this.svc});
  @override State<_ReleveTab> createState() => _ReleveTabState();
}

class _ReleveTabState extends State<_ReleveTab> {
  List<TurnoutSnapshot> _snaps = [];
  bool _loading = true;
  int _heure = DateTime.now().hour.clamp(7, 17);
  final _ctrl = TextEditingController();
  final List<int> _heures = [7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17];

  @override
  void initState() { super.initState(); _load(); }

  @override
  void didUpdateWidget(_ReleveTab old) {
    super.didUpdateWidget(old);
    if (old.bureau.id != widget.bureau.id) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final s = await widget.svc.getTurnoutBureau(widget.bureau.id);
    setState(() { _snaps = s; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return _loading ? const Center(child: CircularProgressIndicator())
        : ListView(padding: const EdgeInsets.all(14), children: [
            Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Saisir relevé — ${widget.bureau.id}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text('${widget.bureau.inscrits} inscrits',
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _heure,
                      decoration: const InputDecoration(labelText: 'Heure',
                          border: OutlineInputBorder(), isDense: true),
                      items: _heures.map((h) => DropdownMenuItem(
                          value: h, child: Text('${h}h00'))).toList(),
                      onChanged: (v) => setState(() => _heure = v!),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(flex: 2,
                    child: TextField(controller: _ctrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Votants',
                          hintText: '/ ${widget.bureau.inscrits}',
                          border: const OutlineInputBorder(), isDense: true,
                        )),
                  ),
                ]),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('Enregistrer'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E20), foregroundColor: Colors.white),
                    onPressed: () async {
                      final val = int.tryParse(_ctrl.text);
                      if (val == null) return;
                      // Code agent correspondant au bureau
                      final agentCode = 'AGT-${widget.bureau.id.replaceAll(RegExp(r'[^0-9]'), '')}';
                      await widget.svc.soumettreTurnout(
                          widget.bureau.id, agentCode, _heure, val);
                      _ctrl.clear();
                      await _load();
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Relevé enregistré ✓'),
                              backgroundColor: Colors.green));
                    },
                  ),
                ),
              ],
            ))),
            const SizedBox(height: 12),
            const Text('Relevés existants', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            if (_snaps.isEmpty)
              const Text('Aucun relevé', style: TextStyle(color: Colors.grey))
            else
              ..._snaps.map((s) => Card(
                margin: const EdgeInsets.only(bottom: 4),
                child: ListTile(dense: true,
                  leading: CircleAvatar(radius: 16,
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    child: Text('${s.heure}h', style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue))),
                  title: Text('${s.votants} votants'),
                  subtitle: Text(widget.bureau.inscrits > 0
                      ? '${(s.votants / widget.bureau.inscrits * 100).toStringAsFixed(1)}% de participation'
                      : ''),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 4),
                    // Bouton modifier
                    IconButton(
                      icon: const Icon(Icons.edit, size: 16, color: Colors.orange),
                      tooltip: 'Modifier',
                      onPressed: () async {
                        final ctrl = TextEditingController(text: s.votants.toString());
                        final ok = await showDialog<bool>(context: context,
                          builder: (_) => AlertDialog(
                            title: Text('Modifier relevé ${s.heure}h'),
                            content: TextField(controller: ctrl,
                                keyboardType: TextInputType.number, autofocus: true,
                                decoration: const InputDecoration(
                                    labelText: 'Votants', border: OutlineInputBorder())),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Annuler')),
                              ElevatedButton(onPressed: () => Navigator.pop(context, true),
                                  child: const Text('OK')),
                            ],
                          ));
                        if (ok == true) {
                          final val = int.tryParse(ctrl.text);
                          if (val == null) return;
                          final agentCode = 'AGT-${widget.bureau.id.replaceAll(RegExp(r'[^0-9]'), '')}';
                          await widget.svc.soumettreTurnout(
                              widget.bureau.id, agentCode, s.heure, val);
                          await _load();
                        }
                      },
                    ),
                  ]),
                ),
              )),
          ]);
  }
}

// ─── Onglet PV ────────────────────────────────────────────────
class _PvTab extends StatefulWidget {
  final AppUser user;
  final Bureau bureau;
  final ElectionService svc;
  const _PvTab({required this.user, required this.bureau, required this.svc});
  @override State<_PvTab> createState() => _PvTabState();
}

class _PvTabState extends State<_PvTab> {
  PvResult? _pv;
  bool _loading = true;
  final _totalCtrl = TextEditingController();
  final _aCtrl = TextEditingController();
  final _bCtrl = TextEditingController();
  final _nulsCtrl = TextEditingController();
  final _abstCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  @override
  void didUpdateWidget(_PvTab old) {
    super.didUpdateWidget(old);
    if (old.bureau.id != widget.bureau.id) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final pv = await widget.svc.getPvBureau(widget.bureau.id);
    if (pv != null) {
      _totalCtrl.text = pv.totalVotants.toString();
      _aCtrl.text = pv.voixCandidatA.toString();
      _bCtrl.text = pv.voixCandidatB.toString();
      _nulsCtrl.text = pv.bulletinsNuls.toString();
      _abstCtrl.text = pv.abstentions.toString();
    }
    setState(() { _pv = pv; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return _loading ? const Center(child: CircularProgressIndicator())
        : ListView(padding: const EdgeInsets.all(14), children: [
            if (_pv != null) ...[
              Card(
                color: _pv!.valide ? Colors.green[50] : _pv!.rejete ? Colors.red[50] : Colors.orange[50],
                child: ListTile(
                  leading: Icon(
                    _pv!.valide ? Icons.verified : _pv!.rejete ? Icons.cancel : Icons.pending,
                    color: _pv!.valide ? Colors.green : _pv!.rejete ? Colors.red : Colors.orange),
                  title: Text(_pv!.valide ? 'PV Validé' : _pv!.rejete ? 'PV Rejeté' : 'En attente'),
                  subtitle: _pv!.motifRejet != null ? Text(_pv!.motifRejet!) : null,
                ),
              ),
              const SizedBox(height: 12),
            ],
            Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_pv != null ? 'Modifier les résultats' : 'Saisir les résultats',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text('${widget.bureau.id} — ${widget.bureau.nom}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 14),
                _field(_totalCtrl, 'Total votants', Icons.people),
                const SizedBox(height: 10),
                _field(_aCtrl, 'Voix Candidat A', Icons.person, color: Colors.blue),
                const SizedBox(height: 10),
                _field(_bCtrl, 'Voix Candidat B', Icons.person, color: Colors.red),
                const SizedBox(height: 10),
                _field(_nulsCtrl, 'Bulletins nuls', Icons.block),
                const SizedBox(height: 10),
                _field(_abstCtrl, 'Abstentions', Icons.remove_circle_outline),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: Text(_pv != null ? 'Mettre à jour' : 'Soumettre le PV'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E20), foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: () async {
                      final total = int.tryParse(_totalCtrl.text);
                      final a = int.tryParse(_aCtrl.text);
                      final b = int.tryParse(_bCtrl.text);
                      final nuls = int.tryParse(_nulsCtrl.text);
                      final abst = int.tryParse(_abstCtrl.text);
                      if ([total, a, b, nuls, abst].any((v) => v == null)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Remplissez tous les champs')));
                        return;
                      }
                      final agentCode = 'AGT-${widget.bureau.id.replaceAll(RegExp(r'[^0-9]'), '')}';
                      await widget.svc.soumettreResultats(PvResult(
                        id: '', bureauId: widget.bureau.id, agentCode: agentCode,
                        totalVotants: total!, bulletinsNuls: nuls!, abstentions: abst!,
                        voixCandidatA: a!, voixCandidatB: b!, createdAt: DateTime.now(),
                      ));
                      await _load();
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('PV enregistré ✓'),
                              backgroundColor: Colors.green));
                    },
                  ),
                ),
              ],
            ))),
          ]);
  }

  Widget _field(TextEditingController c, String label, IconData icon, {Color? color}) =>
      TextField(controller: c, keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: label, prefixIcon: Icon(icon, color: color, size: 18),
            border: const OutlineInputBorder(), isDense: true));
}

// ─── Onglet Documents ─────────────────────────────────────────
class _DocTab extends StatefulWidget {
  final AppUser user;
  final Bureau bureau;
  final ElectionService svc;
  const _DocTab({required this.user, required this.bureau, required this.svc});
  @override State<_DocTab> createState() => _DocTabState();
}

class _DocTabState extends State<_DocTab> {
  Document? _doc;
  bool _loading = true;
  final _omCtrl = TextEditingController();
  final _ordCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  @override
  void didUpdateWidget(_DocTab old) {
    super.didUpdateWidget(old);
    if (old.bureau.id != widget.bureau.id) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final docs = await widget.svc.getDocuments();
    Document? d;
    try { d = docs.firstWhere((doc) => doc.bureauId == widget.bureau.id); } catch (_) {}
    if (d != null) {
      _omCtrl.text = d.nbOm.toString();
      _ordCtrl.text = d.nbOrdonnances.toString();
    }
    setState(() { _doc = d; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return _loading ? const Center(child: CircularProgressIndicator())
        : ListView(padding: const EdgeInsets.all(14), children: [
            if (_doc != null) ...[
              Card(
                color: _doc!.valide ? Colors.green[50] : Colors.orange[50],
                child: ListTile(
                  leading: Icon(_doc!.valide ? Icons.verified : Icons.pending,
                      color: _doc!.valide ? Colors.green : Colors.orange),
                  title: Text(_doc!.valide ? 'Documents validés' : 'En attente'),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
              Text(_doc != null ? 'Modifier les documents' : 'Saisir les documents',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 14),
              TextField(controller: _omCtrl, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Nombre d\'OM',
                      border: OutlineInputBorder(), isDense: true,
                      prefixIcon: Icon(Icons.description))),
              const SizedBox(height: 10),
              TextField(controller: _ordCtrl, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Nombre d\'ordonnances',
                      border: OutlineInputBorder(), isDense: true,
                      prefixIcon: Icon(Icons.file_present))),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Enregistrer'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20), foregroundColor: Colors.white),
                  onPressed: () async {
                    final om = int.tryParse(_omCtrl.text);
                    final ord = int.tryParse(_ordCtrl.text);
                    if (om == null || ord == null) return;
                    final agentCode = 'AGT-${widget.bureau.id.replaceAll(RegExp(r'[^0-9]'), '')}';
                    await widget.svc.soumettreDocuments(
                        widget.bureau.id, agentCode, om, ord);
                    await _load();
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Documents enregistrés ✓'),
                            backgroundColor: Colors.green));
                  },
                ),
              ),
            ]))),
          ]);
  }
}

// ─── Onglet Cartes (saisie superviseur) ──────────────────────
class _CartesTab extends StatefulWidget {
  final AppUser user;
  final Bureau bureau;
  final ElectionService svc;
  const _CartesTab({required this.user, required this.bureau, required this.svc});
  @override
  State<_CartesTab> createState() => _CartesTabState();
}

class _CartesTabState extends State<_CartesTab> {
  RetraitCartes? _retrait;
  bool _loading = true;
  final _retraitsCtrl = TextEditingController();
  final _nonRetraitsCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  @override
  void didUpdateWidget(_CartesTab old) {
    super.didUpdateWidget(old);
    if (old.bureau.id != widget.bureau.id) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await widget.svc.getRetraitCartes(widget.bureau.id);
    if (r != null) {
      _retraitsCtrl.text = r.nbRetraits.toString();
      _nonRetraitsCtrl.text = r.nbNonRetraits.toString();
      _obsCtrl.text = r.observations ?? '';
    } else {
      _retraitsCtrl.clear();
      _nonRetraitsCtrl.clear();
      _obsCtrl.clear();
    }
    setState(() { _retrait = r; _loading = false; });
  }

  double get _taux {
    if (_retrait == null || widget.bureau.inscrits == 0) return 0;
    return _retrait!.nbRetraits / widget.bureau.inscrits * 100;
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(padding: const EdgeInsets.all(14), children: [
            // Info bureau
            Card(
              color: Colors.teal[50],
              child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
                const Icon(Icons.location_on, color: Colors.teal, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.bureau.id,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                  Text(widget.bureau.nom, style: const TextStyle(fontSize: 12)),
                  Text('${widget.bureau.inscrits} inscrits — ${widget.bureau.region}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ])),
              ])),
            ),
            const SizedBox(height: 12),

            // Statut actuel si données existent
            if (_retrait != null) ...[
              Card(
                color: _retrait!.valide ? Colors.green[50] : Colors.orange[50],
                child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
                  Row(children: [
                    Icon(_retrait!.valide ? Icons.verified : Icons.pending,
                        color: _retrait!.valide ? Colors.green : Colors.orange, size: 18),
                    const SizedBox(width: 8),
                    Text(_retrait!.valide ? 'Validé ✓' : 'En attente validation',
                        style: TextStyle(fontWeight: FontWeight.bold,
                            color: _retrait!.valide ? Colors.green[700] : Colors.orange[700])),
                    const Spacer(),
                    Text('${_taux.toStringAsFixed(1)}%',
                        style: TextStyle(fontWeight: FontWeight.bold,
                            color: _taux >= 70 ? Colors.green : Colors.orange, fontSize: 16)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: Column(children: [
                      Text(_retrait!.nbRetraits.toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold,
                              fontSize: 20, color: Colors.green)),
                      const Text('Retirées', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ])),
                    Expanded(child: Column(children: [
                      Text(_retrait!.nbNonRetraits.toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold,
                              fontSize: 20, color: Colors.red)),
                      const Text('Non retirées', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ])),
                    Expanded(child: Column(children: [
                      Text('${widget.bureau.inscrits}',
                          style: const TextStyle(fontWeight: FontWeight.bold,
                              fontSize: 20, color: Colors.indigo)),
                      const Text('Inscrits', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ])),
                  ]),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (_taux / 100).clamp(0.0, 1.0),
                      backgroundColor: Colors.red[100],
                      color: _taux >= 70 ? Colors.green : Colors.orange,
                      minHeight: 10,
                    ),
                  ),
                  if (_retrait!.observations != null && _retrait!.observations!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('📝 ${_retrait!.observations}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ])),
              ),
              const SizedBox(height: 12),
            ],

            // Formulaire de saisie / mise à jour
            Card(
              child: Padding(padding: const EdgeInsets.all(14), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _retrait != null ? 'Mettre à jour les retraits' : 'Saisir les retraits',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  if (_retrait == null)
                    Text('Inscrits: ${widget.bureau.inscrits}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 14),

                  TextField(
                    controller: _retraitsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Cartes retirées',
                      hintText: 'Sur \${widget.bureau.inscrits} inscrits',
                      prefixIcon: const Icon(Icons.credit_card, color: Colors.green),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (val) {
                      final r = int.tryParse(val) ?? 0;
                      final nonR = (widget.bureau.inscrits - r).clamp(0, widget.bureau.inscrits);
                      _nonRetraitsCtrl.text = nonR.toString();
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 10),

                  // Non retirées — calculé automatiquement
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(children: [
                      const Icon(Icons.credit_card_off, color: Colors.red, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Non retirées (calculé auto)',
                            style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text(
                          _nonRetraitsCtrl.text.isEmpty ? '—' : _nonRetraitsCtrl.text,
                          style: const TextStyle(fontWeight: FontWeight.bold,
                              fontSize: 22, color: Colors.red),
                        ),
                      ])),
                      if (_retraitsCtrl.text.isNotEmpty)
                        Builder(builder: (ctx) {
                          final r = int.tryParse(_retraitsCtrl.text) ?? 0;
                          final t = widget.bureau.inscrits > 0
                              ? r / widget.bureau.inscrits * 100 : 0.0;
                          return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text('\${t.toStringAsFixed(1)}%',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18,
                                    color: t >= 70 ? Colors.green : Colors.orange)),
                            const Text('taux retrait', style: TextStyle(fontSize: 9, color: Colors.grey)),
                          ]);
                        }),
                    ]),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: _obsCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Observations (facultatif)',
                      hintText: 'Problèmes rencontrés, liste indisponible...',
                      prefixIcon: Icon(Icons.notes),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),

                  // Aperçu taux en temps réel
                  if (_retraitsCtrl.text.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Builder(builder: (_) {
                      final r = int.tryParse(_retraitsCtrl.text) ?? 0;
                      final t = widget.bureau.inscrits > 0
                          ? r / widget.bureau.inscrits * 100 : 0.0;
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (t >= 70 ? Colors.green : Colors.orange).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: (t >= 70 ? Colors.green : Colors.orange).withOpacity(0.3)),
                        ),
                        child: Row(children: [
                          Icon(t >= 70 ? Icons.thumb_up : Icons.info_outline,
                              color: t >= 70 ? Colors.green : Colors.orange, size: 16),
                          const SizedBox(width: 8),
                          Text('Taux de retrait : ${t.toStringAsFixed(1)}%',
                              style: TextStyle(fontWeight: FontWeight.bold,
                                  color: t >= 70 ? Colors.green : Colors.orange)),
                        ]),
                      );
                    }),
                  ],

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: Text(_retrait != null ? 'Mettre à jour' : 'Enregistrer'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B5E20),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: _enregistrer,
                    ),
                  ),

                  // Bouton valider (superviseur national seulement)
                  if (_retrait != null && !_retrait!.valide) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.verified, color: Colors.green, size: 16),
                        label: const Text('Valider ces données',
                            style: TextStyle(color: Colors.green)),
                        style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.green)),
                        onPressed: () async {
                          await widget.svc.validerRetraitCartes(_retrait!.id);
                          await _load();
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Données validées ✓'),
                                  backgroundColor: Colors.green));
                        },
                      ),
                    ),
                  ],
                ],
              )),
            ),
          ]);
  }

  Future<void> _enregistrer() async {
    final retraits = int.tryParse(_retraitsCtrl.text);
    final nonRetraits = int.tryParse(_nonRetraitsCtrl.text);
    if (retraits == null || nonRetraits == null || retraits < 0 || nonRetraits < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saisissez des nombres valides'),
              backgroundColor: Colors.red));
      return;
    }
    // Code agent correspondant au bureau
    final agentCode = 'AGT-${widget.bureau.id.replaceAll(RegExp(r'[^0-9]'), '')}';
    final ok = await widget.svc.soumettreRetraitCartes(
        widget.bureau.id, agentCode, retraits, nonRetraits, _obsCtrl.text.trim());
    if (ok) {
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Retraits enregistrés ✓'),
              backgroundColor: Colors.green));
    }
  }
}
