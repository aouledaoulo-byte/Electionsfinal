import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/services.dart';

class CartesScreen extends StatefulWidget {
  final AppUser user;
  final Bureau bureau;
  const CartesScreen({super.key, required this.user, required this.bureau});
  @override
  State<CartesScreen> createState() => _CartesScreenState();
}

class _CartesScreenState extends State<CartesScreen> {
  final _svc = ElectionService();
  RetraitCartes? _retraitJour;
  List<RetraitCartesHoraire> _horaires = [];
  bool _loading = true;
  bool _saving = false;

  static final DateTime _debut = DateTime(2026, 3, 10);
  static final DateTime _fin   = DateTime(2026, 4, 10, 18); // 10/04 jusqu'à 18h inclus

  DateTime _dateSelect = DateTime.now();
  int _heureSelect = DateTime.now().hour == 0 ? 1 : DateTime.now().hour;

  final _ctrl = TextEditingController();

  // Jours restants
  int get _joursRestants {
    final diff = _fin.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  bool get _dansPeriode =>
      !DateTime.now().isBefore(_debut) && !DateTime.now().isAfter(_fin);

  // Dernier relevé horaire du jour
  RetraitCartesHoraire? get _dernierHoraire => _horaires.isEmpty ? null
      : _horaires.reduce((a, b) => a.heure > b.heure ? a : b);

  // Relevé existant pour l'heure sélectionnée
  RetraitCartesHoraire? get _releveHeure {
    try { return _horaires.firstWhere((h) => h.heure == _heureSelect); }
    catch (_) { return null; }
  }

  int get _nonRetraits {
    final r = int.tryParse(_ctrl.text) ?? 0;
    return (widget.bureau.inscrits - r).clamp(0, widget.bureau.inscrits);
  }

  double get _tauxSaisi {
    final r = int.tryParse(_ctrl.text) ?? 0;
    return widget.bureau.inscrits > 0 ? r / widget.bureau.inscrits * 100 : 0;
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    if (now.isBefore(_debut)) _dateSelect = _debut;
    else if (now.isAfter(_fin)) _dateSelect = _fin;
    else _dateSelect = now;
    _load();
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await _svc.getRetraitCartes(widget.bureau.id);
    final h = await _svc.getRetraitsHorairesBureau(widget.bureau.id, _dateSelect);
    // Pré-remplir avec le relevé de l'heure sélectionnée
    final existing = h.where((e) => e.heure == _heureSelect).toList();
    if (existing.isNotEmpty) {
      _ctrl.text = existing.first.nbRetraits.toString();
    } else if (_ctrl.text.isEmpty && h.isNotEmpty) {
      // Pré-remplir avec le dernier relevé du jour
      final last = h.reduce((a, b) => a.heure > b.heure ? a : b);
      _ctrl.text = last.nbRetraits.toString();
    }
    setState(() { _retraitJour = r; _horaires = h; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Retraits cartes',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          Text(widget.bureau.id,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ]),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(12), children: [
              _phaseCard(),
              const SizedBox(height: 10),
              _bureauCard(),
              const SizedBox(height: 10),
              _saisieCard(),
              const SizedBox(height: 10),
              if (_horaires.isNotEmpty) _historiqueJour(),
            ]),
    );
  }

