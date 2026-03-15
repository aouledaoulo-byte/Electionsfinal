import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/services.dart';

class CartesSuiviScreen extends StatefulWidget {
  final AppUser user;
  const CartesSuiviScreen({super.key, required this.user});
  @override State<CartesSuiviScreen> createState() => _CartesSuiviScreenState();
}

class _CartesSuiviScreenState extends State<CartesSuiviScreen>
    with SingleTickerProviderStateMixin {
  final _svc = ElectionService();
  late TabController _tabs;
  List<Bureau> _bureaux = [];
  List<RetraitCartes> _retraits = [];
  List<RetraitCartesHoraire> _horaires = [];
  bool _loading = true;
  Timer? _timer;

  static final DateTime _debut = DateTime(2026, 3, 10);
  static final DateTime _fin   = DateTime(2026, 4, 10, 18);

  String _filterCommune = 'Toutes';
  DateTime _semaineSelect = DateTime.now();
  final _searchCtrl = TextEditingController();

  // ── Jours restants ────────────────────────────────
  int get _joursRestants {
    final d = _fin.difference(DateTime.now()).inDays;
    return d < 0 ? 0 : d;
  }

  // ── Filtres ───────────────────────────────────────
  List<Bureau> get _bureausFiltres {
    final q = _searchCtrl.text.toLowerCase();
    return _bureaux.where((b) {
      final mc = _filterCommune == 'Toutes' || b.region == _filterCommune;
      final ms = q.isEmpty || b.nom.toLowerCase().contains(q) || b.id.toLowerCase().contains(q);
      return mc && ms;
    }).toList();
  }

  Map<String, RetraitCartes> get _retraitMap => {for (var r in _retraits) r.bureauId: r};

  List<RetraitCartes> get _retraitsFiltres {
    final ids = _bureausFiltres.map((b) => b.id).toSet();
    return _retraits.where((r) => ids.contains(r.bureauId)).toList();
  }

  // ── Stats globales (toutes saisies) ──────────────
  int get _totalInscrits => _bureausFiltres.fold(0, (s, b) => s + b.inscrits);
  int get _totalRetraits => _retraitsFiltres.fold(0, (s, r) => s + r.nbRetraits);
  int get _totalNonRetraits => _retraitsFiltres.fold(0, (s, r) => s + r.nbNonRetraits);
  double get _tauxGlobal => _totalInscrits > 0 ? _totalRetraits / _totalInscrits * 100 : 0;
  int get _nbSaisis => _retraitsFiltres.length;
  int get _nbValides => _retraitsFiltres.where((r) => r.valide).length;
  double get _couverture => _bureaux.isEmpty ? 0 : _nbSaisis / _bureaux.length * 100;

  // ── Bureaux non saisis aujourd'hui ───────────────
  List<Bureau> get _bureausSansSignalement {
    final today = DateTime.now();
    final saisisAuj = _retraits.where((r) {
      final ds = r.dateSaisie ?? r.updatedAt;
      return ds.year == today.year && ds.month == today.month && ds.day == today.day;
    }).map((r) => r.bureauId).toSet();
    return _bureausFiltres.where((b) => !saisisAuj.contains(b.id)).toList();
  }

  // ── Stats par commune ─────────────────────────────
  Map<String, Map<String, dynamic>> get _statsByCommune {
    final map = <String, Map<String, dynamic>>{};
    for (var commune in ['RAS DIKA', 'BOULAOS', 'BALBALA']) {
      final bC = _bureaux.where((b) => b.region == commune).toList();
      final rC = _retraits.where((r) => bC.any((b) => b.id == r.bureauId)).toList();
      final ins = bC.fold(0, (s, b) => s + b.inscrits);
      final ret = rC.fold(0, (s, r) => s + r.nbRetraits);
      map[commune] = {
        'bureaux': bC.length, 'saisis': rC.length,
        'inscrits': ins, 'retraits': ret,
        'taux': ins > 0 ? ret / ins * 100 : 0.0,
      };
    }
    return map;
  }

  // ── Stats journalières depuis horaires ───────────
  Map<String, Map<String, int>> get _statsParDate {
    final maxParBureau = <String, RetraitCartesHoraire>{};
    for (var h in _horaires) {
      if (widget.user.isSuperviseurRegional) {
        final b = _bureaux.firstWhere((b) => b.id == h.bureauId,
            orElse: () => Bureau(id:'',nom:'',region:'',inscrits:0));
        if (b.region != widget.user.region) continue;
      }
      final ds = _dateStr(h.dateSaisie);
      final key = h.bureauId + '_' + ds;
      if (!maxParBureau.containsKey(key) || h.heure > maxParBureau[key]!.heure) {
        maxParBureau[key] = h;
      }
    }
    final map = <String, Map<String, int>>{};
    for (var h in maxParBureau.values) {
      final ds = _dateStr(h.dateSaisie);
      map.putIfAbsent(ds, () => {'retraits': 0, 'non_retraits': 0, 'bureaux': 0});
      map[ds]!['retraits'] = map[ds]!['retraits']! + h.nbRetraits;
      map[ds]!['non_retraits'] = map[ds]!['non_retraits']! + h.nbNonRetraits;
      map[ds]!['bureaux'] = map[ds]!['bureaux']! + 1;
    }
    return map;
  }

  // ── Semaines ──────────────────────────────────────
  DateTime get _lundiSemaine {
    var l = _semaineSelect.subtract(Duration(days: _semaineSelect.weekday - 1));
    if (l.isBefore(_debut)) l = _debut;
    if (l.isAfter(_fin)) l = _fin.subtract(const Duration(days: 6));
    return l;
  }
  List<DateTime> get _joursSemaine => List.generate(7,
      (i) => _lundiSemaine.add(Duration(days: i)))
      .where((d) => !d.isAfter(_fin) && !d.isBefore(_debut)).toList();

  List<DateTime> get _semaines {
    final weeks = <DateTime>[];
    var d = _debut;
    while (d.weekday != 1) d = d.subtract(const Duration(days: 1));
    while (!d.isAfter(_fin)) { weeks.add(d); d = d.add(const Duration(days: 7)); }
    return weeks;
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    if (widget.user.isSuperviseurRegional) _filterCommune = widget.user.region!;
    final now = DateTime.now();
    _semaineSelect = (now.isAfter(_debut) && now.isBefore(_fin)) ? now : _debut;
    _load();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _loadSilent());
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() { _timer?.cancel(); _tabs.dispose(); _searchCtrl.dispose(); super.dispose(); }

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
    final region = widget.user.isSuperviseurRegional ? widget.user.region : null;
    _bureaux = await _svc.getBureaux(region: region);
    _retraits = await _svc.getAllRetraitCartes(region: region);
    try {
      _horaires = await _svc.getAllRetraitsHoraires(region: region);
    } catch (_) { _horaires = []; }
  }

  @override
  Widget build(BuildContext context) {
    final urgent = _joursRestants <= 7;
    return Column(children: [
      // ── Header ──────────────────────────────────
      Container(
        color: const Color(0xFF1B5E20),
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(children: [
            const Icon(Icons.credit_card, color: Colors.white70, size: 16),
            const SizedBox(width: 6),
            const Expanded(child: Text('Suivi retraits cartes',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            // Badge live
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.circle, color: Colors.greenAccent, size: 8),
                SizedBox(width: 4),
                Text('Live 10s', style: TextStyle(color: Colors.white, fontSize: 9)),
              ])),
            const SizedBox(width: 8),
            // Jours restants
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: urgent ? Colors.red.withOpacity(0.4) : Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(urgent ? Icons.warning_amber : Icons.calendar_today,
                    color: Colors.white, size: 12),
                const SizedBox(width: 4),
                Text('$_joursRestants j.',
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 11)),
              ])),
            const SizedBox(width: 8),
            GestureDetector(onTap: _load,
                child: const Icon(Icons.refresh, color: Colors.white, size: 18)),
          ]),
          const SizedBox(height: 8),
          // KPIs
          Row(children: [
            _kpiTop('Taux', '${_tauxGlobal.toStringAsFixed(1)}%',
                _tauxGlobal >= 70 ? Colors.greenAccent : Colors.orange),
            _vDiv(),
            _kpiTop('Retirées', _totalRetraits.toString(), Colors.white),
            _vDiv(),
            _kpiTop('Restantes', _totalNonRetraits.toString(), Colors.redAccent),
            _vDiv(),
            _kpiTop('Couverture', '${_couverture.toStringAsFixed(0)}%',
                _couverture >= 80 ? Colors.greenAccent : Colors.white70),
          ]),
          const SizedBox(height: 6),
          ClipRRect(borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (_tauxGlobal / 100).clamp(0.0, 1.0),
              backgroundColor: Colors.red.withOpacity(0.3),
              color: _tauxGlobal >= 70 ? Colors.greenAccent : Colors.orange,
              minHeight: 8)),
          const SizedBox(height: 3),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('$_totalRetraits / $_totalInscrits inscrits',
                style: const TextStyle(color: Colors.white70, fontSize: 10)),
            Text('$_nbSaisis/${_bureaux.length} bureaux · $_nbValides validés',
                style: const TextStyle(color: Colors.white60, fontSize: 10)),
          ]),
        ]),
      ),

      TabBar(
        controller: _tabs,
        labelColor: const Color(0xFF1B5E20),
        indicatorColor: const Color(0xFF1B5E20),
        tabs: [
          const Tab(icon: Icon(Icons.today, size: 16), text: 'Jour'),
          const Tab(icon: Icon(Icons.date_range, size: 16), text: 'Semaine'),
          Tab(icon: Stack(children: [
            const Icon(Icons.list, size: 20),
            if (_bureausSansSignalement.isNotEmpty)
              Positioned(right: 0, top: 0,
                child: Container(width: 8, height: 8,
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle))),
          ]), text: 'Bureaux'),
        ],
      ),

      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(controller: _tabs, children: [
                _jourTab(), _semaineTab(), _bureauTab()]),
      ),
    ]);
  }

  // ────────────────────────────────────────────────────
  // ONGLET JOUR
  // ────────────────────────────────────────────────────
  Widget _jourTab() {
    final today = DateTime.now();
    final todayStr = _dateStr(today);
    final statsDate = _statsParDate;

    // Retraits saisis aujourd'hui
    final todayR = _retraitsFiltres.where((r) {
      final ds = r.dateSaisie ?? r.updatedAt;
      return ds.year == today.year && ds.month == today.month && ds.day == today.day;
    }).toList();

    final retAuj = todayR.fold(0, (s, r) => s + r.nbRetraits);
    final nonAuj = todayR.fold(0, (s, r) => s + r.nbNonRetraits);
    final insAuj = todayR.fold(0, (s, r) {
      final b = _bureaux.firstWhere((b) => b.id == r.bureauId,
          orElse: () => Bureau(id:'',nom:'',region:'',inscrits:0));
      return s + b.inscrits;
    });
    final tauxAuj = insAuj > 0 ? retAuj / insAuj * 100 : 0.0;

    // Jours depuis début
    final jours = <DateTime>[];
    var d = _debut;
    while (!d.isAfter(today) && !d.isAfter(_fin)) { jours.add(d); d = d.add(const Duration(days: 1)); }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(12), children: [

        // Résumé aujourd'hui
        Card(color: Colors.blue[50], shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
          child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
            Row(children: [
              const Icon(Icons.today, color: Colors.blue, size: 18),
              const SizedBox(width: 8),
              Text("Aujourd'hui — ${_fmtLong(today)}",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const Spacer(),
              Text('${todayR.length} bur.',
                  style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              _miniStat('Retirées', retAuj.toString(), Colors.green),
              _miniStat('Non ret.', nonAuj.toString(), Colors.red),
              _miniStat('Taux jour', '${tauxAuj.toStringAsFixed(1)}%',
                  tauxAuj >= 70 ? Colors.green : Colors.orange),
              _miniStat('Bureaux', '${todayR.length}', Colors.blue),
            ]),
            if (todayR.isNotEmpty) ...[
              const SizedBox(height: 8),
              ClipRRect(borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: (tauxAuj / 100).clamp(0.0, 1.0),
                  backgroundColor: Colors.grey[200],
                  color: tauxAuj >= 70 ? Colors.green : Colors.orange,
                  minHeight: 10)),
            ],
          ]))),
        const SizedBox(height: 8),

        // Alertes bureaux sans saisie
        if (_bureausSansSignalement.isNotEmpty) ...[
          Card(
            color: Colors.orange[50],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(padding: const EdgeInsets.all(12), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.warning_amber, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Text('${_bureausSansSignalement.length} bureau(x) sans saisie aujourd\'hui',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                ]),
                const SizedBox(height: 6),
                ..._bureausSansSignalement.take(5).map((b) => Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Row(children: [
                    Text(b.id, style: const TextStyle(fontSize: 11,
                        fontWeight: FontWeight.bold, color: Colors.orange)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(b.nom,
                        style: const TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis)),
                  ]))),
                if (_bureausSansSignalement.length > 5)
                  Text('+ ${_bureausSansSignalement.length - 5} autres...',
                      style: TextStyle(fontSize: 10, color: Colors.orange[600])),
              ],
            )),
          ),
          const SizedBox(height: 8),
        ],

        // Validation en lot (national)
        if (widget.user.isSuperviseurNational) ...[
          _validationLotCard(),
          const SizedBox(height: 8),
        ],

        // Par commune aujourd'hui (national)
        if (widget.user.isSuperviseurNational && todayR.isNotEmpty) ...[
          const Text('Par commune — Aujourd\'hui',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          ..._statsByCommune.entries.map((e) {
            final rC = todayR.where((r) {
              final b = _bureaux.firstWhere((b) => b.id == r.bureauId,
                  orElse: () => Bureau(id:'',nom:'',region:'',inscrits:0));
              return b.region == e.key;
            }).toList();
            final ret = rC.fold(0, (s, r) => s + r.nbRetraits);
            final ins = e.value['inscrits'] as int;
            final taux = ins > 0 ? ret / ins * 100 : 0.0;
            return Card(margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(dense: true,
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF1B5E20).withOpacity(0.1),
                  child: const Icon(Icons.location_on, color: Color(0xFF1B5E20), size: 16)),
                title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$ret retirées | ${rC.length} bureaux'),
                  LinearProgressIndicator(
                    value: (taux / 100).clamp(0.0, 1.0),
                    backgroundColor: Colors.grey[200],
                    color: taux >= 70 ? Colors.green : Colors.orange,
                    minHeight: 4),
                ]),
                trailing: Text('${taux.toStringAsFixed(1)}%',
                    style: TextStyle(fontWeight: FontWeight.bold,
                        color: taux >= 70 ? Colors.green : Colors.orange)),
              ));
          }),
          const SizedBox(height: 10),
        ],

        // Historique journalier
        const Text('Historique depuis le 10/03/2026',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        ...jours.reversed.map((j) {
          final s = statsDate[_dateStr(j)];
          final retFromStats = s != null ? (s['retraits'] as int? ?? 0) : 0;
          final retFromList = _retraits.where((r) {
            final ds = r.dateSaisie;
            return ds != null && _dateStr(ds) == _dateStr(j);
          }).fold(0, (s2, r) => s2 + r.nbRetraits);
          final int ret = retFromStats > 0 ? retFromStats : retFromList;
          final int bur = s != null ? (s['bureaux'] as int? ?? 0) : 0;
          final isToday = _dateStr(j) == todayStr;
          final taux = _totalInscrits > 0 ? ret / _totalInscrits * 100 : 0.0;
          return Card(margin: const EdgeInsets.only(bottom: 4),
            color: isToday ? Colors.blue[50] : null,
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(children: [
                Row(children: [
                  Icon(isToday ? Icons.today : Icons.calendar_today,
                      color: isToday ? Colors.blue : Colors.grey[400], size: 14),
                  const SizedBox(width: 6),
                  Text(_fmtLong(j), style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12,
                      color: isToday ? Colors.blue[800] : Colors.black87)),
                  if (isToday) ...[
                    const SizedBox(width: 6),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: Colors.blue,
                          borderRadius: BorderRadius.circular(4)),
                      child: const Text('Auj.', style: TextStyle(color: Colors.white,
                          fontSize: 9, fontWeight: FontWeight.bold))),
                  ],
                  const Spacer(),
                  Text(ret > 0 ? '$bur bur.' : 'Aucune saisie',
                      style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                ]),
                if (ret > 0) ...[
                  const SizedBox(height: 5),
                  LinearProgressIndicator(
                    value: (taux / 100).clamp(0.0, 1.0),
                    backgroundColor: Colors.grey[200],
                    color: taux >= 70 ? Colors.green : Colors.orange,
                    minHeight: 6, borderRadius: BorderRadius.circular(3)),
                  const SizedBox(height: 3),
                  Row(children: [
                    Text('$ret retirées',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                            color: Colors.green[700])),
                    const Spacer(),
                    Text('${taux.toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                            color: taux >= 70 ? Colors.green : Colors.orange)),
                  ]),
                ],
              ])));
        }),
      ]),
    );
  }

  Widget _validationLotCard() {
    final enAttente = _retraits.where((r) => !r.valide).toList();
    if (enAttente.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.green[50],
            borderRadius: BorderRadius.circular(10)),
        child: const Row(children: [
          Icon(Icons.verified, color: Colors.green, size: 16),
          SizedBox(width: 8),
          Text('Toutes les saisies sont validées ✓',
              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        ]));
    }
    return Card(color: Colors.orange[50],
      child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        const Icon(Icons.hourglass_empty, color: Colors.orange, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${enAttente.length} saisies en attente',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
          const Text('Non encore validées par vous',
              style: TextStyle(fontSize: 11, color: Colors.grey)),
        ])),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
          child: const Text('Valider tout', style: TextStyle(fontSize: 12)),
          onPressed: () async {
            for (var r in enAttente) await _svc.validerRetraitCartes(r.id);
            await _load();
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('${enAttente.length} validés ✓'),
                backgroundColor: Colors.green));
          },
        ),
      ])));
  }

  // ────────────────────────────────────────────────────
  // ONGLET SEMAINE
  // ────────────────────────────────────────────────────
  Widget _semaineTab() {
    final statsDate = _statsParDate;
    final semaines = _semaines;
    final retSemaine = _joursSemaine.fold(0, (s, j) => s + _getJourRet(j, statsDate));
    int maxJour = 1;
    if (statsDate.isNotEmpty) {
      for (final v in statsDate.values) {
        final r = (v['retraits'] ?? 0) as int;
        if (r > maxJour) maxJour = r;
      }
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(12), children: [

        // Sélecteur semaine
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.calendar_view_week, color: Color(0xFF1B5E20), size: 18),
              SizedBox(width: 8),
              Text('Sélectionner une semaine',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: semaines.asMap().entries.map((entry) {
                final i = entry.key; final sem = entry.value;
                final fin = sem.add(const Duration(days: 6));
                final isSel = !_lundiSemaine.isBefore(sem) &&
                    _lundiSemaine.isBefore(fin.add(const Duration(days: 1)));
                final retW = List.generate(7, (j) => sem.add(Duration(days: j)))
                    .fold(0, (s, d) => s + _getJourRet(d, statsDate));
                return GestureDetector(
                  onTap: () => setState(() => _semaineSelect = sem),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSel ? const Color(0xFF1B5E20) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8)),
                    child: Column(children: [
                      Text('S${i+1}', style: TextStyle(fontWeight: FontWeight.bold,
                          fontSize: 12, color: isSel ? Colors.white : Colors.black87)),
                      Text('${sem.day}/${sem.month}', style: TextStyle(fontSize: 9,
                          color: isSel ? Colors.white70 : Colors.grey)),
                      if (retW > 0) Text('$retW', style: TextStyle(fontSize: 8,
                          color: isSel ? Colors.greenAccent : Colors.green[600],
                          fontWeight: FontWeight.bold)),
                    ])));
              }).toList())),
          ])));

        const SizedBox(height: 10),

        // Graphique barres
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('${_fmt(_joursSemaine.first)} → ${_fmt(_joursSemaine.last)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6)),
                child: Text('$retSemaine retraits cette semaine',
                    style: TextStyle(color: Colors.green[700], fontSize: 11,
                        fontWeight: FontWeight.bold))),
            ]),
            const SizedBox(height: 12),
            ..._joursSemaine.map((jour) {
              final ret = _getJourRet(jour, statsDate);
              final burRaw = statsDate[_dateStr(jour)];
              final int bur = burRaw != null ? (burRaw['bureaux'] as int? ?? 0) : 0;
              final isFuture = jour.isAfter(DateTime.now());
              final isToday = _dateStr(jour) == _dateStr(DateTime.now());
              final ratio = maxJour > 0 && ret > 0 ? ret / maxJour : 0.0;
              final taux = _totalInscrits > 0 ? ret / _totalInscrits * 100 : 0.0;
              final jourNoms = ['Lun','Mar','Mer','Jeu','Ven','Sam','Dim'];
              return Padding(padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  SizedBox(width: 34, child: Text(jourNoms[jour.weekday-1],
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                          color: isToday ? const Color(0xFF1B5E20) : Colors.grey[600]))),
                  SizedBox(width: 44, child: Text('${jour.day}/${jour.month}',
                      style: TextStyle(fontSize: 10, color: Colors.grey[400]))),
                  Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(5),
                    child: Stack(children: [
                      Container(height: 30, color: isFuture ? Colors.grey[50] : Colors.grey[100]),
                      if (!isFuture && ret > 0)
                        FractionallySizedBox(widthFactor: ratio.clamp(0.0,1.0),
                          child: Container(height: 30,
                              color: isToday ? const Color(0xFF1B5E20) : Colors.green[300])),
                      if (!isFuture && ret > 0)
                        Positioned.fill(child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('$ret retraits', style: const TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.bold, fontSize: 11)),
                              Text('$bur bur.', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                            ]))),
                      if (isFuture) Positioned.fill(child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Align(alignment: Alignment.centerLeft,
                          child: Text('À venir', style: TextStyle(fontSize: 10, color: Colors.grey[400]))))),
                    ]))),
                  SizedBox(width: 44, child: Text(ret > 0 ? '${taux.toStringAsFixed(0)}%' : '',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                ]));
            }),
            const Divider(),
            Row(children: [
              const Text('Total semaine', style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('$retSemaine retraits',
                  style: TextStyle(fontWeight: FontWeight.bold,
                      color: retSemaine > 0 ? Colors.green : Colors.grey)),
            ]),
          ])));

        const SizedBox(height: 10),

        // Synthèse cumulative période
        Card(color: Colors.green[50], shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
          child: Padding(padding: const EdgeInsets.all(14), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.summarize, color: Color(0xFF1B5E20), size: 18),
                const SizedBox(width: 8),
                Text('Cumul ${_fmt(_debut)} → ${_fmt(_fin)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ]),
              const SizedBox(height: 10),
              _statL('Total inscrits', '$_totalInscrits', Colors.indigo),
              _statL('Cartes retirées', '$_totalRetraits', Colors.green),
              _statL('Non retirées', '$_totalNonRetraits', Colors.red),
              _statL('Taux de retrait', '${_tauxGlobal.toStringAsFixed(2)}%',
                  _tauxGlobal >= 70 ? Colors.green : Colors.orange),
              _statL('Bureaux saisis', '$_nbSaisis / ${_bureaux.length}', Colors.blue),
              _statL('Bureaux validés ✓', '$_nbValides / ${_bureaux.length}', Colors.green),
              const SizedBox(height: 8),
              ClipRRect(borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (_tauxGlobal / 100).clamp(0.0, 1.0),
                  backgroundColor: Colors.red[100], color: Colors.green, minHeight: 12)),

              if (widget.user.isSuperviseurNational) ...[
                const Divider(height: 20),
                const Text('Par commune', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ..._statsByCommune.entries.map((e) {
                  final s = e.value;
                  final taux = s['taux'] as double;
                  return Padding(padding: const EdgeInsets.only(bottom: 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Text('${taux.toStringAsFixed(1)}%',
                            style: TextStyle(fontWeight: FontWeight.bold,
                                color: taux >= 70 ? Colors.green : Colors.orange)),
                      ]),
                      const SizedBox(height: 3),
                      ClipRRect(borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: (taux / 100).clamp(0.0, 1.0),
                          backgroundColor: Colors.grey[200],
                          color: taux >= 70 ? Colors.green : Colors.orange,
                          minHeight: 10)),
                      const SizedBox(height: 2),
                      Text('${s['retraits']}/${s['inscrits']} — ${s['saisis']}/${s['bureaux']} bureaux',
                          style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ]));
                }),
              ],
            ])));
      ]),
    );
  }

  // ────────────────────────────────────────────────────
  // ONGLET BUREAUX
  // ────────────────────────────────────────────────────
  Widget _bureauTab() {
    final bureaux = List<Bureau>.from(_bureausFiltres);
    final rm = _retraitMap;
    // Tri: non saisis en premier (plus urgent), puis par taux croissant
    bureaux.sort((a, b) {
      final ra = rm[a.id];
      final rb = rm[b.id];
      if (ra == null && rb != null) return -1;
      if (ra != null && rb == null) return 1;
      if (ra != null && rb != null) {
        final ta = ra.nbRetraits / (a.inscrits > 0 ? a.inscrits : 1);
        final tb = rb.nbRetraits / (b.inscrits > 0 ? b.inscrits : 1);
        return ta.compareTo(tb); // Taux faible en premier
      }
      return a.id.compareTo(b.id);
    });

    return Column(children: [
      Padding(padding: const EdgeInsets.all(8), child: Row(children: [
        Expanded(child: TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Rechercher...',
            prefixIcon: const Icon(Icons.search, size: 18),
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(vertical: 8)),
        )),
        const SizedBox(width: 8),
        if (widget.user.isSuperviseurNational)
          DropdownButton<String>(
            value: _filterCommune, isDense: true,
            items: ['Toutes','RAS DIKA','BOULAOS','BALBALA'].map((c) =>
                DropdownMenuItem(value: c, child: Text(c,
                    style: const TextStyle(fontSize: 12)))).toList(),
            onChanged: (v) => setState(() => _filterCommune = v!)),
      ])),

      // Légende statuts
      Container(color: Colors.grey[100], padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(children: [
          _legendItem(Colors.red[400]!, 'Non saisi'),
          const SizedBox(width: 12),
          _legendItem(Colors.orange, 'Faible (<70%)'),
          const SizedBox(width: 12),
          _legendItem(Colors.green, 'Bon (≥70%)'),
          const Spacer(),
          Text('${bureaux.length} bureaux',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ])),

      Expanded(child: RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          padding: const EdgeInsets.all(6),
          itemCount: bureaux.length,
          itemBuilder: (ctx, i) {
            final b = bureaux[i];
            final r = rm[b.id];
            final taux = r != null && b.inscrits > 0 ? r.nbRetraits / b.inscrits * 100 : 0.0;
            final Color barColor = r == null ? Colors.red[400]!
                : taux >= 70 ? Colors.green : Colors.orange;

            return Card(
              margin: const EdgeInsets.only(bottom: 5),
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(children: [
                  Container(width: 4, height: 54, decoration: BoxDecoration(
                      color: barColor, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(b.id, style: const TextStyle(fontWeight: FontWeight.bold,
                          fontSize: 12, color: Color(0xFF1B5E20))),
                      const SizedBox(width: 6),
                      if (r?.valide == true) const Icon(Icons.verified, color: Colors.green, size: 12)
                      else if (r != null) Icon(Icons.hourglass_empty, color: Colors.orange[400], size: 12),
                      if (r?.dateSaisie != null) ...[
                        const SizedBox(width: 4),
                        Text(_fmt(r!.dateSaisie!), style: TextStyle(fontSize: 9, color: Colors.grey[400])),
                      ],
                    ]),
                    Text(b.nom, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    if (r != null) ...[
                      ClipRRect(borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: (taux / 100).clamp(0.0, 1.0),
                          backgroundColor: Colors.grey[200], color: barColor, minHeight: 5)),
                      const SizedBox(height: 2),
                      Text('${r.nbRetraits} / ${b.inscrits} inscrits',
                          style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ] else
                      Text('⚠ Aucune saisie',
                          style: TextStyle(fontSize: 10, color: Colors.red[400],
                              fontWeight: FontWeight.bold)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    if (r != null)
                      Text('${taux.toStringAsFixed(1)}%',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13,
                              color: barColor)),
                    if (r != null && !r.valide && widget.user.isSuperviseurNational)
                      TextButton(
                        style: TextButton.styleFrom(
                            padding: EdgeInsets.zero, minimumSize: Size.zero),
                        child: const Text('✓', style: TextStyle(fontSize: 12, color: Colors.green)),
                        onPressed: () async {
                          await _svc.validerRetraitCartes(r.id);
                          _load();
                        }),
                  ]),
                ])));
          }))),
    ]);
  }

  // ── Helpers ──────────────────────────────────────────
  int _getJourRet(DateTime jour, Map<String, Map<String, int>> stats) {
    final ds = _dateStr(jour);
    final fromStats = stats[ds]?['retraits'] ?? 0;
    if (fromStats > 0) return fromStats;
    return _retraits.where((r) {
      final d = r.dateSaisie;
      return d != null && _dateStr(d) == ds;
    }).fold(0, (s, r) => s + r.nbRetraits);
  }

  Widget _legendItem(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: c,
        borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 10)),
  ]);

  Widget _kpiTop(String l, String v, Color c) => Expanded(child: Column(children: [
    Text(v, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 13)),
    Text(l, style: const TextStyle(color: Colors.white54, fontSize: 9)),
  ]));

  Widget _vDiv() => Container(width: 1, height: 30, color: Colors.white24,
      margin: const EdgeInsets.symmetric(horizontal: 2));

  Widget _miniStat(String l, String v, Color c) => Expanded(child: Column(children: [
    Text(v, style: TextStyle(fontWeight: FontWeight.bold, color: c, fontSize: 16)),
    Text(l, style: const TextStyle(fontSize: 9, color: Colors.grey)),
  ]));

  Widget _statL(String l, String v, Color c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      Expanded(child: Text(l, style: const TextStyle(fontSize: 13))),
      Text(v, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: c)),
    ]));

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
  String _fmtLong(DateTime d) {
    const j = ['Lun','Mar','Mer','Jeu','Ven','Sam','Dim'];
    const m = ['jan','fév','mar','avr','mai','jun','jul','août','sep','oct','nov','déc'];
    return '${j[d.weekday-1]} ${d.day} ${m[d.month-1]}';
  }
  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
}
