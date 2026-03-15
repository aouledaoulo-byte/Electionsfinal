import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/services.dart';

class CartesSuiviScreen extends StatefulWidget {
  final AppUser user;
  const CartesSuiviScreen({super.key, required this.user});
  @override
  State<CartesSuiviScreen> createState() => _CartesSuiviScreenState();
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
  static final DateTime _fin = DateTime(2026, 4, 10, 18);

  String _filterCommune = 'Toutes';
  DateTime _semaineSelect = DateTime.now();
  final _searchCtrl = TextEditingController();

  int get _joursRestants {
    final d = _fin.difference(DateTime.now()).inDays;
    return d < 0 ? 0 : d;
  }

  List<Bureau> get _bureausFiltres {
    final q = _searchCtrl.text.toLowerCase();
    return _bureaux.where((b) {
      final mc = _filterCommune == 'Toutes' || b.region == _filterCommune;
      final ms = q.isEmpty ||
          b.nom.toLowerCase().contains(q) ||
          b.id.toLowerCase().contains(q);
      return mc && ms;
    }).toList();
  }

  Map<String, RetraitCartes> get _retraitMap {
    final m = <String, RetraitCartes>{};
    for (var r in _retraits) {
      m[r.bureauId] = r;
    }
    return m;
  }

  List<RetraitCartes> get _retraitsFiltres {
    final ids = _bureausFiltres.map((b) => b.id).toSet();
    return _retraits.where((r) => ids.contains(r.bureauId)).toList();
  }

  int get _totalInscrits => _bureausFiltres.fold(0, (s, b) => s + b.inscrits);
  int get _totalRetraits => _retraitsFiltres.fold(0, (s, r) => s + r.nbRetraits);
  int get _totalNonRetraits => _retraitsFiltres.fold(0, (s, r) => s + r.nbNonRetraits);
  double get _tauxGlobal =>
      _totalInscrits > 0 ? _totalRetraits / _totalInscrits * 100 : 0;
  int get _nbSaisis => _retraitsFiltres.length;
  int get _nbValides => _retraitsFiltres.where((r) => r.valide).length;
  double get _couverture =>
      _bureaux.isEmpty ? 0 : _nbSaisis / _bureaux.length * 100;

  List<Bureau> get _bureausSansSignalement {
    final today = DateTime.now();
    final saisisAuj = _retraits.where((r) {
      final ds = r.dateSaisie ?? r.updatedAt;
      return ds.year == today.year &&
          ds.month == today.month &&
          ds.day == today.day;
    }).map((r) => r.bureauId).toSet();
    return _bureausFiltres.where((b) => !saisisAuj.contains(b.id)).toList();
  }

  Map<String, Map<String, dynamic>> get _statsByCommune {
    final map = <String, Map<String, dynamic>>{};
    for (var commune in ['RAS DIKA', 'BOULAOS', 'BALBALA']) {
      final bC = _bureaux.where((b) => b.region == commune).toList();
      final rC = _retraits
          .where((r) => bC.any((b) => b.id == r.bureauId))
          .toList();
      final ins = bC.fold(0, (s, b) => s + b.inscrits);
      final ret = rC.fold(0, (s, r) => s + r.nbRetraits);
      map[commune] = {
        'bureaux': bC.length,
        'saisis': rC.length,
        'inscrits': ins,
        'retraits': ret,
        'taux': ins > 0 ? ret / ins * 100 : 0.0,
      };
    }
    return map;
  }

  // Stats journalières depuis horaires
  Map<String, int> _statsRetParDate() {
    final maxParBureau = <String, RetraitCartesHoraire>{};
    for (var h in _horaires) {
      if (widget.user.isSuperviseurRegional) {
        Bureau? b;
        try {
          b = _bureaux.firstWhere((x) => x.id == h.bureauId);
        } catch (_) {}
        if (b == null || b.region != widget.user.region) continue;
      }
      final ds = _dateStr(h.dateSaisie);
      final key = h.bureauId + '_' + ds;
      if (!maxParBureau.containsKey(key) ||
          h.heure > maxParBureau[key]!.heure) {
        maxParBureau[key] = h;
      }
    }
    final result = <String, int>{};
    for (var h in maxParBureau.values) {
      final ds = _dateStr(h.dateSaisie);
      result[ds] = (result[ds] ?? 0) + h.nbRetraits;
    }
    return result;
  }

