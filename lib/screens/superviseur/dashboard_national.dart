import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/services.dart';

class DashboardNational extends StatefulWidget {
  final AppUser user;
  const DashboardNational({super.key, required this.user});
  @override State<DashboardNational> createState() => _DashboardNationalState();
}

class _DashboardNationalState extends State<DashboardNational> {
  final _svc = ElectionService();
  List<Bureau> _bureaux = [];
  List<PvResult> _pvs = [];
  bool _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _loadSilent());
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    await _fetchData();
    setState(() => _loading = false);
  }

  Future<void> _loadSilent() async {
    await _fetchData();
    if (mounted) setState(() {});
  }

  Future<void> _fetchData() async {
    _bureaux = await _svc.getBureaux();
    _pvs = await _svc.getPvPublies();
  }

  // ── Calculs ───────────────────────────────────────
  int get _totalInscrits => _bureaux.fold(0, (s, b) => s + b.inscrits);
  int get _pvCount => _pvs.length;
  int get _totalVotants => _pvs.fold(0, (s, p) => s + p.totalVotants);
  int get _totalA => _pvs.fold(0, (s, p) => s + p.voixCandidatA);
  int get _totalB => _pvs.fold(0, (s, p) => s + p.voixCandidatB);
  int get _totalNuls => _pvs.fold(0, (s, p) => s + p.bulletinsNuls);
  int get _totalAbst => _pvs.fold(0, (s, p) => s + p.abstentions);
  double get _tauxParticipation =>
      _totalInscrits > 0 ? _totalVotants / _totalInscrits * 100 : 0;
  double get _pctA => _totalVotants > 0 ? _totalA / _totalVotants * 100 : 0;
  double get _pctB => _totalVotants > 0 ? _totalB / _totalVotants * 100 : 0;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(12), children: [
              _headerCard(),
              const SizedBox(height: 10),
              if (_pvCount > 0) ...[
                _resultatsCard(),
                const SizedBox(height: 10),
                _graphiqueResultats(),
                const SizedBox(height: 10),
                _parCommuneCard(),
              ] else
                _enAttenteCard(),
            ]),
    );
  }

  Widget _headerCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D47A1),
        borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.public, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          const Expanded(child: Text('Résultats publiés — National',
              style: TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 14))),
          GestureDetector(onTap: _load,
              child: const Icon(Icons.refresh, color: Colors.white)),
        ]),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6)),
          child: Text(
            '✓ Données validées par superviseurs régionaux et national',
            style: const TextStyle(color: Colors.white70, fontSize: 10))),
        const SizedBox(height: 10),
        Row(children: [
          _kpi('PV publiés', '$_pvCount/${_bureaux.length}', Colors.white),
          _vDiv(),
          _kpi('Votants', _totalVotants.toString(), Colors.white),
          _vDiv(),
          _kpi('Participation', '${_tauxParticipation.toStringAsFixed(1)}%',
              _tauxParticipation >= 60 ? Colors.greenAccent : Colors.orange),
        ]),
        const SizedBox(height: 6),
        ClipRRect(borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: (_pvCount / _bureaux.length.clamp(1,9999)).clamp(0.0, 1.0),
            backgroundColor: Colors.white.withOpacity(0.2),
            color: Colors.greenAccent, minHeight: 6)),
        const SizedBox(height: 3),
        Text('$_pvCount / ${_bureaux.length} bureaux publiés',
            style: const TextStyle(color: Colors.white60, fontSize: 10)),
      ]));
  }

  Widget _enAttenteCard() {
    return Card(
      color: Colors.grey[50],
      child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
        Icon(Icons.hourglass_empty, size: 48, color: Colors.grey[400]),
        const SizedBox(height: 12),
        const Text('Aucun résultat publié',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Text('Les résultats apparaîtront ici après validation\n'
            'des PV par les superviseurs régionaux et national.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 13)),
      ])));
  }

  Widget _resultatsCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(14), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Résultats consolidés',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          // Candidat A
          _candidatRow('Candidat A', _totalA, _pctA, Colors.blue),
          const SizedBox(height: 8),
          // Candidat B
          _candidatRow('Candidat B', _totalB, _pctB, Colors.red),
          const Divider(height: 20),
          _statRow('Total votants', '$_totalVotants'),
          _statRow('Bulletins nuls', '$_totalNuls'),
          _statRow('Abstentions', '$_totalAbst'),
          _statRow('Taux participation', '${_tauxParticipation.toStringAsFixed(2)}%'),
          _statRow('Inscrits', '$_totalInscrits'),
        ])));
  }

  Widget _candidatRow(String name, int voix, double pct, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        CircleAvatar(radius: 12, backgroundColor: color,
            child: Text(name[name.length-1],
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 12))),
        const SizedBox(width: 10),
        Expanded(child: Text(name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
        Text('$voix voix',
            style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        const SizedBox(width: 10),
        Text('${pct.toStringAsFixed(1)}%',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(borderRadius: BorderRadius.circular(5),
        child: LinearProgressIndicator(
          value: (pct / 100).clamp(0.0, 1.0),
          backgroundColor: Colors.grey[200], color: color, minHeight: 12)),
    ]);
  }

  Widget _graphiqueResultats() {
    if (_totalA == 0 && _totalB == 0) return const SizedBox.shrink();
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(14), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Répartition des voix',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 16),
          // Barre comparaison A vs B
          Row(children: [
            Expanded(
              flex: _totalA.clamp(1, 999999),
              child: Container(
                height: 40,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.horizontal(left: Radius.circular(6))),
                child: Center(child: Text('A: ${_pctA.toStringAsFixed(1)}%',
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 12))))),
            Expanded(
              flex: _totalB.clamp(1, 999999),
              child: Container(
                height: 40,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.horizontal(right: Radius.circular(6))),
                child: Center(child: Text('B: ${_pctB.toStringAsFixed(1)}%',
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 12))))),
          ]),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _legendItem(Colors.blue, 'Candidat A: $_totalA voix'),
            _legendItem(Colors.red, 'Candidat B: $_totalB voix'),
          ]),
          if (_totalNuls > 0) ...[
            const SizedBox(height: 8),
            _legendItem(Colors.grey, 'Nuls: $_totalNuls · Abstentions: $_totalAbst'),
          ],
        ])));
  }

  Widget _parCommuneCard() {
    final communes = ['RAS DIKA', 'BOULAOS', 'BALBALA'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Par commune', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        ...communes.map((commune) {
          final bC = _bureaux.where((b) => b.region == commune).toList();
          final pvC = _pvs.where((p) {
            return bC.any((b) => b.id == p.bureauId);
          }).toList();
          if (pvC.isEmpty) return const SizedBox.shrink();

          final votants = pvC.fold(0, (s, p) => s + p.totalVotants);
          final a = pvC.fold(0, (s, p) => s + p.voixCandidatA);
          final b = pvC.fold(0, (s, p) => s + p.voixCandidatB);
          final ins = bC.fold(0, (s, b2) => s + b2.inscrits);
          final tauxP = ins > 0 ? votants / ins * 100 : 0.0;
          final pctAc = votants > 0 ? a / votants * 100 : 0.0;
          final pctBc = votants > 0 ? b / votants * 100 : 0.0;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(padding: const EdgeInsets.all(12), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.location_on, color: Color(0xFF1B5E20), size: 16),
                  const SizedBox(width: 6),
                  Text(commune, style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
                  const Spacer(),
                  Text('${pvC.length}/${bC.length} PV',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ]),
                const Divider(height: 12),
                _statRow('Participation', '${tauxP.toStringAsFixed(1)}%'),
                _statRow('Candidat A', '${pctAc.toStringAsFixed(1)}% ($a voix)'),
                _statRow('Candidat B', '${pctBc.toStringAsFixed(1)}% ($b voix)'),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(flex: a.clamp(1,999999),
                      child: Container(height: 8, color: Colors.blue,
                          decoration: const BoxDecoration(
                              borderRadius: BorderRadius.horizontal(left: Radius.circular(4))))),
                  Expanded(flex: b.clamp(1,999999),
                      child: Container(height: 8, color: Colors.red,
                          decoration: const BoxDecoration(
                              borderRadius: BorderRadius.horizontal(right: Radius.circular(4))))),
                ]),
              ])));
        }),
      ]);
  }

  Widget _statRow(String l, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      Expanded(child: Text(l, style: const TextStyle(fontSize: 13))),
      Text(v, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
    ]));

  Widget _legendItem(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 12, height: 12, decoration: BoxDecoration(color: c,
        borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 6),
    Text(label, style: const TextStyle(fontSize: 11)),
  ]);

  Widget _kpi(String l, String v, Color c) => Expanded(child: Column(children: [
    Text(v, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 14)),
    Text(l, style: const TextStyle(color: Colors.white54, fontSize: 9)),
  ]));

  Widget _vDiv() => Container(width: 1, height: 30, color: Colors.white24,
      margin: const EdgeInsets.symmetric(horizontal: 2));
}
