import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/services.dart';
import '../../utils/constants.dart';

// ============================================================
//  DASHBOARD LIVE — Suivi participation horaire
// ============================================================
class DashboardLive extends StatefulWidget {
  const DashboardLive({super.key});
  @override
  State<DashboardLive> createState() => _DashboardLiveState();
}

class _DashboardLiveState extends State<DashboardLive> {
  final _data = DataService();
  List<Map<String, dynamic>> _coverage = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _loading = true);
    final c = await _data.getLiveCoverage();
    setState(() { _coverage = c; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _charger,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          // Graphique couverture par heure
          Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Couverture LIVE par heure',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              const Text('% bureaux ayant transmis un relevé',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 16),
              if (_coverage.isNotEmpty) SizedBox(
                height: 200,
                child: BarChart(BarChartData(
                  barGroups: _coverage.map((c) {
                    final h = (c['heure'] as num).toInt();
                    final pct = (c['pct_couverture'] as num?)?.toDouble() ?? 0;
                    return BarChartGroupData(x: h, barRods: [
                      BarChartRodData(
                        toY: pct,
                        color: pct >= 80 ? Colors.green
                            : pct >= 50 ? Colors.orange : Colors.red,
                        width: 18, borderRadius: BorderRadius.circular(4),
                      ),
                    ]);
                  }).toList(),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) => Text('${v.toInt()}h',
                          style: const TextStyle(fontSize: 9)),
                    )),
                    leftTitles: AxisTitles(sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) => Text('${v.toInt()}%',
                          style: const TextStyle(fontSize: 9)),
                      reservedSize: 32,
                    )),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  maxY: 100,
                  gridData: FlGridData(
                    getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade200),
                  ),
                  borderData: FlBorderData(show: false),
                )),
              ),
            ]),
          )),
          const SizedBox(height: 8),

          // Tableau détaillé
          Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Détail par heure',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 12),
              ..._coverage.map((c) {
                final h = (c['heure'] as num).toInt();
                final pct = (c['pct_couverture'] as num?)?.toDouble() ?? 0;
                final total = (c['total_bureaux'] as num?)?.toInt() ?? 0;
                final valides = (c['bureaux_valides'] as num?)?.toInt() ?? 0;
                final taux = (c['taux_participation'] as num?)?.toDouble() ?? 0;
                final color = pct >= 80 ? Colors.green : pct >= 50 ? Colors.orange : Colors.grey;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          shape: BoxShape.circle),
                      child: Center(child: Text('${h}h',
                          style: TextStyle(fontWeight: FontWeight.bold,
                              color: color, fontSize: 12))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct / 100, minHeight: 8,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text('$valides/$total bureaux · part. ${taux.toStringAsFixed(1)}%',
                          style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ])),
                    const SizedBox(width: 8),
                    Text('${pct.toStringAsFixed(0)}%',
                        style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                  ]),
                );
              }),
            ]),
          )),
        ]),
      ),
    );
  }
}

// ============================================================
//  VALIDATION SCREEN — Valider/Rejeter PV et relevés
// ============================================================
class ValidationScreen extends StatefulWidget {
  const ValidationScreen({super.key});
  @override
  State<ValidationScreen> createState() => _ValidationScreenState();
}