  Map<String, int> _statsBurParDate() {
    final maxParBureau = <String, RetraitCartesHoraire>{};
    for (var h in _horaires) {
      final ds = _dateStr(h.dateSaisie);
      final key = h.bureauId + '_' + ds;
      if (!maxParBureau.containsKey(key) ||
          h.heure > maxParBureau[key]!.heure) {
        maxParBureau[key] = h;
      }
    }
    final result = <String, int>{};
    for (var h in maxParBureau.values) {
      final ds = _dateStr(h.dateSaisie);
      result[ds] = (result[ds] ?? 0) + 1;
    }
    return result;
  }

  int _getJourRet(DateTime jour, Map<String, int> stats) {
    final ds = _dateStr(jour);
    final fromStats = stats[ds] ?? 0;
    if (fromStats > 0) return fromStats;
    return _retraits.where((r) {
      final d = r.dateSaisie;
      return d != null && _dateStr(d) == ds;
    }).fold(0, (s, r) => s + r.nbRetraits);
  }

  // Semaines
  DateTime get _lundiSemaine {
    var l = _semaineSelect
        .subtract(Duration(days: _semaineSelect.weekday - 1));
    if (l.isBefore(_debut)) l = _debut;
    if (l.isAfter(_fin)) l = _fin.subtract(const Duration(days: 6));
    return l;
  }

  List<DateTime> get _joursSemaine {
    final list = <DateTime>[];
    for (int i = 0; i < 7; i++) {
      final d = _lundiSemaine.add(Duration(days: i));
      if (!d.isAfter(_fin) && !d.isBefore(_debut)) list.add(d);
    }
    return list;
  }

