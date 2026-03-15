import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/services.dart';

class ReleveScreen extends StatefulWidget {
  final AppUser user;
  final Bureau bureau;
  const ReleveScreen({super.key, required this.user, required this.bureau});
  @override State<ReleveScreen> createState() => _ReleveScreenState();
}

class _ReleveScreenState extends State<ReleveScreen> {
  final _svc = ElectionService();
  List<TurnoutSnapshot> _snapshots = [];
  bool _loading = true;
  bool _saving = false;

  static final DateTime _jourVote = DateTime(2026, 4, 10);
  static const int _heureOuv = 7;
  static const int _heureFerm = 17; // relevés de 7h à 17h

  int get _heureActuelle {
    final now = DateTime.now();
    if (!_estJourVote) return _heureOuv;
    return now.hour.clamp(_heureOuv, _heureFerm);
  }

  bool get _estJourVote {
    final now = DateTime.now();
    return now.year == _jourVote.year &&
        now.month == _jourVote.month &&
        now.day == _jourVote.day;
  }

  bool get _bureauOuvert {
    if (!_estJourVote) return false;
    final h = DateTime.now().hour;
    return h >= _heureOuv && h <= 18;
  }

  bool get _phaseDepouillement {
    if (!_estJourVote) return false;
    return DateTime.now().hour >= 18;
  }

  int _heureSelect = 7;
  final _ctrl = TextEditingController();

  TurnoutSnapshot? get _releveHeure {
    try { return _snapshots.firstWhere((s) => s.heure == _heureSelect); }
    catch (_) { return null; }
  }

  TurnoutSnapshot? get _dernierReleve => _snapshots.isEmpty ? null
      : _snapshots.reduce((a, b) => a.heure > b.heure ? a : b);

  double get _tauxSaisi {
    final v = int.tryParse(_ctrl.text) ?? 0;
    return widget.bureau.inscrits > 0 ? v / widget.bureau.inscrits * 100 : 0;
  }

