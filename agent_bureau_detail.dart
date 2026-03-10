import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../utils/constants.dart';

class AgentBureauDetail extends StatefulWidget {
  final Bureau bureau;
  final String agentId;
  const AgentBureauDetail({super.key, required this.bureau, required this.agentId});
  @override
  State<AgentBureauDetail> createState() => _AgentBureauDetailState();
}

class _AgentBureauDetailState extends State<AgentBureauDetail>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _data = DataService();
  List<TurnoutSnapshot> _snapshots = [];
  PvResult? _pv;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _loading = true);
    final s = await _data.getSnapshotsBureau(widget.bureau.id);
    final p = await _data.getPvBureau(widget.bureau.id);
    setState(() { _snapshots = s; _pv = p; _loading = false; });
  }

  int get _heureActuelle {
    final h = DateTime.now().hour;
    return h.clamp(AppConstants.heureOuverture, AppConstants.heureFermeture);
  }

  bool get _releveDejaSaisi =>
      _snapshots.any((s) => s.heure == _heureActuelle);

  @override
  Widget build(BuildContext context) {
    final b = widget.bureau;
    return Scaffold(
      appBar: AppBar(
        title: Text(b.nom, overflow: TextOverflow.ellipsis),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.access_time), text: 'Relevé LIVE'),
            Tab(icon: Icon(Icons.assignment), text: 'PV Final'),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
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

  // ══════════════════════════════════════════
  //  TAB LIVE — Relevés horaires
  // ══════════════════════════════════════════
  Widget _tabLive() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        _bureauInfoCard(),
        const SizedBox(height: 16),
        // Formulaire saisie
        if (!_releveDejaSaisi)
          _formSaisieSnapshot()
        else
          _releveExistant(),
        const SizedBox(height: 16),
        // Historique
        if (_snapshots.isNotEmpty) _historiqueSnapshots(),
      ]),
    );
  }

  Widget _bureauInfoCard() {
    final b = widget.bureau;
    return Card(
      color: const Color(0xFFE8F5E9),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _kpiMini('Inscrits', b.inscrits.toString()),
            _kpiMini('OM', b.ordreMission.toString()),
            _kpiMini('Ord.', b.ordonnance.toString()),
            _kpiMini('Corrigés', b.inscritsCorriges.toString(), bold: true, color: const Color(0xFF1B5E20)),
          ]),
        ]),
      ),
    );
  }

  Widget _kpiMini(String label, String value, {bool bold = false, Color? color}) {
    return Column(children: [
      Text(value, style: TextStyle(
          fontSize: bold ? 20 : 18,
          fontWeight: bold ? FontWeight.bold : FontWeight.w600,
          color: color ?? Colors.black87)),
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
    ]);
  }

  Widget _formSaisieSnapshot() {
    final ctrl = TextEditingController();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.edit, color: Color(0xFF1B5E20)),
            const SizedBox(width: 8),
            Text('Relevé ${_heureActuelle}h00',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Nombre de votants',
              hintText: '0 - ${widget.bureau.inscritsCorriges}',
              prefixIcon: const Icon(Icons.people),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              suffixText: '/ ${widget.bureau.inscritsCorriges}',
            ),
          ),
          const SizedBox(height: 16),
          StatefulBuilder(builder: (ctx, setS) {
            int? v = int.tryParse(ctrl.text);
            double pct = v != null && widget.bureau.inscritsCorriges > 0
                ? v / widget.bureau.inscritsCorriges * 100 : 0;
            return Column(children: [
              if (v != null) ...[
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Participation estimée'),
                  Text('${pct.toStringAsFixed(1)}%',
                      style: const TextStyle(fontWeight: FontWeight.bold,
                          color: Color(0xFF1B5E20), fontSize: 18)),
                ]),
                const SizedBox(height: 8),
              ],
              ElevatedButton.icon(
                onPressed: () async {
                  final votants = int.tryParse(ctrl.text);
                  if (votants == null || votants < 0) {
                    _showErr('Saisissez un nombre valide');
                    return;
                  }
                  if (votants > widget.bureau.inscritsCorriges) {
                    _showErr('Votants > Inscrits corrigés !');
                    return;
                  }
                  final ok = await _data.submitSnapshot(
                    bureauId: widget.bureau.id,
                    heure: _heureActuelle,
                    votants: votants,
                    saisiPar: widget.agentId,
                  );
                  if (!mounted) return;
                  if (ok) {
                    _showOk('Relevé ${_heureActuelle}h transmis !');
                    _charger();
                  } else {
                    _showErr('Erreur de transmission');
                  }
                },
                icon: const Icon(Icons.send),
                label: Text('Envoyer relevé ${_heureActuelle}h',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ]);
          }),
        ]),
      ),
    );
  }

  Widget _releveExistant() {
    final snap = _snapshots.firstWhere((s) => s.heure == _heureActuelle);
    final color = snap.statut == 'valide' ? Colors.green
        : snap.statut == 'rejete' ? Colors.red : Colors.orange;
    return Card(
      color: color.withOpacity(0.08),
      shape: RoundedRectangleBorder(
          side: BorderSide(color: color), borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Icon(snap.statut == 'valide' ? Icons.check_circle
              : snap.statut == 'rejete' ? Icons.cancel : Icons.pending,
              color: color, size: 32),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Relevé ${_heureActuelle}h — ${snap.votants} votants',
                style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            Text('Statut : ${snap.statut.toUpperCase()}',
                style: TextStyle(color: color, fontSize: 12)),
            if (snap.noteRejet != null)
              Text('Rejet : ${snap.noteRejet}', style: const TextStyle(color: Colors.red, fontSize: 11)),
          ])),
        ]),
      ),
    );
  }

  Widget _historiqueSnapshots() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Historique des relevés',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          ..._snapshots.map((s) {
            final color = s.statut == 'valide' ? Colors.green
                : s.statut == 'rejete' ? Colors.red : Colors.orange;
            final pct = widget.bureau.inscritsCorriges > 0
                ? (s.votants / widget.bureau.inscritsCorriges * 100).toStringAsFixed(1) : '—';
            return ListTile(
              dense: true,
              leading: CircleAvatar(
                backgroundColor: color.withOpacity(0.15),
                child: Text('${s.heure}h', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              title: Text('${s.votants} votants ($pct%)'),
              subtitle: Text(s.statut.toUpperCase(), style: TextStyle(color: color, fontSize: 11)),
              trailing: Icon(
                s.statut == 'valide' ? Icons.check_circle
                    : s.statut == 'rejete' ? Icons.cancel : Icons.schedule,
                color: color, size: 18,
              ),
            );
          }),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════
  //  TAB PV — Procès-verbal final
  // ══════════════════════════════════════════
  Widget _tabPv() {
    if (_pv != null && _pv!.statut == 'valide') {
      return _pvValide();
    }
    return _formPv();
  }

  Widget _pvValide() {
    final p = _pv!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Card(
          color: const Color(0xFFE8F5E9),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              const Icon(Icons.verified, color: Color(0xFF1B5E20), size: 48),
              const SizedBox(height: 8),
              const Text('PV Validé', style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF1B5E20))),
              const Divider(height: 24),
              _pvLigne('Votants', p.votants.toString()),
              _pvLigne('Nuls', '${p.nuls} (${p.pctNuls.toStringAsFixed(1)}%)'),
              _pvLigne('Candidat A', '${p.voixA} — ${p.pctA.toStringAsFixed(1)}%'),
              _pvLigne('Candidat B', '${p.voixB} — ${p.pctB.toStringAsFixed(1)}%'),
              _pvLigne('Exprimés', p.exprimes.toString()),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _pvLigne(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ]),
    );
  }

  Widget _formPv() {
    final cVotants = TextEditingController(text: _pv?.votants.toString());
    final cNuls    = TextEditingController(text: _pv?.nuls.toString());
    final cVoixA   = TextEditingController(text: _pv?.voixA.toString());
    final cVoixB   = TextEditingController(text: _pv?.voixB.toString());
    File? photo;
    String? photoUrl = _pv?.photoUrl;

    return StatefulBuilder(builder: (ctx, setS) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          if (_pv?.statut == 'rejete')
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  const Icon(Icons.cancel, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Rejeté : ${_pv!.noteRejet ?? ""}',
                      style: const TextStyle(color: Colors.red))),
                ]),
              ),
            ),
          const SizedBox(height: 8),
          _bureauInfoCard(),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Saisie du PV final',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                _champPv('Votants', cVotants, Icons.people),
                _champPv('Bulletins nuls', cNuls, Icons.cancel_outlined),
                _champPv('Voix Candidat A', cVoixA, Icons.how_to_vote),
                _champPv('Voix Candidat B', cVoixB, Icons.how_to_vote),
                const SizedBox(height: 8),

                // Vérification live
                Builder(builder: (_) {
                  final v = int.tryParse(cVotants.text);
                  final n = int.tryParse(cNuls.text);
                  final a = int.tryParse(cVoixA.text);
                  final bb = int.tryParse(cVoixB.text);
                  if (v != null && n != null && a != null && bb != null) {
                    final ok = v == n + a + bb;
                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ok ? Colors.green.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        Icon(ok ? Icons.check_circle : Icons.warning,
                            color: ok ? Colors.green : Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Text(ok
                            ? 'Total cohérent : $v = $n + $a + $bb'
                            : 'ERREUR : $v ≠ $n + $a + $bb (total = ${n+a+bb})',
                            style: TextStyle(
                                color: ok ? Colors.green.shade700 : Colors.red,
                                fontSize: 12, fontWeight: FontWeight.bold)),
                      ]),
                    );
                  }
                  return const SizedBox();
                }),
                const SizedBox(height: 16),

                // Photo PV
                const Text('Photo du PV *',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final xf = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
                    if (xf != null) setS(() => photo = File(xf.path));
                  },
                  child: Container(
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      border: Border.all(
                          color: (photo == null && photoUrl == null)
                              ? Colors.red.shade200 : Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: photo != null
                        ? ClipRRect(borderRadius: BorderRadius.circular(10),
                            child: Image.file(photo!, fit: BoxFit.cover, width: double.infinity))
                        : photoUrl != null
                            ? const Center(child: Icon(Icons.check_circle, color: Colors.green, size: 40))
                            : const Center(child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.camera_alt, size: 36, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text('Prendre la photo du PV',
                                      style: TextStyle(color: Colors.grey)),
                                ],
                              )),
                  ),
                ),
                const SizedBox(height: 20),

                ElevatedButton.icon(
                  onPressed: () async {
                    final v = int.tryParse(cVotants.text);
                    final n = int.tryParse(cNuls.text);
                    final a = int.tryParse(cVoixA.text);
                    final bb = int.tryParse(cVoixB.text);

                    if (v == null || n == null || a == null || bb == null) {
                      _showErr('Remplissez tous les champs');
                      return;
                    }
                    if (v != n + a + bb) {
                      _showErr('Total incohérent : votants ≠ nuls + voix A + voix B');
                      return;
                    }
                    if (v > widget.bureau.inscritsCorriges) {
                      _showErr('Votants > Inscrits corrigés !');
                      return;
                    }
                    if (photo == null && photoUrl == null) {
                      _showErr('Photo du PV obligatoire');
                      return;
                    }

                    // Upload photo si nouvelle
                    if (photo != null) {
                      photoUrl = await _data.uploadPhotoPv(
                          widget.bureau.id, await photo!.readAsBytes());
                    }

                    final ok = await _data.submitPv(
                      bureauId: widget.bureau.id,
                      votants: v, nuls: n, voixA: a, voixB: bb,
                      saisiPar: widget.agentId, photoUrl: photoUrl,
                    );
                    if (!mounted) return;
                    if (ok) {
                      _showOk('PV transmis avec succès !');
                      _charger();
                    } else {
                      _showErr('Erreur de transmission');
                    }
                  },
                  icon: const Icon(Icons.send),
                  label: const Text('Soumettre le PV',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ]),
            ),
          ),
        ]),
      );
    });
  }

  Widget _champPv(String label, TextEditingController ctrl, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  void _showErr(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red));

  void _showOk(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green));
}