  List<DateTime> get _semaines {
    final weeks = <DateTime>[];
    var d = _debut;
    while (d.weekday != 1) {
      d = d.subtract(const Duration(days: 1));
    }
    while (!d.isAfter(_fin)) {
      weeks.add(d);
      d = d.add(const Duration(days: 7));
    }
    return weeks;
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    if (widget.user.isSuperviseurRegional) {
      _filterCommune = widget.user.region!;
    }
    final now = DateTime.now();
    _semaineSelect =
        (now.isAfter(_debut) && now.isBefore(_fin)) ? now : _debut;
    _load();
    _timer = Timer.periodic(
        const Duration(seconds: 10), (_) => _loadSilent());
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

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
    final region =
        widget.user.isSuperviseurRegional ? widget.user.region : null;
    _bureaux = await _svc.getBureaux(region: region);
    _retraits = await _svc.getAllRetraitCartes(region: region);
    try {
      _horaires = await _svc.getAllRetraitsHoraires(region: region);
    } catch (_) {
      _horaires = [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final urgent = _joursRestants <= 7;
    return Column(children: [
      _buildHeader(urgent),
      TabBar(
        controller: _tabs,
        labelColor: const Color(0xFF1B5E20),
        indicatorColor: const Color(0xFF1B5E20),
        tabs: [
          const Tab(icon: Icon(Icons.today, size: 16), text: 'Jour'),
          const Tab(icon: Icon(Icons.date_range, size: 16), text: 'Semaine'),
          Tab(
            icon: Stack(children: [
              const Icon(Icons.list, size: 20),
              if (_bureausSansSignalement.isNotEmpty)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                  ),
                ),
            ]),
            text: 'Bureaux',
          ),
        ],
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabs,
                children: [_jourTab(), _semaineTab(), _bureauTab()],
              ),
      ),
    ]);
  }

  Widget _buildHeader(bool urgent) {
    return Container(
      color: const Color(0xFF1B5E20),
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.credit_card, color: Colors.white70, size: 16),
          const SizedBox(width: 6),
          const Expanded(
            child: Text('Suivi retraits cartes',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.circle, color: Colors.greenAccent, size: 8),
              SizedBox(width: 4),
              Text('Live 10s',
                  style: TextStyle(color: Colors.white, fontSize: 9)),
            ]),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: urgent
                    ? Colors.red.withOpacity(0.4)
                    : Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                  urgent
                      ? Icons.warning_amber
                      : Icons.calendar_today,
                  color: Colors.white,
                  size: 12),
              const SizedBox(width: 4),
              Text('$_joursRestants j.',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11)),
            ]),
          ),
          const SizedBox(width: 8),
          GestureDetector(
              onTap: _load,
              child: const Icon(Icons.refresh,
                  color: Colors.white, size: 18)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _kpiTop(
              'Taux',
              '${_tauxGlobal.toStringAsFixed(1)}%',
              _tauxGlobal >= 70
                  ? Colors.greenAccent
                  : Colors.orange),
          _vDiv(),
          _kpiTop('Retirées', _totalRetraits.toString(), Colors.white),
          _vDiv(),
          _kpiTop('Restantes', _totalNonRetraits.toString(),
              Colors.redAccent),
          _vDiv(),
          _kpiTop(
              'Couv.',
              '${_couverture.toStringAsFixed(0)}%',
              _couverture >= 80
                  ? Colors.greenAccent
                  : Colors.white70),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (_tauxGlobal / 100).clamp(0.0, 1.0),
            backgroundColor: Colors.red.withOpacity(0.3),
            color: _tauxGlobal >= 70
                ? Colors.greenAccent
                : Colors.orange,
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 3),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('$_totalRetraits / $_totalInscrits inscrits',
              style:
                  const TextStyle(color: Colors.white70, fontSize: 10)),
          Text('$_nbSaisis/${_bureaux.length} bureaux · $_nbValides validés',
              style:
                  const TextStyle(color: Colors.white60, fontSize: 10)),
        ]),
      ]),
    );
  }

  Widget _jourTab() {
    final statsRet = _statsRetParDate();
    final statsBur = _statsBurParDate();
    final today = DateTime.now();
    final todayStr = _dateStr(today);
    final todayR = _retraitsFiltres.where((r) {
      final ds = r.dateSaisie ?? r.updatedAt;
      return ds.year == today.year &&
          ds.month == today.month &&
          ds.day == today.day;
    }).toList();
    final retAuj = todayR.fold(0, (s, r) => s + r.nbRetraits);
    final nonAuj = todayR.fold(0, (s, r) => s + r.nbNonRetraits);
    int insAuj = 0;
    for (var r in todayR) {
      Bureau? b;
      try {
        b = _bureaux.firstWhere((x) => x.id == r.bureauId);
      } catch (_) {}
      if (b != null) insAuj += b.inscrits;
    }
    final tauxAuj = insAuj > 0 ? retAuj / insAuj * 100 : 0.0;

    final jours = <DateTime>[];
    var d = _debut;
    while (!d.isAfter(today) && !d.isAfter(_fin)) {
      jours.add(d);
      d = d.add(const Duration(days: 1));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(12), children: [
        _cardAujourd(retAuj, nonAuj, tauxAuj, todayR.length, today),
        const SizedBox(height: 8),
        if (_bureausSansSignalement.isNotEmpty) ...[
          _cardAlertes(),
          const SizedBox(height: 8),
        ],
        if (widget.user.isSuperviseurNational) ...[
          _cardValidation(),
          const SizedBox(height: 8),
          if (todayR.isNotEmpty) _cardCommunes(todayR),
          const SizedBox(height: 8),
        ],
        Text('Historique depuis le ${_fmt(_debut)}',
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        ...jours.reversed.map((j) {
          final ret = _getJourRet(j, statsRet);
          final bur = statsBur[_dateStr(j)] ?? 0;
          final isToday = _dateStr(j) == todayStr;
          final taux = _totalInscrits > 0
              ? ret / _totalInscrits * 100
              : 0.0;
          return _cardJour(j, ret, bur, isToday, taux);
        }),
      ]),
    );
  }

  Widget _cardAujourd(int ret, int nonRet, double taux, int nbBur,
      DateTime today) {
    return Card(
      color: Colors.blue[50],
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          Row(children: [
            const Icon(Icons.today, color: Colors.blue, size: 18),
            const SizedBox(width: 8),
            Text("Aujourd'hui — ${_fmtLong(today)}",
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(),
            Text('$nbBur bur.',
                style: const TextStyle(
                    color: Colors.grey, fontSize: 11)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _miniStat('Retirées', ret.toString(), Colors.green),
            _miniStat(
                'Non ret.', nonRet.toString(), Colors.red),
            _miniStat(
                'Taux',
                '${taux.toStringAsFixed(1)}%',
                taux >= 70 ? Colors.green : Colors.orange),
            _miniStat('Bureaux', nbBur.toString(), Colors.blue),
          ]),
          if (nbBur > 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: (taux / 100).clamp(0.0, 1.0),
                backgroundColor: Colors.grey[200],
                color: taux >= 70 ? Colors.green : Colors.orange,
                minHeight: 10,
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _cardAlertes() {
    final manquants = _bureausSansSignalement;
    return Card(
      color: Colors.orange[50],
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.warning_amber,
                  color: Colors.orange, size: 16),
              const SizedBox(width: 8),
              Text(
                '${manquants.length} bureau(x) sans saisie aujourd\'hui',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange),
              ),
            ]),
            const SizedBox(height: 6),
            ...manquants.take(5).map((b) => Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Row(children: [
                    Text(b.id,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(b.nom,
                            style: const TextStyle(fontSize: 11),
                            overflow: TextOverflow.ellipsis)),
                  ]),
                )),
            if (manquants.length > 5)
              Text('+ ${manquants.length - 5} autres...',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.orange[600])),
          ],
        ),
      ),
    );
  }

  Widget _cardValidation() {
    final enAttente =
        _retraits.where((r) => !r.valide).toList();
    if (enAttente.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(10)),
        child: const Row(children: [
          Icon(Icons.verified, color: Colors.green, size: 16),
          SizedBox(width: 8),
          Text('Toutes les saisies sont validées ✓',
              style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold)),
        ]),
      );
    }
    return Card(
      color: Colors.orange[50],
      child: ListTile(
        leading: const Icon(Icons.hourglass_empty,
            color: Colors.orange, size: 18),
        title: Text('${enAttente.length} saisies en attente',
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orange,
                fontSize: 13)),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8)),
          child: const Text('Valider tout',
              style: TextStyle(fontSize: 12)),
          onPressed: () async {
            for (var r in enAttente) {
              await _svc.validerRetraitCartes(r.id);
            }
            await _load();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('${enAttente.length} validés ✓'),
                  backgroundColor: Colors.green));
            }
          },
        ),
      ),
    );
  }

  Widget _cardCommunes(List<RetraitCartes> todayR) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Par commune',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        ..._statsByCommune.entries.map((e) {
          final rC = todayR.where((r) {
            Bureau? b;
            try {
              b = _bureaux.firstWhere((x) => x.id == r.bureauId);
            } catch (_) {}
            return b?.region == e.key;
          }).toList();
          final ret =
              rC.fold(0, (s, r) => s + r.nbRetraits);
          final ins = e.value['inscrits'] as int;
          final taux =
              ins > 0 ? ret / ins * 100 : 0.0;
          return Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              leading: CircleAvatar(
                backgroundColor:
                    const Color(0xFF1B5E20).withOpacity(0.1),
                child: const Icon(Icons.location_on,
                    color: Color(0xFF1B5E20), size: 16),
              ),
              title: Text(e.key,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$ret retirées | ${rC.length} bureaux'),
                    LinearProgressIndicator(
                      value: (taux / 100).clamp(0.0, 1.0),
                      backgroundColor: Colors.grey[200],
                      color: taux >= 70
                          ? Colors.green
                          : Colors.orange,
                      minHeight: 4,
                    ),
                  ]),
              trailing: Text('${taux.toStringAsFixed(1)}%',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: taux >= 70
                          ? Colors.green
                          : Colors.orange)),
            ),
          );
        }),
      ],
    );
  }

  Widget _cardJour(
      DateTime j, int ret, int bur, bool isToday, double taux) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      color: isToday ? Colors.blue[50] : null,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(children: [
          Row(children: [
            Icon(
                isToday ? Icons.today : Icons.calendar_today,
                color: isToday ? Colors.blue : Colors.grey[400],
                size: 14),
            const SizedBox(width: 6),
            Text(_fmtLong(j),
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isToday
                        ? Colors.blue[800]
                        : Colors.black87)),
            if (isToday) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(4)),
                child: const Text('Auj.',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold)),
              ),
            ],
            const Spacer(),
            Text(
                ret > 0
                    ? '$bur bur.'
                    : 'Aucune saisie',
                style: TextStyle(
                    fontSize: 10, color: Colors.grey[400])),
          ]),
          if (ret > 0) ...[
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (taux / 100).clamp(0.0, 1.0),
                backgroundColor: Colors.grey[200],
                color: taux >= 70 ? Colors.green : Colors.orange,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 3),
            Row(children: [
              Text('$ret retirées',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700])),
              const Spacer(),
              Text('${taux.toStringAsFixed(1)}%',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: taux >= 70
                          ? Colors.green
                          : Colors.orange)),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _semaineTab() {
    final statsRet = _statsRetParDate();
    final statsBur = _statsBurParDate();
    final semaines = _semaines;

    int retSemaine = 0;
    for (var j in _joursSemaine) {
      retSemaine += _getJourRet(j, statsRet);
    }

    int maxJour = 1;
    for (var j in statsRet.values) {
      if (j > maxJour) maxJour = j;
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(12), children: [
        _buildSemainePicker(semaines, statsRet),
        const SizedBox(height: 10),
        _buildGraphiqueSemaine(statsRet, statsBur, retSemaine, maxJour),
        const SizedBox(height: 10),
        _buildSyntheseGlobale(),
      ]),
    );
  }

  Widget _buildSemainePicker(
      List<DateTime> semaines, Map<String, int> statsRet) {
    final items = <Widget>[];
    for (int idx = 0; idx < semaines.length; idx++) {
      final sem = semaines[idx];
      final fin = sem.add(const Duration(days: 6));
      final isSel = !_lundiSemaine.isBefore(sem) &&
          _lundiSemaine.isBefore(fin.add(const Duration(days: 1)));
      int retW = 0;
      for (int j = 0; j < 7; j++) {
        retW += _getJourRet(sem.add(Duration(days: j)), statsRet);
      }
      items.add(GestureDetector(
        onTap: () => setState(() => _semaineSelect = sem),
        child: Container(
          margin: const EdgeInsets.only(right: 6),
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSel
                ? const Color(0xFF1B5E20)
                : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(children: [
            Text('S${idx + 1}',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isSel ? Colors.white : Colors.black87)),
            Text('${sem.day}/${sem.month}',
                style: TextStyle(
                    fontSize: 9,
                    color: isSel
                        ? Colors.white70
                        : Colors.grey)),
            if (retW > 0)
              Text('$retW',
                  style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: isSel
                          ? Colors.greenAccent
                          : Colors.green[600])),
          ]),
        ),
      ));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.calendar_view_week,
                  color: Color(0xFF1B5E20), size: 18),
              SizedBox(width: 8),
              Text('Sélectionner une semaine',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: items),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraphiqueSemaine(Map<String, int> statsRet,
      Map<String, int> statsBur, int retSemaine, int maxJour) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(
                  '${_fmt(_joursSemaine.first)} → ${_fmt(_joursSemaine.last)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              Text('$retSemaine retraits',
                  style: TextStyle(
                      color: Colors.green[700],
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 12),
            ..._joursSemaine.map((jour) {
              final ret = _getJourRet(jour, statsRet);
              final bur = statsBur[_dateStr(jour)] ?? 0;
              final isFuture = jour.isAfter(DateTime.now());
              final isToday =
                  _dateStr(jour) == _dateStr(DateTime.now());
              final ratio =
                  maxJour > 0 && ret > 0 ? ret / maxJour : 0.0;
              final taux = _totalInscrits > 0
                  ? ret / _totalInscrits * 100
                  : 0.0;
              const jourNoms = [
                'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'
              ];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  SizedBox(
                    width: 34,
                    child: Text(jourNoms[jour.weekday - 1],
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isToday
                                ? const Color(0xFF1B5E20)
                                : Colors.grey[600])),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                        '${jour.day}/${jour.month}',
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[400])),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: Stack(children: [
                        Container(
                            height: 30,
                            color: isFuture
                                ? Colors.grey[50]
                                : Colors.grey[100]),
                        if (!isFuture && ret > 0)
                          FractionallySizedBox(
                            widthFactor: ratio.clamp(0.0, 1.0),
                            child: Container(
                                height: 30,
                                color: isToday
                                    ? const Color(0xFF1B5E20)
                                    : Colors.green[300]),
                          ),
                        if (!isFuture && ret > 0)
                          Positioned.fill(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('$ret retraits',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight:
                                              FontWeight.bold,
                                          fontSize: 11)),
                                  Text('$bur bur.',
                                      style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 10)),
                                ],
                              ),
                            ),
                          ),
                        if (isFuture)
                          Positioned.fill(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text('À venir',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[400])),
                              ),
                            ),
                          ),
                      ]),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                        ret > 0
                            ? '${taux.toStringAsFixed(0)}%'
                            : '',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                ]),
              );
            }),
            const Divider(),
            Row(children: [
              const Text('Total semaine',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('$retSemaine retraits',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: retSemaine > 0
                          ? Colors.green
                          : Colors.grey)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSyntheseGlobale() {
    return Card(
      color: Colors.green[50],
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.summarize,
                  color: Color(0xFF1B5E20), size: 18),
              const SizedBox(width: 8),
              Text('Cumul ${_fmt(_debut)} → ${_fmt(_fin)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
            ]),
            const SizedBox(height: 10),
            _statL('Total inscrits', '$_totalInscrits',
                Colors.indigo),
            _statL('Cartes retirées', '$_totalRetraits',
                Colors.green),
            _statL('Non retirées', '$_totalNonRetraits',
                Colors.red),
            _statL(
                'Taux de retrait',
                '${_tauxGlobal.toStringAsFixed(2)}%',
                _tauxGlobal >= 70 ? Colors.green : Colors.orange),
            _statL('Bureaux saisis',
                '$_nbSaisis / ${_bureaux.length}', Colors.blue),
            _statL('Bureaux validés ✓',
                '$_nbValides / ${_bureaux.length}', Colors.green),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (_tauxGlobal / 100).clamp(0.0, 1.0),
                backgroundColor: Colors.red[100],
                color: Colors.green,
                minHeight: 12,
              ),
            ),
            if (widget.user.isSuperviseurNational) ...[
              const Divider(height: 20),
              const Text('Par commune',
                  style:
                      TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._statsByCommune.entries.map((e) {
                final s = e.value;
                final taux = s['taux'] as double;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(e.key,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Text('${taux.toStringAsFixed(1)}%',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: taux >= 70
                                    ? Colors.green
                                    : Colors.orange)),
                      ]),
                      const SizedBox(height: 3),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: (taux / 100).clamp(0.0, 1.0),
                          backgroundColor: Colors.grey[200],
                          color: taux >= 70
                              ? Colors.green
                              : Colors.orange,
                          minHeight: 10,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                          '${s['retraits']}/${s['inscrits']} — ${s['saisis']}/${s['bureaux']} bureaux',
                          style: const TextStyle(
                              fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bureauTab() {
    final bureaux = List<Bureau>.from(_bureausFiltres);
    final rm = _retraitMap;
    bureaux.sort((a, b) {
      final ra = rm[a.id];
      final rb = rm[b.id];
      if (ra == null && rb != null) return -1;
      if (ra != null && rb == null) return 1;
      if (ra != null && rb != null) {
        final ta =
            ra.nbRetraits / (a.inscrits > 0 ? a.inscrits : 1);
        final tb =
            rb.nbRetraits / (b.inscrits > 0 ? b.inscrits : 1);
        return ta.compareTo(tb);
      }
      return a.id.compareTo(b.id);
    });

    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(8),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Rechercher...',
                prefixIcon:
                    const Icon(Icons.search, size: 18),
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (widget.user.isSuperviseurNational)
            DropdownButton<String>(
              value: _filterCommune,
              isDense: true,
              items: ['Toutes', 'RAS DIKA', 'BOULAOS', 'BALBALA']
                  .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(c,
                          style: const TextStyle(
                              fontSize: 12))))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _filterCommune = v!),
            ),
        ]),
      ),
      Container(
        color: Colors.grey[100],
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 6),
        child: Row(children: [
          _legendItem(Colors.red[400]!, 'Non saisi'),
          const SizedBox(width: 12),
          _legendItem(Colors.orange, 'Faible (<70%)'),
          const SizedBox(width: 12),
          _legendItem(Colors.green, 'Bon (≥70%)'),
          const Spacer(),
          Text('${bureaux.length} bureaux',
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold)),
        ]),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView.builder(
            padding: const EdgeInsets.all(6),
            itemCount: bureaux.length,
            itemBuilder: (ctx, i) {
              final b = bureaux[i];
              final r = rm[b.id];
              final taux = r != null && b.inscrits > 0
                  ? r.nbRetraits / b.inscrits * 100
                  : 0.0;
              final Color barColor = r == null
                  ? Colors.red[400]!
                  : taux >= 70
                      ? Colors.green
                      : Colors.orange;
              return Card(
                margin: const EdgeInsets.only(bottom: 5),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  child: Row(children: [
                    Container(
                      width: 4,
                      height: 54,
                      decoration: BoxDecoration(
                          color: barColor,
                          borderRadius:
                              BorderRadius.circular(2)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text(b.id,
                                style: const TextStyle(
                                    fontWeight:
                                        FontWeight.bold,
                                    fontSize: 12,
                                    color: Color(0xFF1B5E20))),
                            const SizedBox(width: 6),
                            if (r?.valide == true)
                              const Icon(Icons.verified,
                                  color: Colors.green,
                                  size: 12)
                            else if (r != null)
                              Icon(Icons.hourglass_empty,
                                  color: Colors.orange[400],
                                  size: 12),
                            if (r?.dateSaisie != null) ...[
                              const SizedBox(width: 4),
                              Text(_fmt(r!.dateSaisie!),
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.grey[400])),
                            ],
                          ]),
                          Text(b.nom,
                              style: const TextStyle(
                                  fontSize: 11),
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          if (r != null) ...[
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value:
                                    (taux / 100).clamp(0.0, 1.0),
                                backgroundColor:
                                    Colors.grey[200],
                                color: barColor,
                                minHeight: 5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                                '${r.nbRetraits} / ${b.inscrits} inscrits',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey)),
                          ] else
                            Text('⚠ Aucune saisie',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.red[400],
                                    fontWeight:
                                        FontWeight.bold)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.end,
                      children: [
                        if (r != null)
                          Text(
                              '${taux.toStringAsFixed(1)}%',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: barColor)),
                        if (r != null &&
                            !r.valide &&
                            widget.user.isSuperviseurNational)
                          TextButton(
                            style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero),
                            child: const Text('✓',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green)),
                            onPressed: () async {
                              await _svc
                                  .validerRetraitCartes(r.id);
                              _load();
                            },
                          ),
                      ],
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
      ),
    ]);
  }

  Widget _legendItem(Color c, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
              color: c, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 10)),
    ]);
  }

  Widget _kpiTop(String l, String v, Color c) {
    return Expanded(
      child: Column(children: [
        Text(v,
            style: TextStyle(
                color: c,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
        Text(l,
            style: const TextStyle(
                color: Colors.white54, fontSize: 9)),
      ]),
    );
  }

  Widget _vDiv() {
    return Container(
        width: 1,
        height: 30,
        color: Colors.white24,
        margin: const EdgeInsets.symmetric(horizontal: 2));
  }

  Widget _miniStat(String l, String v, Color c) {
    return Expanded(
      child: Column(children: [
        Text(v,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: c,
                fontSize: 16)),
        Text(l,
            style: const TextStyle(
                fontSize: 9, color: Colors.grey)),
      ]),
    );
  }

  Widget _statL(String l, String v, Color c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Expanded(child: Text(l, style: const TextStyle(fontSize: 13))),
        Text(v,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: c)),
      ]),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _fmtLong(DateTime d) {
    const j = [
      'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'
    ];
    const m = [
      'jan', 'fév', 'mar', 'avr', 'mai', 'jun',
      'jul', 'août', 'sep', 'oct', 'nov', 'déc'
    ];
    return '${j[d.weekday - 1]} ${d.day} ${m[d.month - 1]}';
  }

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
