import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../utils/constants.dart';

class AgentsScreen extends StatefulWidget {
  final AppUser user;
  const AgentsScreen({super.key, required this.user});
  @override
  State<AgentsScreen> createState() => _AgentsScreenState();
}

class _AgentsScreenState extends State<AgentsScreen>
    with SingleTickerProviderStateMixin {
  final _svc = ElectionService();
  late TabController _tabCtrl;
  List<_AgentInfo> _agents = [];
  List<_AgentInfo> _filtered = [];
  bool _loading = true;
  Timer? _timer;
  String _filterCommune = 'Toutes';
  final _searchCtrl = TextEditingController();

  final _communes = ['Toutes', 'RAS DIKA', 'BOULAOS', 'BALBALA'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _load();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _load());
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // Charger bureaux + présences + PV soumis
    final region = widget.user.isSuperviseurRegional ? widget.user.region : null;
    final bureaux = await _svc.getBureaux(region: region);
    final presences = await _svc.getPresences();
    final pvs = await _svc.getPvResults(region: region);
    final snapshots = await _svc.getAllTurnouts(region: region);

    final agents = bureaux.map((b) {
      final agentCode = _getBureauAgent(b.id);
      final presence = presences.firstWhere(
          (p) => p['agent_code'] == agentCode,
          orElse: () => <String, dynamic>{});
      final pv = pvs.firstWhere((p) => p.bureauId == b.id,
          orElse: () => PvResult(
              id: '', bureauId: '', agentCode: '', totalVotants: 0,
              bulletinsNuls: 0, abstentions: 0, voixCandidatA: 0,
              voixCandidatB: 0, createdAt: DateTime.now()));
      final nbSnap = snapshots.where((s) => s.bureauId == b.id).length;

      return _AgentInfo(
        agentCode: agentCode,
        bureauId: b.id,
        bureauNom: b.nom,
        commune: b.region,
        enLigne: presence['en_ligne'] == true,
        jamaisConnecte: presence.isEmpty,
        nbReleves: nbSnap,
        pvSoumis: pv.bureauId.isNotEmpty,
        statutPv: pv.bureauId.isEmpty ? 'absent' : pv.statut,
      );
    }).toList();

    setState(() {
      _agents = agents;
      _loading = false;
    });
    _applyFilter();
  }

  String _getBureauAgent(String bureauId) {
    final num = int.tryParse(bureauId.replaceAll('B', ''));
    if (num == null) return '';
    return 'AGENT-${num.toString().padLeft(3, '0')}';
  }

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _agents.where((a) {
        final matchCommune = _filterCommune == 'Toutes' || a.commune == _filterCommune;
        final matchSearch = q.isEmpty ||
            a.agentCode.toLowerCase().contains(q) ||
            a.bureauNom.toLowerCase().contains(q) ||
            a.bureauId.toLowerCase().contains(q);
        return matchCommune && matchSearch;
      }).toList();
    });
  }

  List<_AgentInfo> get _enLigne => _filtered.where((a) => a.enLigne).toList();
  List<_AgentInfo> get _horsLigne =>
      _filtered.where((a) => !a.enLigne && !a.jamaisConnecte).toList();
  List<_AgentInfo> get _jamaisConnecte =>
      _filtered.where((a) => a.jamaisConnecte).toList();

  @override
  Widget build(BuildContext context) {
    final total = _agents.length;
    final enligne = _agents.where((a) => a.enLigne).length;
    final jamais = _agents.where((a) => a.jamaisConnecte).length;
    final pvSoumis = _agents.where((a) => a.pvSoumis).length;

    return Column(children: [
      // Stats
      Container(
        color: const Color(0xFF1B5E20),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          _topStat('En ligne', enligne.toString(), Colors.greenAccent),
          _vDiv(),
          _topStat('Total', total.toString(), Colors.white),
          _vDiv(),
          _topStat('PV soumis', pvSoumis.toString(), Colors.orange),
          _vDiv(),
          _topStat('Jamais', jamais.toString(), Colors.red[200]!),
        ]),
      ),

      // Filtres
      Padding(
        padding: const EdgeInsets.all(8),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Rechercher agent / bureau...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (widget.user.isSuperviseurNational)
            DropdownButton<String>(
              value: _filterCommune,
              isDense: true,
              items: _communes
                  .map((c) => DropdownMenuItem(
                      value: c, child: Text(c, style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: (v) {
                setState(() => _filterCommune = v!);
                _applyFilter();
              },
            ),
        ]),
      ),

      // Onglets
      TabBar(
        controller: _tabCtrl,
        labelColor: const Color(0xFF1B5E20),
        indicatorColor: const Color(0xFF1B5E20),
        labelStyle: const TextStyle(fontSize: 12),
        tabs: [
          Tab(text: 'En ligne (${_enLigne.length})'),
          Tab(text: 'Hors ligne (${_horsLigne.length})'),
          Tab(text: 'Jamais (${_jamaisConnecte.length})'),
        ],
      ),

      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabCtrl,
                children: [
                  _listeAgents(_enLigne, Colors.green),
                  _listeAgents(_horsLigne, Colors.orange),
                  _listeAgents(_jamaisConnecte, Colors.red),
                ],
              ),
      ),
    ]);
  }

  Widget _listeAgents(List<_AgentInfo> agents, Color color) {
    if (agents.isEmpty) {
      return Center(
          child: Text('Aucun agent',
              style: TextStyle(color: Colors.grey[400])));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: agents.length,
        itemBuilder: (ctx, i) => _agentCard(agents[i], color),
      ),
    );
  }

  Widget _agentCard(_AgentInfo a, Color statusColor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(children: [
          // Status dot
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: a.enLigne
                  ? Colors.green
                  : a.jamaisConnecte
                      ? Colors.red
                      : Colors.orange,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          // Info
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(a.agentCode,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF1B5E20))),
                const SizedBox(width: 8),
                Text(a.bureauId,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ]),
              Text(a.bureauNom,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis),
              Text(a.commune,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ]),
          ),
          // Indicateurs
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _statutChip(a.statutPv),
            const SizedBox(height: 4),
            Text('${a.nbReleves} relevés',
                style: TextStyle(
                    fontSize: 11,
                    color: a.nbReleves > 0 ? Colors.blue : Colors.grey[400])),
          ]),
        ]),
      ),
    );
  }

  Widget _statutChip(String statut) {
    Color color;
    String label;
    switch (statut) {
      case 'valide':
        color = Colors.green;
        label = 'PV ✓';
        break;
      case 'rejete':
        color = Colors.red;
        label = 'Rejeté';
        break;
      case 'en_attente':
        color = Colors.orange;
        label = 'En attente';
        break;
      default:
        color = Colors.grey;
        label = 'Sans PV';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
    );
  }

  Widget _topStat(String label, String value, Color color) => Expanded(
        child: Column(children: [
          Text(value,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ]),
      );

  Widget _vDiv() => Container(
      width: 1, height: 30, color: Colors.white24,
      margin: const EdgeInsets.symmetric(horizontal: 4));
}

class _AgentInfo {
  final String agentCode;
  final String bureauId;
  final String bureauNom;
  final String commune;
  final bool enLigne;
  final bool jamaisConnecte;
  final int nbReleves;
  final bool pvSoumis;
  final String statutPv;

  _AgentInfo({
    required this.agentCode,
    required this.bureauId,
    required this.bureauNom,
    required this.commune,
    required this.enLigne,
    required this.jamaisConnecte,
    required this.nbReleves,
    required this.pvSoumis,
    required this.statutPv,
  });
}
