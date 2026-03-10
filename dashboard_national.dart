import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/services.dart';

class DashboardNational extends StatefulWidget {
  const DashboardNational({super.key});
  @override
  State<DashboardNational> createState() => _DashboardNationalState();
}

class _DashboardNationalState extends State<DashboardNational> {
  final _data = DataService();
  Map<String, dynamic>? _kpi;
  List<Map<String, dynamic>> _regions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _loading = true);
    final kpi = await _data.getKpiNational();
    final reg = await _data.getKpiByRegion();
    setState(() { _kpi = kpi; _regions = reg; _loading = false; });
  }

  double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
  int _i(dynamic v) => (v as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_kpi == null) return const Center(child: Text('Données indisponibles'));

    final pctA = _d(_kpi!['pct_candidat_a']);
    final pctB = _d(_kpi!['pct_candidat_b']);
    final taux = _d(_kpi!['taux_participation_corriges']);
    final couv = _d(_kpi!['pct_couverture_pv']);

    return RefreshIndicator(
      onRefresh: _charger,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          // ── KPI NATIONAUX ──
          _sectionTitre('📊 KPI National'),
          _gridKpi([
            _kpiCard('Inscrits', _fmtN(_kpi!['total_inscrits']), Icons.people, Colors.blue),
            _kpiCard('Corrigés', _fmtN(_kpi!['total_inscrits_corriges']), Icons.people_alt, Colors.teal),
            _kpiCard('Votants', _fmtN(_kpi!['total_votants']), Icons.how_to_vote, Colors.green),
            _kpiCard('Abstention', '${(100-taux).toStringAsFixed(1)}%', Icons.person_off, Colors.orange),
          ]),
          const SizedBox(height: 8),

          // ── PARTICIPATION ──
          Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Participation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 12),
              _barreParticipation('Sur inscrits', _d(_kpi!['taux_participation_inscrits']), Colors.blue),
              const SizedBox(height: 8),
              _barreParticipation('Sur corrigés', taux, const Color(0xFF1B5E20)),
            ]),
          )),
          const SizedBox(height: 8),

          // ── RÉSULTATS CANDIDATS ──
          Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Résultats — Candidats', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _candidatCard('A', _fmtN(_kpi!['total_voix_a']), pctA, Colors.blue)),
                const SizedBox(width: 10),
                Expanded(child: _candidatCard('B', _fmtN(_kpi!['total_voix_b']), pctB, Colors.red)),
              ]),
              const SizedBox(height: 16),
              // Camembert
              if (pctA > 0 || pctB > 0) SizedBox(
                height: 180,
                child: PieChart(PieChartData(
                  sections: [
                    PieChartSectionData(value: pctA, color: Colors.blue, title: '${pctA.toStringAsFixed(1)}%',
                        radius: 70, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    PieChartSectionData(value: pctB, color: Colors.red, title: '${pctB.toStringAsFixed(1)}%',
                        radius: 70, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                  centerSpaceRadius: 30,
                )),
              ),
            ]),
          )),
          const SizedBox(height: 8),

          // ── COUVERTURE PV ──
          Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Couverture PV', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _statCircle(_i(_kpi!['pv_valides']).toString(), 'Validés', Colors.green),
                _statCircle(_i(_kpi!['pv_soumis']).toString(), 'En attente', Colors.orange),
                _statCircle(_i(_kpi!['pv_rejetes']).toString(), 'Rejetés', Colors.red),
                _statCircle(_i(_kpi!['pv_manquants']).toString(), 'Manquants', Colors.grey),
              ]),
              const SizedBox(height: 12),
              _barreParticipation('Couverture totale', couv, Colors.green),
            ]),
          )),
          const SizedBox(height: 8),

          // ── PAR RÉGION ──
          _sectionTitre('🗺️ Par région'),
          ..._regions.map((r) => _regionCard(r)),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _sectionTitre(String t) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
  );

  Widget _gridKpi(List<Widget> w) => GridView.count(
    crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
    childAspectRatio: 1.8, mainAxisSpacing: 8, crossAxisSpacing: 8,
    children: w,
  );

  Widget _kpiCard(String label, String value, IconData icon, Color color) => Card(
    color: color.withOpacity(0.08),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: color)),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ])),
      ]),
    ),
  );

  Widget _barreParticipation(String label, double pct, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        Text('${pct.toStringAsFixed(1)}%',
            style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: pct / 100,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation(color),
          minHeight: 10,
        ),
      ),
    ]);
  }

  Widget _candidatCard(String cand, String voix, double pct, Color color) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3))),
    child: Column(children: [
      CircleAvatar(backgroundColor: color, child: Text(cand,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
      const SizedBox(height: 8),
      Text('Candidat $cand', style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      Text(voix, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      Text('${pct.toStringAsFixed(1)}%',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
    ]),
  );

  Widget _statCircle(String value, String label, Color color) => Column(children: [
    CircleAvatar(backgroundColor: color.withOpacity(0.15),
        child: Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color))),
    const SizedBox(height: 4),
    Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
  ]);

  Widget _regionCard(Map<String, dynamic> r) {
    final pctA = _d(r['pct_a']);
    final pctB = _d(r['pct_b']);
    final taux = _d(r['taux_participation']);
    final couv = _d(r['pct_couverture']);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(r['region'] ?? '—',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text('${taux.toStringAsFixed(1)}% participation',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _miniBar('A', pctA, Colors.blue)),
            const SizedBox(width: 8),
            Expanded(child: _miniBar('B', pctB, Colors.red)),
          ]),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${_i(r['pv_valides'])}/${_i(r['total_bureaux'])} PV',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            Text('Couverture : ${couv.toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
        ]),
      ),
    );
  }

  Widget _miniBar(String cand, double pct, Color color) {
    return Row(children: [
      CircleAvatar(radius: 10, backgroundColor: color,
          child: Text(cand, style: const TextStyle(color: Colors.white, fontSize: 10))),
      const SizedBox(width: 6),
      Expanded(child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: pct / 100, minHeight: 8,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation(color),
        ),
      )),
      const SizedBox(width: 6),
      Text('${pct.toStringAsFixed(1)}%',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
    ]);
  }

  String _fmtN(dynamic v) {
    final n = (v as num?)?.toInt() ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }
}
