import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/services.dart';

class PvScreen extends StatefulWidget {
  final AppUser user;
  final Bureau bureau;
  const PvScreen({super.key, required this.user, required this.bureau});
  @override State<PvScreen> createState() => _PvScreenState();
}

class _PvScreenState extends State<PvScreen> {
  final _svc = ElectionService();
  PvResult? _pvExist;
  bool _loading = true;
  bool _modeCorrection = false;
  bool _saving = false;

  static final DateTime _jourVote = DateTime(2026, 4, 10);

  // Phase 3 accessible dès 18h00 le 10/04
  bool get _phaseDepouillement {
    final now = DateTime.now();
    final isJourVote = now.year == _jourVote.year &&
        now.month == _jourVote.month && now.day == _jourVote.day;
    return isJourVote && now.hour >= 18 || now.isAfter(_jourVote);
  }

  int get _minutesRestantes {
    final now = DateTime.now();
    final fermeture = DateTime(2026, 4, 10, 18, 0);
    final diff = fermeture.difference(now).inMinutes;
    return diff < 0 ? 0 : diff;
  }

  final _totalCtrl = TextEditingController();
  final _aCtrl     = TextEditingController();
  final _bCtrl     = TextEditingController();
  final _nulsCtrl  = TextEditingController();
  final _abstCtrl  = TextEditingController();

  // Cohérence: A + B + nuls doit = total
  int get _somme =>
      (int.tryParse(_aCtrl.text) ?? 0) +
      (int.tryParse(_bCtrl.text) ?? 0) +
      (int.tryParse(_nulsCtrl.text) ?? 0);

  int get _total => int.tryParse(_totalCtrl.text) ?? 0;
  bool get _coherent => _total == 0 || _somme == _total;
  int get _ecart => _somme - _total;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() {
    _totalCtrl.dispose(); _aCtrl.dispose(); _bCtrl.dispose();
    _nulsCtrl.dispose(); _abstCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final pv = await _svc.getPvBureau(widget.bureau.id);
    if (pv != null) {
      _totalCtrl.text = pv.totalVotants.toString();
      _aCtrl.text     = pv.voixCandidatA.toString();
      _bCtrl.text     = pv.voixCandidatB.toString();
      _nulsCtrl.text  = pv.bulletinsNuls.toString();
      _abstCtrl.text  = pv.abstentions.toString();
    }
    setState(() { _pvExist = pv; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('PV Dépouillement',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          Text(widget.bureau.id,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ]),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(12), children: [
              _phaseCard(),
              const SizedBox(height: 10),
              _bureauCard(),
              const SizedBox(height: 10),
              if (_pvExist != null) ...[
                _statutBanner(),
                const SizedBox(height: 10),
              ],
              if (_pvExist == null || _pvExist!.rejeteReg ||
                  _pvExist!.rejeteNat || _modeCorrection)
                _formulaire(),
            ]),
    );
  }

