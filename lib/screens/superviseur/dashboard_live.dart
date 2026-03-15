import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/services.dart';

class DashboardLive extends StatefulWidget {
  final AppUser user;
  const DashboardLive({super.key, required this.user});
  @override State<DashboardLive> createState() => _DashboardLiveState();
}

class _DashboardLiveState extends State<DashboardLive> {
  final _svc = ElectionService();
  List<Bureau> _bureaux = [];
  List<TurnoutSnapshot> _snapshots = [];
  bool _loading = true;
  Timer? _timer;
  DateTime _lastUpdate = DateTime.now();

  static final DateTime _jourVote = DateTime(2026, 4, 10);
  static const List<int> _heures = [7,8,9,10,11,12,13,14,15,16,17];

  bool get _estJourVote {
    final now = DateTime.now();
    return now.year == _jourVote.year && now.month == _jourVote.month
        && now.day == _jourVote.day;
  }

  int get _heureActuelle => DateTime.now().hour.clamp(7, 17);

  // ── Stats ─────────────────────────────────────────
  int get _totalInscrits => _bureaux.fold(0, (s, b) => s + b.inscrits);

  // Dernier relevé connu par bureau
  Map<String, TurnoutSnapshot> get _dernierParBureau {
    final map = <String, TurnoutSnapshot>{};
    for (var s in _snapshots) {
      if (!map.containsKey(s.bureauId) || s.heure > map[s.bureauId]!.heure) {
        map[s.bureauId] = s;
      }
    }
    return map;
  }

  int get _totalVotants => _dernierParBureau.values.fold(0, (s, v) => s + v.votants);
  double get _tauxGlobal => _totalInscrits > 0 ? _totalVotants / _totalInscrits * 100 : 0;
  int get _bureauxSaisis => _dernierParBureau.length;
  double get _couverture => _bureaux.isEmpty ? 0 : _bureauxSaisis / _bureaux.length * 100;

  // Relevés manquants à l'heure actuelle
  List<Bureau> get _bureausSansReleve => _estJourVote
      ? _bureaux.where((b) =>
          !_snapshots.any((s) => s.bureauId == b.id && s.heure == _heureActuelle))
          .toList()
      : [];

  // Stats par heure (courbe)
  Map<int, int> get _statsParHeure {
    final map = <int, int>{};
    for (var h in _heures) {
      // Pour chaque bureau, prendre le dernier relevé <= h
      int total = 0;
      for (var b in _bureaux) {
        final snapsH = _snapshots.where((s) => s.bureauId == b.id && s.heure <= h).toList();
        if (snapsH.isNotEmpty) {
          total += snapsH.reduce((a, b) => a.heure > b.heure ? a : b).votants;
        }
      }
      map[h] = total;
    }
    return map;
  }

  // Stats par commune
  Map<String, Map<String, dynamic>> get _statsByCommune {
    final map = <String, Map<String, dynamic>>{};
    for (var commune in ['RAS DIKA', 'BOULAOS', 'BALBALA']) {
      final bC = _bureaux.where((b) => b.region == commune).toList();
      final ins = bC.fold(0, (s, b) => s + b.inscrits);
      int votants = 0;
      int saisis = 0;
      for (var b in bC) {
        final last = _dernierParBureau[b.id];
        if (last != null) { votants += last.votants; saisis++; }
      }
      map[commune] = {
        'bureaux': bC.length, 'saisis': saisis,
        'inscrits': ins, 'votants': votants,
        'taux': ins > 0 ? votants / ins * 100 : 0.0,
      };
    }
    return map;
  }