  @override
  void initState() {
    super.initState();
    _heureSelect = _heureActuelle;
    _load();
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final s = await _svc.getTurnoutBureau(widget.bureau.id);
    // Pré-remplir avec relevé existant à l'heure sélectionnée
    final existing = s.where((e) => e.heure == _heureSelect).toList();
    if (existing.isNotEmpty) {
      _ctrl.text = existing.first.votants.toString();
    } else if (s.isNotEmpty) {
      // Pré-remplir avec dernier relevé
      final last = s.reduce((a, b) => a.heure > b.heure ? a : b);
      _ctrl.text = last.votants.toString();
    }
    setState(() { _snapshots = s; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Relevé participation',
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
              if (_phaseDepouillement)
                _depouillementCard()
              else
                _saisieCard(),
              const SizedBox(height: 10),
              if (_snapshots.isNotEmpty) _historiqueHoraire(),
            ]),
    );
  }

  Widget _phaseCard() {
    if (_phaseDepouillement) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.purple.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.purple.withOpacity(0.4))),
        child: const Row(children: [
          Icon(Icons.how_to_vote, color: Colors.purple, size: 18),
          SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Phase dépouillement', style: TextStyle(
                fontWeight: FontWeight.bold, color: Colors.purple)),
            Text('Le bureau est fermé — saisie du PV disponible',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
          ])),
        ]));
    }
    if (!_bureauOuvert) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.withOpacity(0.3))),
        child: Row(children: [
          Icon(Icons.access_time, color: Colors.grey[600], size: 18),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Jour du vote: 10/04/2026',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700])),
            Text('Ouverture 07h00 → Fermeture 18h00',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ])),
        ]));
    }
    // Bureau ouvert
    final now = DateTime.now();
    final minutesRestantes = (18 * 60) - (now.hour * 60 + now.minute);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.withOpacity(0.4))),
      child: Row(children: [
        const Icon(Icons.how_to_vote, color: Colors.green, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('🟢 Bureau ouvert — Jour du vote',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
          Text('Fermeture dans ${minutesRestantes ~/ 60}h${(minutesRestantes % 60).toString().padLeft(2,'0')}',
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
          const Text('heure actuelle', style: TextStyle(fontSize: 9, color: Colors.grey)),
        ]),
      ]));
  }

  Widget _bureauCard() {
    final dernierTaux = _dernierReleve != null && widget.bureau.inscrits > 0
        ? _dernierReleve!.votants / widget.bureau.inscrits * 100 : 0.0;
    return Card(
      color: const Color(0xFF1B5E20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.bureau.nom,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            Text('${widget.bureau.inscrits} inscrits · ${widget.bureau.region}',
                style: const TextStyle(color: Colors.white60, fontSize: 11)),
          ])),
          if (_dernierReleve != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: dernierTaux >= 60
                    ? Colors.greenAccent.withOpacity(0.3)
                    : dernierTaux >= 40 ? Colors.orange.withOpacity(0.3)
                    : Colors.red.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8)),
              child: Column(children: [
                Text('${dernierTaux.toStringAsFixed(1)}%',
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 20)),
                Text('à ${_dernierReleve!.heure}h',
                    style: const TextStyle(color: Colors.white70, fontSize: 9)),
              ]),
            ),
        ]),
        if (_dernierReleve != null) ...[
          const SizedBox(height: 10),
          ClipRRect(borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: (dernierTaux / 100).clamp(0.0, 1.0),
              backgroundColor: Colors.white.withOpacity(0.2),
              color: dernierTaux >= 60 ? Colors.greenAccent : Colors.orange,
              minHeight: 8)),
          const SizedBox(height: 4),
          Row(children: [
            Text('${_dernierReleve!.votants} votants',
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
            const Spacer(),
            Text('${widget.bureau.inscrits - _dernierReleve!.votants} non votants',
                style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
          ]),
          const SizedBox(height: 4),
          Text('${_snapshots.length}/11 relevés saisis',
              style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ],
      ])));
  }

  Widget _saisieCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(14), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.edit, color: Color(0xFF1B5E20), size: 18),
            const SizedBox(width: 8),
            const Text('Saisir un relevé',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Spacer(),
            if (_releveHeure != null)
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange.withOpacity(0.4))),
                child: const Text('Modification',
                    style: TextStyle(color: Colors.orange, fontSize: 10,
                        fontWeight: FontWeight.bold))),
          ]),
          const SizedBox(height: 14),

          // Sélecteur heure
          DropdownButtonFormField<int>(
            value: _heureSelect,
            decoration: const InputDecoration(
              labelText: 'Heure du relevé',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.access_time, size: 18)),
            items: List.generate(11, (i) => i + 7).map((h) {
              final exists = _snapshots.any((s) => s.heure == h);
              final isCurrent = h == _heureActuelle;
              return DropdownMenuItem(value: h,
                child: Row(children: [
                  Text('${h.toString().padLeft(2,'0')}h00',
                      style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: isCurrent ? const Color(0xFF1B5E20) : null)),
                  if (isCurrent) ...[
                    const SizedBox(width: 6),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(color: const Color(0xFF1B5E20),
                          borderRadius: BorderRadius.circular(4)),
                      child: const Text('actuel', style: TextStyle(color: Colors.white, fontSize: 8))),
                  ],
                  if (exists) ...[const SizedBox(width: 6),
                    const Icon(Icons.check_circle, color: Colors.green, size: 12)],
                ]));
            }).toList(),
            onChanged: (v) {
              setState(() => _heureSelect = v!);
              final existing = _snapshots.where((s) => s.heure == v).toList();
              if (existing.isNotEmpty) {
                _ctrl.text = existing.first.votants.toString();
              } else {
                // Pré-remplir avec dernier relevé < heure sélectionnée
                final prev = _snapshots.where((s) => s.heure < v!).toList();
                if (prev.isNotEmpty) {
                  _ctrl.text = prev.reduce((a, b) => a.heure > b.heure ? a : b).votants.toString();
                }
              }
            },
          ),
          const SizedBox(height: 12),

          // Champ votants
          TextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              labelText: 'Nombre de votants à ${_heureSelect.toString().padLeft(2,'0')}h00',
              hintText: 'Cumulatif depuis l\'ouverture',
              helperText: 'Sur ${widget.bureau.inscrits} inscrits',
              prefixIcon: const Icon(Icons.people, color: Color(0xFF1B5E20)),
              border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 10),

          // Indicateur taux en temps réel
          if (_ctrl.text.isNotEmpty && _ctrl.text != '0') ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _tauxSaisi >= 60
                    ? Colors.green.withOpacity(0.06)
                    : _tauxSaisi >= 40 ? Colors.orange.withOpacity(0.06)
                    : Colors.red.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: (_tauxSaisi >= 60 ? Colors.green
                    : _tauxSaisi >= 40 ? Colors.orange : Colors.red).withOpacity(0.3))),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Taux de participation',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    Text('${_tauxSaisi.toStringAsFixed(1)}%',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 26,
                            color: _tauxSaisi >= 60 ? Colors.green
                                : _tauxSaisi >= 40 ? Colors.orange : Colors.red)),
                  ]),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${int.tryParse(_ctrl.text) ?? 0} votants',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('${widget.bureau.inscrits - (int.tryParse(_ctrl.text) ?? 0)} restants',
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 4),
                    _niveauParticipation(),
                  ]),
                ]),
                const SizedBox(height: 8),
                ClipRRect(borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: (_tauxSaisi / 100).clamp(0.0, 1.0),
                    backgroundColor: Colors.grey[200],
                    color: _tauxSaisi >= 60 ? Colors.green
                        : _tauxSaisi >= 40 ? Colors.orange : Colors.red,
                    minHeight: 12)),
              ]),
            ),
            const SizedBox(height: 12),
          ],

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _saving
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Icon(_releveHeure != null ? Icons.update : Icons.send),
              label: Text(_saving ? 'Envoi...'
                  : _releveHeure != null
                      ? 'Mettre à jour le relevé ${_heureSelect}h'
                      : 'Envoyer le relevé ${_heureSelect}h'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: _saving ? null : _envoyer,
            ),
          ),
        ],
      )));
  }

  Widget _niveauParticipation() {
    String label; Color color;
    if (_tauxSaisi >= 70) { label = 'Fort'; color = Colors.green; }
    else if (_tauxSaisi >= 50) { label = 'Moyen'; color = Colors.orange; }
    else if (_tauxSaisi >= 30) { label = 'Faible'; color = Colors.red; }
    else { label = 'Très faible'; color = Colors.red[800]!; }
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.4))),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)));
  }

  Widget _depouillementCard() {
    return Card(
      color: Colors.purple[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
        const Row(children: [
          Icon(Icons.info_outline, color: Colors.purple, size: 18),
          SizedBox(width: 8),
          Expanded(child: Text('Bureau fermé — Phase dépouillement',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple))),
        ]),
        const SizedBox(height: 8),
        if (_dernierReleve != null)
          _statRow('Dernier relevé (${_dernierReleve!.heure}h)',
              '${_dernierReleve!.votants} votants'),
        _statRow('Bureaux inscrits', '${widget.bureau.inscrits}'),
        const SizedBox(height: 8),
        const Text('Rendez-vous sur "PV Final" pour saisir les résultats.',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
      ])));
  }


  Widget _statRow(String l, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Expanded(child: Text(l, style: const TextStyle(fontSize: 12))),
      Text(v, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
    ]));

  Widget _historiqueHoraire() {
    final heures = List.generate(11, (i) => i + 7);
    final max = _snapshots.isEmpty ? 1
        : _snapshots.map((s) => s.votants).reduce((a, b) => a > b ? a : b);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(14), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.timeline, color: Color(0xFF1B5E20), size: 18),
            const SizedBox(width: 8),
            const Text('Progression horaire',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(),
            Text('${_snapshots.length}/11 relevés',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
          const SizedBox(height: 12),
          ...heures.map((h) {
            final snap = _snapshots.where((s) => s.heure == h).toList();
            final has = snap.isNotEmpty;
            final votants = has ? snap.first.votants : 0;
            final taux = widget.bureau.inscrits > 0 && has
                ? votants / widget.bureau.inscrits * 100 : 0.0;
            final ratio = max > 0 && has ? votants / max : 0.0;
            final isSelected = h == _heureSelect;
            final isPast = h < _heureActuelle;
            final isCurrent = h == _heureActuelle;

            return GestureDetector(
              onTap: () {
                setState(() => _heureSelect = h);
                if (has) _ctrl.text = votants.toString();
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF1B5E20).withOpacity(0.06) : null,
                  borderRadius: BorderRadius.circular(6),
                  border: isSelected
                      ? Border.all(color: const Color(0xFF1B5E20).withOpacity(0.3)) : null),
                child: Row(children: [
                  SizedBox(width: 36,
                    child: Row(children: [
                      Text('${h.toString().padLeft(2,'0')}h',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11,
                              color: isSelected ? const Color(0xFF1B5E20)
                                  : has ? Colors.black87 : Colors.grey[400])),
                      if (isCurrent) const Text(' ◀',
                          style: TextStyle(color: Colors.orange, fontSize: 8)),
                    ])),
                  Expanded(child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(children: [
                      Container(height: 22,
                          color: !has && isPast ? Colors.red[50] : Colors.grey[100]),
                      if (has) FractionallySizedBox(
                        widthFactor: ratio.clamp(0.0, 1.0),
                        child: Container(height: 22,
                            color: isSelected ? const Color(0xFF1B5E20)
                                : taux >= 60 ? Colors.green[400] : Colors.orange[400])),
                      if (has) Positioned.fill(child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Align(alignment: Alignment.centerLeft,
                          child: Text('$votants votants',
                              style: const TextStyle(color: Colors.white,
                                  fontSize: 10, fontWeight: FontWeight.bold))))),
                      if (!has && isPast) Positioned.fill(child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Align(alignment: Alignment.centerLeft,
                          child: Text('⚠ Manquant',
                              style: TextStyle(color: Colors.red[400],
                                  fontSize: 10, fontWeight: FontWeight.bold))))),
                    ]))),
                  SizedBox(width: 40,
                    child: Text(has ? '${taux.toStringAsFixed(0)}%' : '',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                            color: taux >= 60 ? Colors.green : Colors.orange))),
                  const SizedBox(width: 4),
                  Icon(has ? Icons.edit : Icons.add_circle_outline,
                      size: 12, color: isSelected
                          ? const Color(0xFF1B5E20) : Colors.grey[300]),
                ])));
          }),
        ])));
  }

  Future<void> _envoyer() async {
    final votants = int.tryParse(_ctrl.text);
    if (votants == null || votants < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Entrez un nombre valide'), backgroundColor: Colors.red));
      return;
    }
    if (votants > widget.bureau.inscrits) {
      final ok = await showDialog<bool>(context: context,
        builder: (_) => AlertDialog(
          title: const Text('⚠ Dépassement'),
          content: Text('$votants > ${widget.bureau.inscrits} inscrits. Confirmer ?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Oui')),
          ]));
      if (ok != true) return;
    }
    // Vérifier cohérence avec relevé précédent
    final prev = _snapshots.where((s) => s.heure < _heureSelect).toList();
    if (prev.isNotEmpty) {
      final lastPrev = prev.reduce((a, b) => a.heure > b.heure ? a : b);
      if (votants < lastPrev.votants) {
        final ok = await showDialog<bool>(context: context,
          builder: (_) => AlertDialog(
            title: const Text('⚠ Incohérence'),
            content: Text('$votants votants < ${lastPrev.votants} votants à ${lastPrev.heure}h.\n'
                'Le relevé est cumulatif. Confirmer ?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Oui')),
            ]));
        if (ok != true) return;
      }
    }
    setState(() => _saving = true);
    await _svc.soumettreTurnout(
        widget.bureau.id, widget.user.code, _heureSelect, votants);
    setState(() => _saving = false);
    await _load();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Relevé ${_heureSelect}h enregistré ✓ ($votants votants)'),
        backgroundColor: Colors.green));
  }
}