class _ValidationScreenState extends State<ValidationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _data = DataService();
  List<Map<String, dynamic>> _pvSoumis = [];
  List<TurnoutSnapshot> _snapsSoumis = [];
  List<Bureau> _bureaux = [];
  bool _loading = true;
  String _superviseurId = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _charger();
  }

  Future<void> _charger() async {
    _superviseurId = await AuthService().getUserId() ?? '';
    setState(() => _loading = true);

    final pvAll = await _data.getAllPv();
    final bAll  = await _data.getAllBureaux();

    // Filtrer PV soumis
    final pvSoumis = pvAll.where((p) => p.statut == PvStatut.soumis).toList();
    final bureauMap = {for (var b in bAll) b.id: b};

    setState(() {
      _pvSoumis = pvSoumis.map((p) => {
        'pv': p,
        'bureau': bureauMap[p.bureauId],
      }).toList();
      _bureaux = bAll;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              TabBar(
                controller: _tabs,
                tabs: [
                  Tab(text: 'PV (${_pvSoumis.length})'),
                  const Tab(text: 'Relevés LIVE'),
                ],
                labelColor: const Color(0xFF1B5E20),
                indicatorColor: const Color(0xFF1B5E20),
              ),
              Expanded(child: TabBarView(
                controller: _tabs,
                children: [_tabPv(), _tabSnapshots()],
              )),
            ]),
      floatingActionButton: FloatingActionButton(
        onPressed: _charger,
        backgroundColor: const Color(0xFF1B5E20),
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }

  Widget _tabPv() {
    if (_pvSoumis.isEmpty) {
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, size: 64, color: Colors.green),
          SizedBox(height: 12),
          Text('Tous les PV sont traités', style: TextStyle(color: Colors.grey)),
        ],
      ));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _pvSoumis.length,
      itemBuilder: (_, i) {
        final item = _pvSoumis[i];
        final pv = item['pv'] as PvResult;
        final b  = item['bureau'] as Bureau?;
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b?.nom ?? '—',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text('${b?.region ?? ''} · ${b?.commune ?? ''} · ${b?.centre ?? ''}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const Divider(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _pvStat('Votants', pv.votants),
                _pvStat('Nuls', pv.nuls),
                _pvStat('A', pv.voixA),
                _pvStat('B', pv.voixB),
              ]),
              // Vérification cohérence
              if (pv.votants != pv.nuls + pv.voixA + pv.voixB)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.warning, color: Colors.red, size: 16),
                    const SizedBox(width: 6),
                    Text('INCOHÉRENCE : ${pv.votants} ≠ ${pv.nuls}+${pv.voixA}+${pv.voixB}',
                        style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ]),
                ),
              if (pv.photoUrl != null) Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  const Icon(Icons.image, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  const Text('Photo PV disponible',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                ]),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => _rejeterPv(pv),
                  icon: const Icon(Icons.cancel, color: Colors.red),
                  label: const Text('Rejeter', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                )),
                const SizedBox(width: 8),
                Expanded(child: ElevatedButton.icon(
                  onPressed: () => _validerPv(pv.id!),
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Valider'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                )),
              ]),
            ]),
          ),
        );
      },
    );
  }

  Widget _pvStat(String label, int value) => Column(children: [
    Text(value.toString(),
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
    Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
  ]);

  Widget _tabSnapshots() {
    return const Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.access_time, size: 48, color: Colors.grey),
        SizedBox(height: 12),
        Text('Validation des relevés LIVE', style: TextStyle(color: Colors.grey)),
        SizedBox(height: 4),
        Text('Sélectionnez un bureau pour valider',
            style: TextStyle(color: Colors.grey, fontSize: 12)),
      ]),
    );
  }

  Future<void> _validerPv(String pvId) async {
    final ok = await _data.validerPv(pvId, _superviseurId);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PV validé ✓'), backgroundColor: Colors.green));
      _charger();
    }
  }

  Future<void> _rejeterPv(PvResult pv) async {
    String note = '';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rejeter le PV'),
        content: TextField(
          decoration: const InputDecoration(
              labelText: 'Motif du rejet', border: OutlineInputBorder()),
          onChanged: (v) => note = v,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );
    if (confirm == true && pv.id != null) {
      final ok = await _data.rejeterPv(pv.id!, note, _superviseurId);
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PV rejeté'), backgroundColor: Colors.red));
        _charger();
      }
    }
  }
}

// ============================================================
//  ANOMALIES SCREEN
// ============================================================
class AnomaliesScreen extends StatefulWidget {
  const AnomaliesScreen({super.key});
  @override
  State<AnomaliesScreen> createState() => _AnomaliesScreenState();
}

class _AnomaliesScreenState extends State<AnomaliesScreen> {
  final _data = DataService();
  List<Map<String, dynamic>> _anomalies = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _loading = true);
    final a = await _data.getAnomalies();
    setState(() { _anomalies = a; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_anomalies.isEmpty) {
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified_user, size: 64, color: Colors.green),
          SizedBox(height: 12),
          Text('Aucune anomalie détectée', style: TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ));
    }

    final critiques = _anomalies.where((a) => a['niveau_anomalie'] == 'CRITIQUE').toList();
    final warnings  = _anomalies.where((a) => a['niveau_anomalie'] == 'WARNING').toList();

    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (critiques.isNotEmpty) ...[
            _headerSection('🔴 CRITIQUE (${critiques.length})', Colors.red),
            ...critiques.map((a) => _anomalieCard(a, Colors.red)),
          ],
          if (warnings.isNotEmpty) ...[
            _headerSection('⚠️ WARNING (${warnings.length})', Colors.orange),
            ...warnings.map((a) => _anomalieCard(a, Colors.orange)),
          ],
        ],
      ),
    );
  }

  Widget _headerSection(String title, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15)),
  );

  Widget _anomalieCard(Map<String, dynamic> a, Color color) {
    final List<String> details = [];
    if (a['anomalie_votants_sup_inscrits'] == true)
      details.add('Votants (${a['votants']}) > Inscrits corrigés (${a['inscrits_corriges']})');
    if (a['anomalie_total_incorrect'] == true)
      details.add('Total : ${a['votants']} ≠ ${a['nuls']} nuls + ${a['exprimes']} exprimés');
    if (a['anomalie_nuls_eleves'] == true)
      details.add('Bulletins nuls élevés : ${a['nuls']} / ${a['votants']}');
    if (a['anomalie_zero_exprimes'] == true)
      details.add('Aucun exprimé alors que ${a['votants']} votants');
    if (a['anomalie_photo_manquante'] == true)
      details.add('Photo du PV manquante');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
          side: BorderSide(color: color.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(color == Colors.red ? Icons.error : Icons.warning,
                color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(a['nom'] ?? '—',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
          ]),
          Text('${a['region']} · ${a['commune']} · ${a['centre']}',
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const Divider(height: 12),
          ...details.map((d) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              Icon(Icons.arrow_right, color: color, size: 16),
              const SizedBox(width: 4),
              Expanded(child: Text(d, style: TextStyle(fontSize: 12, color: color))),
            ]),
          )),
        ]),
      ),
    );
  }
}
