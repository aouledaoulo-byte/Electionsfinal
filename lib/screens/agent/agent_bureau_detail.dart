import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/services.dart';

class AgentBureauDetail extends StatefulWidget {
  final AppUser user;
  final Bureau bureau;
  final int initialTab;
  const AgentBureauDetail({super.key, required this.user, required this.bureau, this.initialTab = 0});
  @override
  State<AgentBureauDetail> createState() => _AgentBureauDetailState();
}

class _AgentBureauDetailState extends State<AgentBureauDetail>
    with SingleTickerProviderStateMixin {
  final _svc = ElectionService();
  late TabController _tabs;

  List<TurnoutSnapshot> _snapshots = [];
  PvResult? _pv;
  bool _loading = true;

  // Relevé live
  final _votantsCtrl = TextEditingController();

  // PV
  final _totalCtrl = TextEditingController();
  final _nulsCtrl = TextEditingController();
  final _abstCtrl = TextEditingController();
  final _aCtrl = TextEditingController();
  final _bCtrl = TextEditingController();

  int get _heureActuelle => DateTime.now().hour.clamp(7, 17);
  final List<int> _heures = [7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17];

  bool get _releveDejaSaisi =>
      _snapshots.any((s) => s.heure == _heureActuelle);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _charger();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _votantsCtrl.dispose();
    _totalCtrl.dispose();
    _nulsCtrl.dispose();
    _abstCtrl.dispose();
    _aCtrl.dispose();
    _bCtrl.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    setState(() => _loading = true);
    final snaps = await _svc.getTurnoutBureau(widget.bureau.id);
    final pv = await _svc.getPvBureau(widget.bureau.id);
    // Pré-remplir le champ votants si relevé de l'heure courante existe
    final existingSnap = snaps.where((s) => s.heure == _heureActuelle).toList();
    if (existingSnap.isNotEmpty && _votantsCtrl.text.isEmpty) {
      _votantsCtrl.text = existingSnap.first.votants.toString();
    }
    // Pré-remplir PV si existe
    if (pv != null) {
      if (_totalCtrl.text.isEmpty) _totalCtrl.text = pv.totalVotants.toString();
      if (_aCtrl.text.isEmpty) _aCtrl.text = pv.voixCandidatA.toString();
      if (_bCtrl.text.isEmpty) _bCtrl.text = pv.voixCandidatB.toString();
      if (_nulsCtrl.text.isEmpty) _nulsCtrl.text = pv.bulletinsNuls.toString();
      if (_abstCtrl.text.isEmpty) _abstCtrl.text = pv.abstentions.toString();
    }
    setState(() {
      _snapshots = snaps;
      _pv = pv;
      _loading = false;
    });
  }

  Future<void> _envoyerReleve() async {
    final val = int.tryParse(_votantsCtrl.text);
    if (val == null || val < 0) {
      _snack('Saisissez un nombre valide', Colors.red);
      return;
    }
    setState(() => _loading = true);
    final ok = await _svc.soumettreTurnout(
        widget.bureau.id, widget.user.code, _heureActuelle, val);
    if (ok) {
      _votantsCtrl.clear();
      await _charger();
      _snack('Relevé ${_heureActuelle}h envoyé ✓', Colors.green);
    } else {
      setState(() => _loading = false);
      _snack('Erreur réseau', Colors.red);
    }
  }

  Future<void> _soumettreResultats() async {
    final total = int.tryParse(_totalCtrl.text);
    final nuls = int.tryParse(_nulsCtrl.text);
    final abst = int.tryParse(_abstCtrl.text);
    final a = int.tryParse(_aCtrl.text);
    final b = int.tryParse(_bCtrl.text);
    if ([total, nuls, abst, a, b].any((v) => v == null || v < 0)) {
      _snack('Remplissez tous les champs', Colors.red);
      return;
    }
    if ((a! + b!) > total!) {
      _snack('Voix A + B > total votants', Colors.red);
      return;
    }
    setState(() => _loading = true);
    final ok = await _svc.soumettreResultats(PvResult(
      id: '', bureauId: widget.bureau.id, agentCode: widget.user.code,
      totalVotants: total, bulletinsNuls: nuls!, abstentions: abst!,
      voixCandidatA: a, voixCandidatB: b, createdAt: DateTime.now(),
    ));
    if (ok) {
      await _charger();
      _snack('PV soumis avec succès ✓', Colors.green);
    } else {
      setState(() => _loading = false);
      _snack('Erreur réseau', Colors.red);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bureau.id,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _charger)
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.bar_chart, size: 18), text: 'Releve LIVE'),
            Tab(icon: Icon(Icons.how_to_vote, size: 18), text: 'PV Final'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [_tabLive(), _tabPv()],
            ),
    );
  }

  // ─── Onglet LIVE ──────────────────────────────────────
  Widget _tabLive() {
    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // KPI en haut
          Row(children: [
            _kpi('Inscrits', widget.bureau.inscrits.toString(), Icons.people, Colors.indigo),
            const SizedBox(width: 8),
            _kpi('Relevés', _snapshots.length.toString(), Icons.bar_chart, Colors.blue),
            const SizedBox(width: 8),
            _kpi('Taux', _taux(), Icons.percent, Colors.green),
          ]),
          const SizedBox(height: 14),

          // Saisie heure courante
          Card(
            color: _releveDejaSaisi ? Colors.green[50] : Colors.blue[50],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(
                    _releveDejaSaisi ? Icons.check_circle : Icons.access_time,
                    color: _releveDejaSaisi ? Colors.green : Colors.blue,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text('Envoyer relevé ${_heureActuelle}h00',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _releveDejaSaisi ? Colors.green[700] : Colors.blue[700])),
                  if (_releveDejaSaisi) ...[
                    const Spacer(),
                    const Text('Déjà saisi',
                        style: TextStyle(fontSize: 12, color: Colors.green)),
                  ],
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _votantsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Nombre de votants',
                        hintText: 'Sur ${widget.bureau.inscrits}',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: const Icon(Icons.how_to_vote, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    icon: Icon(_releveDejaSaisi ? Icons.edit : Icons.send, size: 16),
                    label: Text(_releveDejaSaisi ? 'Modifier' : 'Envoyer'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E20),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12)),
                    onPressed: _envoyerReleve,
                  ),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 14),

          // Historique barres
          const Text('Historique',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          ..._heures.map((h) {
            final snap =
                _snapshots.where((s) => s.heure == h).toList();
            final v = snap.isEmpty ? null : snap.first.votants;
            final taux = v != null && widget.bureau.inscrits > 0
                ? v / widget.bureau.inscrits
                : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(children: [
                SizedBox(
                  width: 38,
                  child: Text('${h}h',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: v != null ? const Color(0xFF1B5E20) : Colors.grey[300])),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: Stack(children: [
                      Container(height: 28, color: Colors.grey[100]),
                      if (v != null)
                        FractionallySizedBox(
                          widthFactor: taux.clamp(0.0, 1.0),
                          child: Container(
                            height: 28,
                            decoration: BoxDecoration(
                              color: Color.lerp(
                                  Colors.green[300], Colors.green[700], taux),
                            ),
                          ),
                        ),
                      if (v != null)
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text('$v votants',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                            ),
                          ),
                        ),
                    ]),
                  ),
                ),
                SizedBox(
                  width: 42,
                  child: Text(
                      v != null ? '${(taux * 100).toStringAsFixed(0)}%' : '',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ]),
            );
          }),
        ],
      ),
    );
  }

  // ─── Onglet PV ────────────────────────────────────────
  Widget _tabPv() {
    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // KPI résumé
          if (_pv != null) ...[
            _pvStatutBanner(),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  _pvRow('Total votants', _pv!.totalVotants),
                  _pvRow('Candidat A', _pv!.voixCandidatA, color: Colors.blue),
                  _pvRow('Candidat B', _pv!.voixCandidatB, color: Colors.red),
                  _pvRow('Bulletins nuls', _pv!.bulletinsNuls),
                  _pvRow('Abstentions', _pv!.abstentions),
                ]),
              ),
            ),
            if (_pv!.motifRejet != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!)),
                child: Text('Motif de rejet : ${_pv!.motifRejet}',
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
              ),
            ],
          ],

          // Formulaire si pas de PV ou PV rejeté
          if (_pv == null || _pv!.rejete) ...[
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _pv?.rejete == true
                          ? 'Corriger et resoumettre le PV'
                          : 'Soumettre le PV Final',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 14),
                    _champPv(_totalCtrl, 'Total votants', Icons.people),
                    const SizedBox(height: 10),
                    _champPv(_aCtrl, 'Voix Candidat A', Icons.person,
                        color: Colors.blue),
                    const SizedBox(height: 10),
                    _champPv(_bCtrl, 'Voix Candidat B', Icons.person,
                        color: Colors.red),
                    const SizedBox(height: 10),
                    _champPv(_nulsCtrl, 'Bulletins nuls', Icons.block),
                    const SizedBox(height: 10),
                    _champPv(_abstCtrl, 'Abstentions', Icons.remove_circle_outline),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.upload),
                        label: const Text('Soumettre le PV'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B5E20),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: _soumettreResultats,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pvStatutBanner() {
    Color color;
    IconData icon;
    String label;
    if (_pv!.valide) {
      color = Colors.green;
      icon = Icons.verified;
      label = 'PV Validé ✓';
    } else if (_pv!.rejete) {
      color = Colors.red;
      icon = Icons.cancel;
      label = 'Rejeté par superviseur';
    } else {
      color = Colors.orange;
      icon = Icons.pending;
      label = 'En attente de validation';
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(children: [
        Icon(icon, color: color),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 15)),
      ]),
    );
  }

  Widget _champPv(TextEditingController c, String label, IconData icon,
      {Color? color}) =>
      TextField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: color, size: 18),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      );

  Widget _kpi(String label, String value, IconData icon, Color color) =>
      Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(value,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: color)),
              Text(label,
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ]),
          ),
        ),
      );

  Widget _pvRow(String label, int value, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(
              child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(value.toString(),
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: color ?? Colors.black87)),
        ]),
      );

  String _taux() {
    if (_snapshots.isEmpty || widget.bureau.inscrits == 0) return '0%';
    final max = _snapshots
        .map((s) => s.votants)
        .reduce((a, b) => a > b ? a : b);
    return '${(max / widget.bureau.inscrits * 100).toStringAsFixed(1)}%';
  }
}