  // ── Phase card ─────────────────────────────────────
  Widget _phaseCard() {
    final urgent = _joursRestants <= 7;
    final color = urgent ? Colors.red : const Color(0xFF1B5E20);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(children: [
        Icon(urgent ? Icons.warning_amber : Icons.calendar_today, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Phase retraits cartes',
              style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          Text('10/03/2026 → 10/04/2026',
              style: TextStyle(fontSize: 11, color: color.withOpacity(0.8))),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$_joursRestants', style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 22, color: color)),
          Text('jours restants', style: TextStyle(fontSize: 10, color: color.withOpacity(0.8))),
        ]),
      ]),
    );
  }

  // ── Bureau card ────────────────────────────────────
  Widget _bureauCard() {
    final dernierTaux = _retraitJour != null && widget.bureau.inscrits > 0
        ? _retraitJour!.nbRetraits / widget.bureau.inscrits * 100 : 0.0;

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
          if (_retraitJour != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: dernierTaux >= 70
                    ? Colors.greenAccent.withOpacity(0.3)
                    : Colors.orange.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8)),
              child: Column(children: [
                Text('${dernierTaux.toStringAsFixed(1)}%',
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 18)),
                const Text('retirées', style: TextStyle(color: Colors.white70, fontSize: 9)),
              ]),
            ),
        ]),
        if (_retraitJour != null) ...[
          const SizedBox(height: 10),
          ClipRRect(borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: (dernierTaux / 100).clamp(0.0, 1.0),
              backgroundColor: Colors.white.withOpacity(0.2),
              color: dernierTaux >= 70 ? Colors.greenAccent : Colors.orange,
              minHeight: 8)),
          const SizedBox(height: 4),
          Row(children: [
            Text('${_retraitJour!.nbRetraits} retirées',
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
            const Spacer(),
            Text('${_retraitJour!.nbNonRetraits} non retirées',
                style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
          ]),
        ],
      ])),
    );
  }

  // ── Saisie card ────────────────────────────────────
  Widget _saisieCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(14), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.edit, color: Color(0xFF1B5E20), size: 18),
            const SizedBox(width: 8),
            const Text('Nouveau relevé',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Spacer(),
            if (_releveHeure != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange.withOpacity(0.4))),
                child: const Text('Modification',
                    style: TextStyle(color: Colors.orange, fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
          ]),
          const SizedBox(height: 14),

          // Ligne date + heure
          Row(children: [
            Expanded(
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dateSelect,
                    firstDate: _debut, lastDate: _fin,
                  );
                  if (picked != null) {
                    setState(() { _dateSelect = picked; _horaires = []; _ctrl.clear(); });
                    _load();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(_fmt(_dateSelect),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _heureSelect,
                decoration: const InputDecoration(
                  labelText: 'Heure',
                  border: OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: Icon(Icons.access_time, size: 16)),
                items: List.generate(24, (i) => i + 1).map((h) {
                  final exists = _horaires.any((e) => e.heure == h);
                  return DropdownMenuItem(value: h,
                    child: Row(children: [
                      Text('${h.toString().padLeft(2,'0')}h'),
                      if (exists) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.check_circle, color: Colors.green, size: 12),
                      ],
                    ]));
                }).toList(),
                onChanged: (v) {
                  setState(() => _heureSelect = v!);
                  final existing = _horaires.where((e) => e.heure == v).toList();
                  if (existing.isNotEmpty) {
                    _ctrl.text = existing.first.nbRetraits.toString();
                  } else {
                    // Pré-remplir avec le dernier relevé < heure sélectionnée
                    final prev = _horaires.where((e) => e.heure < v!).toList();
                    if (prev.isNotEmpty) {
                      final last = prev.reduce((a, b) => a.heure > b.heure ? a : b);
                      _ctrl.text = last.nbRetraits.toString();
                    }
                  }
                },
              ),
            ),
          ]),
          const SizedBox(height: 12),

          // Saisie nombre retirées
          TextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            autofocus: false,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              labelText: 'Cartes retirées à ${_heureSelect.toString().padLeft(2,'0')}h00',
              hintText: 'Nombre cumulatif depuis l\'ouverture',
              helperText: 'Sur ${widget.bureau.inscrits} inscrits au total',
              prefixIcon: const Icon(Icons.credit_card, color: Colors.green),
              border: const OutlineInputBorder(),
              counterText: '',
            ),
          ),
          const SizedBox(height: 10),

          // Non retirées — calculé auto + indicateur visuel
          if (_ctrl.text.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _tauxSaisi >= 70
                    ? Colors.green.withOpacity(0.06)
                    : Colors.orange.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _tauxSaisi >= 70
                      ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3))),
              child: Column(children: [
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Non retirées (auto)',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                      Text('$_nonRetraits',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24,
                              color: _tauxSaisi >= 70 ? Colors.green : Colors.orange)),
                    ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${_tauxSaisi.toStringAsFixed(1)}%',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22,
                            color: _tauxSaisi >= 70 ? Colors.green : Colors.orange)),
                    Row(children: [
                      Icon(
                        _tauxSaisi >= 70 ? Icons.thumb_up : Icons.info_outline,
                        size: 12,
                        color: _tauxSaisi >= 70 ? Colors.green : Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        _tauxSaisi >= 70 ? 'Bon taux' : 'Taux faible',
                        style: TextStyle(fontSize: 10,
                            color: _tauxSaisi >= 70 ? Colors.green : Colors.orange)),
                    ]),
                  ]),
                ]),
                const SizedBox(height: 8),
                ClipRRect(borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: (_tauxSaisi / 100).clamp(0.0, 1.0),
                    backgroundColor: Colors.grey[200],
                    color: _tauxSaisi >= 70 ? Colors.green : Colors.orange,
                    minHeight: 10)),
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
                  : Icon(_releveHeure != null ? Icons.update : Icons.save),
              label: Text(_saving ? 'Enregistrement...'
                  : _releveHeure != null
                      ? 'Mettre à jour ${_heureSelect.toString().padLeft(2,'0')}h'
                      : 'Enregistrer ${_heureSelect.toString().padLeft(2,'0')}h'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: _saving ? null : _enregistrer,
            ),
          ),
        ],
      )),
    );
  }

  // ── Historique horaire du jour ─────────────────────
  Widget _historiqueJour() {
    final maxRet = _horaires.isEmpty ? 1
        : _horaires.map((h) => h.nbRetraits).reduce((a, b) => a > b ? a : b);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(14), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.bar_chart, color: Color(0xFF1B5E20), size: 18),
            const SizedBox(width: 8),
            Text('Relevés du ${_fmt(_dateSelect)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(),
            Text('${_horaires.length} saisie(s)',
                style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ]),
          const SizedBox(height: 12),
          ..._horaires.map((h) {
            final taux = widget.bureau.inscrits > 0
                ? h.nbRetraits / widget.bureau.inscrits * 100 : 0.0;
            final ratio = maxRet > 0 ? h.nbRetraits / maxRet : 0.0;
            final isSelected = h.heure == _heureSelect;

            return GestureDetector(
              onTap: () {
                setState(() => _heureSelect = h.heure);
                _ctrl.text = h.nbRetraits.toString();
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF1B5E20).withOpacity(0.06) : null,
                  borderRadius: BorderRadius.circular(6),
                  border: isSelected
                      ? Border.all(color: const Color(0xFF1B5E20).withOpacity(0.3))
                      : null),
                child: Row(children: [
                  SizedBox(width: 36,
                    child: Text('${h.heure.toString().padLeft(2,'0')}h',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: isSelected
                                ? const Color(0xFF1B5E20) : Colors.grey[600]))),
                  Expanded(child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(children: [
                      Container(height: 24, color: Colors.grey[100]),
                      FractionallySizedBox(
                        widthFactor: ratio.clamp(0.0, 1.0),
                        child: Container(height: 24,
                            color: taux >= 70
                                ? Colors.green[400] : Colors.orange[400])),
                      Positioned.fill(child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Align(alignment: Alignment.centerLeft,
                          child: Text('${h.nbRetraits} retirées',
                              style: const TextStyle(color: Colors.white,
                                  fontSize: 11, fontWeight: FontWeight.bold))))),
                    ]))),
                  SizedBox(width: 44,
                    child: Text('${taux.toStringAsFixed(0)}%',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                            color: taux >= 70 ? Colors.green : Colors.orange))),
                  const SizedBox(width: 6),
                  Icon(Icons.edit, size: 12,
                      color: isSelected ? const Color(0xFF1B5E20) : Colors.grey[300]),
                ]),
              ),
            );
          }),
        ],
      )),
    );
  }

  Future<void> _enregistrer() async {
    final retraits = int.tryParse(_ctrl.text);
    if (retraits == null || retraits < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Entrez un nombre valide'), backgroundColor: Colors.red));
      return;
    }
    if (retraits > widget.bureau.inscrits) {
      final ok = await showDialog<bool>(context: context,
        builder: (_) => AlertDialog(
          title: const Text('⚠ Dépassement'),
          content: Text('$retraits dépasse les ${widget.bureau.inscrits} inscrits. Confirmer ?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false),
                child: const Text('Non')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true),
                child: const Text('Oui')),
          ]));
      if (ok != true) return;
    }
    setState(() => _saving = true);
    final nonR = (widget.bureau.inscrits - retraits).clamp(0, widget.bureau.inscrits);
    // Enregistrer relevé horaire
    await _svc.soumettreRetraitHoraire(
        widget.bureau.id, widget.user.code, _dateSelect, _heureSelect, retraits);
    // Mettre à jour le cumul journalier
    await _svc.soumettreRetraitCartes(
        widget.bureau.id, widget.user.code, retraits, nonR, null);
    setState(() => _saving = false);
    await _load();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Relevé ${_heureSelect.toString().padLeft(2,'0')}h enregistré ✓'),
        backgroundColor: Colors.green));
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
}