  Widget _phaseCard() {
    if (!_phaseDepouillement) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.withOpacity(0.4))),
        child: Row(children: [
          const Icon(Icons.lock_clock, color: Colors.orange, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Phase 3 — Dépouillement',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
              Text('Disponible à partir de 18h00 le 10/04/2026'
                  ' ($_minutesRestantes min restantes)',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ])),
        ]));
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.withOpacity(0.4))),
      child: const Row(children: [
        Icon(Icons.how_to_vote, color: Colors.blue, size: 20),
        SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('🔵 Phase 3 — Dépouillement & Proclamation',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue,
                  fontSize: 14)),
          Text('Bureau fermé — Saisir les résultats du dépouillement',
              style: TextStyle(fontSize: 11, color: Colors.grey)),
        ])),
      ]));
  }

  Widget _bureauCard() {
    return Card(
      color: const Color(0xFF1B5E20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(14), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.bureau.nom,
              style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.location_on, color: Colors.white60, size: 14),
            const SizedBox(width: 4),
            Text(widget.bureau.region,
                style: const TextStyle(color: Colors.white60, fontSize: 12)),
            const SizedBox(width: 16),
            const Icon(Icons.people, color: Colors.white60, size: 14),
            const SizedBox(width: 4),
            Text('${widget.bureau.inscrits} inscrits',
                style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ]),
        ]));
  }

  Widget _statutBanner() {
    final pv = _pvExist!;
    Color color; IconData icon; String label; String detail;

    if (pv.publie) {
      color = Colors.green; icon = Icons.public;
      label = 'Publié ✓'; detail = 'Validé par Superviseur National';
    } else if (pv.valideReg) {
      color = Colors.blue; icon = Icons.verified;
      label = 'Validé région'; detail = 'En attente du Superviseur National';
    } else if (pv.rejeteNat) {
      color = Colors.red; icon = Icons.cancel;
      label = 'Rejeté (National)'; detail = pv.motifRejet ?? '';
    } else if (pv.rejeteReg) {
      color = Colors.red; icon = Icons.cancel;
      label = 'Rejeté (Région)'; detail = pv.motifRejet ?? '';
    } else {
      color = Colors.orange; icon = Icons.hourglass_empty;
      label = 'Soumis'; detail = 'En attente validation régionale';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: color,
              fontWeight: FontWeight.bold, fontSize: 15)),
        ]),
        if (detail.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(detail, style: TextStyle(color: color.withOpacity(0.8), fontSize: 12)),
        ],
        const SizedBox(height: 12),
        _workflowBar(),
        // Résumé PV si publié/validé
        if (pv.valideReg || pv.publie) ...[
          const Divider(height: 16),
          _pvResume(pv),
        ],
        // Bouton modifier
        if (!pv.publie && !pv.rejeteReg && !pv.rejeteNat) ...[
          const SizedBox(height: 10),
          SizedBox(width: double.infinity,
            child: OutlinedButton.icon(
              icon: Icon(_modeCorrection ? Icons.close : Icons.edit, size: 14),
              label: Text(_modeCorrection ? 'Annuler' : 'Modifier le PV'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange)),
              onPressed: () => setState(() => _modeCorrection = !_modeCorrection),
            )),
        ],
      ]));
  }

  Widget _pvResume(PvResult pv) {
    final tot = pv.totalVotants > 0 ? pv.totalVotants : 1;
    final pctA = pv.voixCandidatA / tot * 100;
    final pctB = pv.voixCandidatB / tot * 100;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Résultats', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      _candidatLine('Candidat A', pv.voixCandidatA, pctA, Colors.blue),
      const SizedBox(height: 6),
      _candidatLine('Candidat B', pv.voixCandidatB, pctB, Colors.red),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(child: Text('Nuls: ${pv.bulletinsNuls}',
            style: const TextStyle(fontSize: 11, color: Colors.grey))),
        Text('Abst: ${pv.abstentions}',
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const Spacer(),
        Text('Total: ${pv.totalVotants}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ]),
    ]);
  }

  Widget _candidatLine(String name, int voix, double pct, Color color) {
    return Column(children: [
      Row(children: [
        Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        const Spacer(),
        Text('$voix voix — ${pct.toStringAsFixed(1)}%',
            style: TextStyle(fontWeight: FontWeight.bold, color: color)),
      ]),
      const SizedBox(height: 3),
      ClipRRect(borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: (pct / 100).clamp(0.0, 1.0),
          backgroundColor: Colors.grey[200], color: color, minHeight: 8)),
    ]);
  }

  Widget _workflowBar() {
    final pv = _pvExist!;
    final steps = [
      {'label': 'Soumis', 'done': true},
      {'label': 'Validé région', 'done': pv.valideReg || pv.valideNat},
      {'label': 'Publié', 'done': pv.publie},
    ];
    return Row(children: List.generate(steps.length * 2 - 1, (idx) {
      if (idx.isOdd) {
        final done = steps[(idx - 1) ~/ 2]['done'] as bool;
        return Expanded(child: Container(height: 2,
            color: done ? Colors.green : Colors.grey[300]));
      }
      final step = steps[idx ~/ 2];
      final done = step['done'] as bool;
      return Column(children: [
        CircleAvatar(radius: 10, backgroundColor: done ? Colors.green : Colors.grey[300],
            child: Icon(done ? Icons.check : Icons.circle, size: 10,
                color: done ? Colors.white : Colors.grey)),
        const SizedBox(height: 2),
        Text(step['label'] as String,
            style: TextStyle(fontSize: 9, color: done ? Colors.green : Colors.grey)),
      ]);
    }));
  }

  Widget _formulaire() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(14), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.ballot, color: Color(0xFF1B5E20), size: 18),
            const SizedBox(width: 8),
            Text(_pvExist != null ? 'Modifier les résultats' : 'Saisir les résultats',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
          const SizedBox(height: 6),
          Text('Les données doivent être cohérentes: A + B + Nuls = Total votants',
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          const SizedBox(height: 16),

          // Total votants
          _fieldNum(_totalCtrl, 'Total votants',
              'Nombre total de personnes ayant voté',
              Icons.people, Colors.indigo, onChanged: (v) {
            // Auto-calculer abstentions
            final tot = int.tryParse(v) ?? 0;
            final abst = (widget.bureau.inscrits - tot).clamp(0, widget.bureau.inscrits);
            _abstCtrl.text = abst.toString();
            setState(() {});
          }),
          const SizedBox(height: 10),

          // Candidat A
          _fieldNum(_aCtrl, 'Voix Candidat A', '', Icons.person, Colors.blue,
              onChanged: (_) => setState(() {})),
          const SizedBox(height: 10),

          // Candidat B
          _fieldNum(_bCtrl, 'Voix Candidat B', '', Icons.person, Colors.red,
              onChanged: (_) => setState(() {})),
          const SizedBox(height: 10),

          // Nuls
          _fieldNum(_nulsCtrl, 'Bulletins nuls', '', Icons.block, Colors.grey,
              onChanged: (_) => setState(() {})),
          const SizedBox(height: 10),

          // Abstentions (calculé auto)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!)),
            child: Row(children: [
              Icon(Icons.remove_circle_outline, color: Colors.grey[600], size: 18),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Abstentions (calculé auto)',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(_abstCtrl.text.isEmpty ? '—' : _abstCtrl.text,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ])),
              Text('/ ${widget.bureau.inscrits} inscrits',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ])),
          const SizedBox(height: 14),

          // Indicateur cohérence
          if (_total > 0) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _coherent ? Colors.green.withOpacity(0.08) : Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: (_coherent ? Colors.green : Colors.red).withOpacity(0.4))),
              child: Row(children: [
                Icon(_coherent ? Icons.check_circle : Icons.error,
                    color: _coherent ? Colors.green : Colors.red, size: 18),
                const SizedBox(width: 10),
                Expanded(child: _coherent
                    ? Text('✓ Cohérence vérifiée — A+B+Nuls = $_total',
                        style: const TextStyle(color: Colors.green,
                            fontWeight: FontWeight.bold, fontSize: 12))
                    : Text('Écart: $_somme ≠ $_total (différence: ${_ecart > 0 ? "+$_ecart" : "$_ecart"})',
                        style: const TextStyle(color: Colors.red,
                            fontWeight: FontWeight.bold, fontSize: 12))),
              ])),
            const SizedBox(height: 10),
          ],

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _saving
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.upload),
              label: Text(_saving ? 'Envoi en cours...'
                  : _pvExist != null ? 'Mettre à jour le PV' : 'Soumettre le PV'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _coherent || _total == 0
                      ? const Color(0xFF1B5E20) : Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: _saving ? null : _soumettre,
            )),

          if (!_coherent && _total > 0) ...[
            const SizedBox(height: 6),
            const Text(
              '⚠ Les données ne sont pas cohérentes. Vous pouvez quand même soumettre.',
              style: TextStyle(fontSize: 10, color: Colors.orange),
              textAlign: TextAlign.center),
          ],
        ])));
  }

  Widget _fieldNum(TextEditingController c, String label, String hint,
      IconData icon, Color color, {Function(String)? onChanged}) =>
      TextField(
        controller: c,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint.isEmpty ? null : hint,
          prefixIcon: Icon(icon, color: color, size: 20),
          border: const OutlineInputBorder(),
          isDense: false));

  Future<void> _soumettre() async {
    final total = int.tryParse(_totalCtrl.text);
    final a     = int.tryParse(_aCtrl.text);
    final b     = int.tryParse(_bCtrl.text);
    final nuls  = int.tryParse(_nulsCtrl.text);
    final abst  = int.tryParse(_abstCtrl.text);

    if ([total, a, b, nuls, abst].any((v) => v == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Remplissez tous les champs'), backgroundColor: Colors.red));
      return;
    }
    if (!_coherent && total! > 0) {
      final ok = await showDialog<bool>(context: context,
        builder: (_) => AlertDialog(
          title: const Text('⚠ Incohérence détectée'),
          content: Text('A+B+Nuls (${ a!+b!+nuls!}) ≠ Total ($total).\n'
              'Écart: ${a+b+nuls - total}. Confirmer quand même ?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false),
                child: const Text('Corriger')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true),
                child: const Text('Soumettre quand même')),
          ]));
      if (ok != true) return;
    }
    setState(() => _saving = true);
    await _svc.soumettreResultats(PvResult(
      id: _pvExist?.id ?? '',
      bureauId: widget.bureau.id,
      agentCode: widget.user.code,
      totalVotants: total!,
      bulletinsNuls: nuls!,
      abstentions: abst!,
      voixCandidatA: a!,
      voixCandidatB: b!,
      createdAt: DateTime.now(),
    ));
    setState(() { _saving = false; _modeCorrection = false; });
    await _load();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('PV soumis ✓'), backgroundColor: Colors.green));
  }
}