  @override
  void initState() {
    super.initState();
    final region = widget.user.isSuperviseurRegional ? widget.user.region : null;
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _loadSilent());
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    await _fetchData();
    setState(() { _loading = false; _lastUpdate = DateTime.now(); });
  }

  Future<void> _loadSilent() async {
    await _fetchData();
    if (mounted) setState(() => _lastUpdate = DateTime.now());
  }

  Future<void> _fetchData() async {
    final region = widget.user.isSuperviseurRegional ? widget.user.region : null;
    _bureaux = await _svc.getBureaux(region: region);
    _snapshots = await _svc.getTurnoutAll(region: region);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(12), children: [
              _headerCard(),
              const SizedBox(height: 10),
              if (widget.user.isSuperviseurNational) ...[
                _communesGrid(),
                const SizedBox(height: 10),
              ],
              _courbeHoraire(),
              const SizedBox(height: 10),
              if (_bureausSansReleve.isNotEmpty) _alertesBureaux(),
              const SizedBox(height: 10),
              _classementBureaux(),
            ]),
    );
  }

  // ── Header global ──────────────────────────────────
  Widget _headerCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B5E20),
        borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.bar_chart, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              widget.user.isSuperviseurNational
                  ? 'Participation nationale — Live'
                  : 'Participation ${widget.user.region} — Live',
              style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 14)),
            Text('Mise à jour: ${_lastUpdate.hour.toString().padLeft(2,'0')}:'
                '${_lastUpdate.minute.toString().padLeft(2,'0')}:'
                '${_lastUpdate.second.toString().padLeft(2,'0')}',
                style: const TextStyle(color: Colors.white54, fontSize: 10)),
          ])),
          // Badge live
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.circle, color: Colors.greenAccent, size: 8),
              SizedBox(width: 4),
              Text('30s', style: TextStyle(color: Colors.white,
                  fontSize: 10, fontWeight: FontWeight.bold)),
            ])),
          const SizedBox(width: 8),
          GestureDetector(onTap: _load,
              child: const Icon(Icons.refresh, color: Colors.white, size: 20)),
        ]),
        const SizedBox(height: 12),
        // KPIs
        Row(children: [
          _kpi('Participation', '${_tauxGlobal.toStringAsFixed(1)}%',
              _tauxGlobal >= 60 ? Colors.greenAccent : Colors.orange, large: true),
          _vDiv(),
          _kpi('Votants', _totalVotants.toString(), Colors.white),
          _vDiv(),
          _kpi('Inscrits', _totalInscrits.toString(), Colors.white70),
          _vDiv(),
          _kpi('Bureaux', '$_bureauxSaisis/${_bureaux.length}',
              _couverture >= 80 ? Colors.greenAccent : Colors.white70),
        ]),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (_tauxGlobal / 100).clamp(0.0, 1.0),
            backgroundColor: Colors.white.withOpacity(0.2),
            color: _tauxGlobal >= 60 ? Colors.greenAccent : Colors.orange,
            minHeight: 10)),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('$_totalVotants / $_totalInscrits inscrits ont voté',
              style: const TextStyle(color: Colors.white70, fontSize: 10)),
          if (_estJourVote)
            Text('Bureau ouvert — ${_heureActuelle}h en cours',
                style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ]),
      ]));
  }

  // ── Communes (national) ────────────────────────────
  Widget _communesGrid() {
    final communes = _statsByCommune;
    final colors = {'RAS DIKA': Colors.teal, 'BOULAOS': Colors.blue, 'BALBALA': Colors.purple};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Par commune', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        ...communes.entries.map((e) {
          final s = e.value;
          final taux = s['taux'] as double;
          final color = colors[e.key] ?? Colors.grey;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
              Row(children: [
                CircleAvatar(backgroundColor: color.withOpacity(0.15),
                    child: Icon(Icons.location_on, color: color, size: 18)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('${s['saisis']}/${s['bureaux']} bureaux · ${s['votants']}/${s['inscrits']} votants',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (taux >= 60 ? Colors.green : taux >= 40 ? Colors.orange : Colors.red)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                  child: Text('${taux.toStringAsFixed(1)}%',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16,
                          color: taux >= 60 ? Colors.green : taux >= 40 ? Colors.orange : Colors.red))),
              ]),
              const SizedBox(height: 8),
              ClipRRect(borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: (taux / 100).clamp(0.0, 1.0),
                  backgroundColor: Colors.grey[200],
                  color: taux >= 60 ? Colors.green : taux >= 40 ? Colors.orange : Colors.red,
                  minHeight: 8)),
            ])));
        }),
      ]);
  }

  // ── Courbe horaire 7h→17h ──────────────────────────
  Widget _courbeHoraire() {
    final stats = _statsParHeure;
    final maxV = stats.values.isEmpty ? 1
        : stats.values.reduce((a, b) => a > b ? a : b).clamp(1, 9999999);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(14), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.timeline, color: Color(0xFF1B5E20), size: 18),
            const SizedBox(width: 8),
            const Text('Évolution horaire',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(),
            const Text('07h → 17h (cumulatif)',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
          const SizedBox(height: 16),
          // Graphique barres
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _heures.map((h) {
                final v = stats[h] ?? 0;
                final ratio = maxV > 0 ? v / maxV : 0.0;
                final taux = _totalInscrits > 0 ? v / _totalInscrits * 100 : 0.0;
                final isCurrent = _estJourVote && h == _heureActuelle;
                final isFuture = _estJourVote && h > _heureActuelle || !_estJourVote;
                final color = isCurrent ? Colors.orange
                    : isFuture ? Colors.grey[300]!
                    : taux >= 60 ? const Color(0xFF1B5E20) : Colors.orange;

                return Expanded(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    if (v > 0 && !isFuture)
                      Text('${taux.toStringAsFixed(0)}%',
                          style: TextStyle(fontSize: 8, color: color,
                              fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      child: Container(
                        height: 100 * ratio.clamp(0.0, 1.0),
                        color: color)),
                    const SizedBox(height: 4),
                    Text('${h}h', style: TextStyle(fontSize: 8,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: isCurrent ? Colors.orange : Colors.grey[600])),
                    if (isCurrent)
                      const Icon(Icons.keyboard_arrow_up,
                          size: 10, color: Colors.orange),
                  ])));
              }).toList()),
          ),
        ])));
  }

  // ── Alertes bureaux sans relevé ────────────────────
  Widget _alertesBureaux() {
    final manquants = _bureausSansReleve;
    if (manquants.isEmpty) return const SizedBox.shrink();
    return Card(
      color: Colors.orange[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(12), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.warning_amber, color: Colors.orange, size: 18),
            const SizedBox(width: 8),
            Text('${manquants.length} bureau(x) sans relevé à ${_heureActuelle}h',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
          ]),
          const SizedBox(height: 8),
          ...manquants.take(8).map((b) => Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(children: [
              Text(b.id, style: const TextStyle(fontSize: 11,
                  fontWeight: FontWeight.bold, color: Colors.orange)),
              const SizedBox(width: 8),
              Expanded(child: Text(b.nom, style: const TextStyle(fontSize: 11),
                  overflow: TextOverflow.ellipsis)),
            ]))),
          if (manquants.length > 8)
            Text('+ ${manquants.length - 8} autres...',
                style: TextStyle(fontSize: 10, color: Colors.orange[600])),
        ])));
  }

  // ── Classement bureaux par participation ──────────
  Widget _classementBureaux() {
    final dpb = _dernierParBureau;
    final List<Map<String, dynamic>> items = [];

    for (var b in _bureaux) {
      final snap = dpb[b.id];
      items.add({
        'bureau': b,
        'votants': snap?.votants ?? 0,
        'heure': snap?.heure ?? 0,
        'taux': snap != null && b.inscrits > 0 ? snap.votants / b.inscrits * 100 : 0.0,
        'saisi': snap != null,
      });
    }
    // Trier: non saisis d'abord, puis par taux croissant
    items.sort((a, b) {
      if (!a['saisi'] && b['saisi']) return -1;
      if (a['saisi'] && !b['saisi']) return 1;
      return (a['taux'] as double).compareTo(b['taux'] as double);
    });

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('Bureaux — Participation',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const Spacer(),
        Text('Triés: faible en premier',
            style: TextStyle(fontSize: 10, color: Colors.grey[500])),
      ]),
      const SizedBox(height: 6),
      ...items.take(20).map((item) {
        final b = item['bureau'] as Bureau;
        final taux = item['taux'] as double;
        final saisi = item['saisi'] as bool;
        final color = !saisi ? Colors.red[400]!
            : taux >= 60 ? Colors.green : taux >= 40 ? Colors.orange : Colors.red[600]!;

        return Card(
          margin: const EdgeInsets.only(bottom: 5),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Container(width: 4, height: 44, decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(b.id, style: const TextStyle(fontWeight: FontWeight.bold,
                      fontSize: 12, color: Color(0xFF1B5E20))),
                  if (saisi) ...[
                    const SizedBox(width: 6),
                    Text('à ${item['heure']}h',
                        style: TextStyle(fontSize: 9, color: Colors.grey[400])),
                  ],
                ]),
                Text(b.nom, style: const TextStyle(fontSize: 11),
                    overflow: TextOverflow.ellipsis),
                if (saisi) ...[
                  const SizedBox(height: 3),
                  LinearProgressIndicator(
                    value: (taux / 100).clamp(0.0, 1.0),
                    backgroundColor: Colors.grey[200],
                    color: color, minHeight: 4),
                ],
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                if (saisi)
                  Text('${taux.toStringAsFixed(1)}%',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13,
                          color: color))
                else
                  Text('⚠ Non saisi',
                      style: TextStyle(fontSize: 10, color: Colors.red[400],
                          fontWeight: FontWeight.bold)),
                if (saisi)
                  Text('${item['votants']}/${b.inscrits}',
                      style: const TextStyle(fontSize: 9, color: Colors.grey)),
              ]),
            ])));
      }),
      if (items.length > 20)
        Center(child: Text('+ ${items.length - 20} autres bureaux',
            style: const TextStyle(color: Colors.grey, fontSize: 12))),
    ]);
  }

  Widget _kpi(String l, String v, Color c, {bool large = false}) =>
      Expanded(child: Column(children: [
        Text(v, style: TextStyle(color: c, fontWeight: FontWeight.bold,
            fontSize: large ? 16 : 13)),
        Text(l, style: const TextStyle(color: Colors.white54, fontSize: 9)),
      ]));

  Widget _vDiv() => Container(width: 1, height: 30, color: Colors.white24,
      margin: const EdgeInsets.symmetric(horizontal: 2));
}
