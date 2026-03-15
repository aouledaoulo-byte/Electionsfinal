import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/services.dart';

class InscritsScreen extends StatefulWidget {
  final AppUser user;
  const InscritsScreen({super.key, required this.user});
  @override
  State<InscritsScreen> createState() => _InscritsScreenState();
}

class _InscritsScreenState extends State<InscritsScreen>
    with SingleTickerProviderStateMixin {
  final _svc = ElectionService();
  late TabController _tabCtrl;
  List<Bureau> _bureaux = [];
  List<Bureau> _filtered = [];
  List<Map<String, dynamic>> _supCodes = [];
  bool _loading = true;
  String _selectedCommune = 'Toutes communes';
  final _searchCtrl = TextEditingController();

  final List<String> _communes = ['Toutes communes', 'RAS DIKA', 'BOULAOS', 'BALBALA'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    if (widget.user.isSuperviseurRegional && widget.user.region != null) {
      _selectedCommune = widget.user.region!;
    }
    _load();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final region = widget.user.isSuperviseurRegional ? widget.user.region : null;
    final b = await _svc.getBureaux(region: region);
    final sup = await _svc.getSuperviseurs();
    setState(() { _bureaux = b; _supCodes = sup; _loading = false; });
    _applyFilter();
  }

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _bureaux.where((b) {
        final matchC = _selectedCommune == 'Toutes communes' || b.region == _selectedCommune;
        final matchS = q.isEmpty ||
            b.nom.toLowerCase().contains(q) ||
            b.id.toLowerCase().contains(q);
        return matchC && matchS;
      }).toList();
    });
  }

  int get _totalInscrits => _filtered.fold(0, (s, b) => s + b.inscrits);

  // ─── ACTIONS BUREAUX ────────────────────────────────────────

  Future<void> _modifierInscrits(Bureau b) async {
    final ctrl = TextEditingController(text: b.inscrits.toString());
    final ok = await showDialog<bool>(context: context,
      builder: (_) => AlertDialog(
        title: Text('Modifier inscrits — ${b.id}', style: const TextStyle(fontSize: 15)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(b.nom, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(b.region, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 12),
          TextField(controller: ctrl, keyboardType: TextInputType.number, autofocus: true,
              decoration: const InputDecoration(labelText: 'Nombre d\'inscrits', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5E20), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enregistrer'),
          ),
        ],
      ));
    if (ok == true) {
      final val = int.tryParse(ctrl.text);
      if (val == null || val < 0) return;
      await _svc.updateInscrits(b.id, val);
      b.inscrits = val;
      setState(() {});
      if (mounted) _snack('${b.id}: $val inscrits', Colors.green);
    }
  }

  Future<void> _renommer(Bureau b) async {
    final ctrl = TextEditingController(text: b.nom);
    final ok = await showDialog<bool>(context: context,
      builder: (_) => AlertDialog(
        title: Text('Renommer — ${b.id}', style: const TextStyle(fontSize: 15)),
        content: TextField(controller: ctrl, autofocus: true,
            decoration: const InputDecoration(labelText: 'Nouveau nom', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5E20), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enregistrer'),
          ),
        ],
      ));
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      await _svc.renameBureau(b.id, ctrl.text.trim());
      b.nom = ctrl.text.trim();
      setState(() {});
    }
  }

  Future<void> _ajouter() async {
    final nomCtrl = TextEditingController();
    final insCtrl = TextEditingController(text: '440');
    String commune = widget.user.isSuperviseurRegional
        ? widget.user.region!
        : (_selectedCommune == 'Toutes communes' ? 'BOULAOS' : _selectedCommune);
    await showDialog(context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) => AlertDialog(
        title: const Text('Ajouter un bureau', style: TextStyle(fontSize: 15)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nomCtrl, autofocus: true,
              decoration: const InputDecoration(labelText: 'Nom du bureau', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          if (widget.user.isSuperviseurNational)
            DropdownButtonFormField<String>(
              value: commune,
              decoration: const InputDecoration(labelText: 'Commune', border: OutlineInputBorder()),
              items: ['RAS DIKA', 'BOULAOS', 'BALBALA'].map((c) =>
                  DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setDlg(() => commune = v!),
            ),
          const SizedBox(height: 12),
          TextField(controller: insCtrl, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Inscrits', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5E20), foregroundColor: Colors.white),
            onPressed: () async {
              if (nomCtrl.text.trim().isEmpty) return;
              final newId = 'B${(_bureaux.length + 1).toString().padLeft(3, '0')}';
              await _svc.addBureau(Bureau(
                  id: newId, nom: nomCtrl.text.trim(), region: commune,
                  inscrits: int.tryParse(insCtrl.text) ?? 440));
              await _load();
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Ajouter'),
          ),
        ],
      )));
  }

  Future<void> _supprimer(Bureau b) async {
    final ok = await showDialog<bool>(context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: Text('${b.nom}\n${b.id} — ${b.region}\n\nCette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ));
    if (ok == true) {
      await _svc.deleteBureau(b.id);
      await _load();
    }
  }

  void _showStats() {
    final byCommune = <String, Map<String, int>>{};
    for (var b in _bureaux) {
      byCommune.putIfAbsent(b.region, () => {'nb': 0, 'inscrits': 0});
      byCommune[b.region]!['nb'] = byCommune[b.region]!['nb']! + 1;
      byCommune[b.region]!['inscrits'] = byCommune[b.region]!['inscrits']! + b.inscrits;
    }
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Statistiques'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _sRow('Total bureaux', _bureaux.length.toString(), bold: true),
        _sRow('Total inscrits', _bureaux.fold(0, (s, b) => s + b.inscrits).toString(), bold: true),
        const Divider(),
        ...byCommune.entries.map((e) => Column(children: [
          Container(width: double.infinity, color: Colors.grey[100],
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold))),
          _sRow('  Bureaux', e.value['nb'].toString()),
          _sRow('  Inscrits', e.value['inscrits'].toString()),
          const SizedBox(height: 4),
        ])),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
    ));
  }

  // ─── SUPERVISEURS ───────────────────────────────────────────

  Widget _superviseurTab() {
    // Codes par défaut si Supabase vide
    final defaults = [
      {'code': 'SUPNAT-2026', 'region': 'National', 'role': 'Superviseur National'},
      {'code': 'SUPBOU-2026', 'region': 'BOULAOS', 'role': 'Superviseur BOULAOS'},
      {'code': 'SUPBAL-2026', 'region': 'BALBALA', 'role': 'Superviseur BALBALA'},
      {'code': 'SUPRAS-2026', 'region': 'RAS DIKA', 'role': 'Superviseur RAS DIKA'},
    ];

    // Fusionner avec données Supabase
    List<Map<String, dynamic>> affichage = List.from(defaults);
    for (var s in _supCodes) {
      final region = s['region']?.toString() ?? '';
      final idx = affichage.indexWhere((d) => d['region'] == region);
      if (idx >= 0 && s['code_personnalise'] != null) {
        affichage[idx] = {...affichage[idx], 'code_perso': s['code_personnalise'].toString()};
      }
    }

    // Filtrer selon le rôle: régional ne voit que son entrée
    if (widget.user.isSuperviseurRegional) {
      affichage = affichage.where((s) => s['region'] == widget.user.region).toList();
    }

    return ListView(padding: const EdgeInsets.all(12), children: [
      // Info accès
      Card(color: Colors.blue[50],
        child: Padding(padding: const EdgeInsets.all(12), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Codes d\'accès superviseurs',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            const Text('Le code par défaut sert pour la première connexion.\nEnsuite chaque superviseur peut personnaliser son code.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ))),
      const SizedBox(height: 8),

      ...affichage.map((s) {
        final codeActuel = s['code_perso']?.toString() ?? s['code'].toString();
        final aPerso = s.containsKey('code_perso');
        final isMyCode = widget.user.region == s['region'] ||
            (widget.user.isSuperviseurNational && s['region'] == 'National');

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(padding: const EdgeInsets.all(14), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF1B5E20).withOpacity(0.1),
                  child: const Icon(Icons.manage_accounts, color: Color(0xFF1B5E20)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s['role'].toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(s['region'].toString(),
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ])),
              ]),
              const SizedBox(height: 10),

              // Code par défaut
              _codeRow('Code par défaut', s['code'].toString(), Colors.grey[700]!),
              const SizedBox(height: 6),

              // Code personnalisé
              if (aPerso)
                _codeRow('Code actuel', codeActuel, Colors.green[700]!),

              // Bouton personnaliser
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: Icon(aPerso ? Icons.edit : Icons.add_circle_outline, size: 16),
                  label: Text(aPerso ? 'Modifier le code' : 'Personnaliser le code'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1B5E20),
                    side: const BorderSide(color: Color(0xFF1B5E20)),
                  ),
                  onPressed: () => _personnaliserCode(
                    s['region'].toString(), s['role'].toString(), codeActuel),
                ),
              ),

              // Accès: quelles données ce superviseur voit
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(children: [
                  const Icon(Icons.visibility, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(child: Text(
                    s['region'] == 'National'
                        ? 'Accès total — voit toutes les communes'
                        : 'Accès limité — voit uniquement ${s['region']}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  )),
                ]),
              ),
            ],
          )),
        );
      }),
    ]);
  }

  Future<void> _personnaliserCode(String region, String role, String codeActuel) async {
    final ctrl = TextEditingController(text: codeActuel);
    final ok = await showDialog<bool>(context: context,
      builder: (_) => AlertDialog(
        title: Text('Personnaliser — $role', style: const TextStyle(fontSize: 14)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Choisissez un nouveau code d\'accès personnalisé.',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nouveau code',
              hintText: 'Ex: MON-CODE-2026',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          const Text('⚠ Notez bien ce code — il remplacera l\'ancien.',
              style: TextStyle(fontSize: 11, color: Colors.orange)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5E20), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enregistrer'),
          ),
        ],
      ));
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      await _svc.setSuperviseurCode(region, ctrl.text.trim().toUpperCase());
      await _load();
      if (mounted) _snack('Code mis à jour pour $region', Colors.green);
    }
  }

  Widget _codeRow(String label, String code, Color color) {
    return Row(children: [
      Text('$label : ', style: const TextStyle(fontSize: 12, color: Colors.grey)),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(code,
            style: TextStyle(fontFamily: 'monospace',
                fontWeight: FontWeight.bold, color: color, fontSize: 13)),
      ),
    ]);
  }

  // ─── AGENTS ──────────────────────────────────────────────────

  Widget _agentsTab() {
    final zones = widget.user.isSuperviseurNational
        ? [
            {'commune': 'RAS DIKA', 'debut': 1, 'fin': 15},
            {'commune': 'BOULAOS', 'debut': 16, 'fin': 217},
            {'commune': 'BALBALA', 'debut': 218, 'fin': 413},
          ]
        : [
            {
              'commune': widget.user.region ?? '',
              'debut': widget.user.region == 'RAS DIKA' ? 1 : widget.user.region == 'BOULAOS' ? 16 : 218,
              'fin': widget.user.region == 'RAS DIKA' ? 15 : widget.user.region == 'BOULAOS' ? 217 : 413,
            }
          ];

    return ListView(padding: const EdgeInsets.all(12), children: [
      Card(color: Colors.orange[50],
        child: Padding(padding: const EdgeInsets.all(12), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Codes agents', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text(
              widget.user.isSuperviseurNational
                  ? 'AGT-001 à AGT-413 — 413 agents au total'
                  : 'Agents de ${widget.user.region}',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ))),
      const SizedBox(height: 8),
      ...zones.map((z) {
        final nb = (z['fin'] as int) - (z['debut'] as int) + 1;
        final colors = {'RAS DIKA': Colors.teal, 'BOULAOS': Colors.blue, 'BALBALA': Colors.purple};
        final color = colors[z['commune']] ?? Colors.grey;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              child: Icon(Icons.location_on, color: color, size: 20),
            ),
            title: Text(z['commune'] as String,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
                'AGT-${(z['debut'] as int).toString().padLeft(3,'0')} → AGT-${(z['fin'] as int).toString().padLeft(3,'0')} ($nb agents)'),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(children: [
                  _sRow('Plage codes', 'AGT-${(z['debut'] as int).toString().padLeft(3,'0')} → AGT-${(z['fin'] as int).toString().padLeft(3,'0')}'),
                  _sRow('Nombre d\'agents', nb.toString()),
                  _sRow('Bureaux assignés', 'B${(z['debut'] as int).toString().padLeft(3,'0')} → B${(z['fin'] as int).toString().padLeft(3,'0')}'),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.list, size: 16),
                      label: Text('Voir les $nb agents'),
                      onPressed: () => _showAgentList(
                          z['commune'] as String, z['debut'] as int, z['fin'] as int),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        );
      }),
    ]);
  }

  void _showAgentList(String commune, int debut, int fin) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.7, maxChildSize: 0.95,
        builder: (_, ctrl) => Column(children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1B5E20),
            child: Row(children: [
              Text(commune, style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              Text('${fin - debut + 1} agents',
                  style: const TextStyle(color: Colors.white70)),
            ]),
          ),
          Expanded(
            child: ListView.builder(
              controller: ctrl,
              itemCount: fin - debut + 1,
              itemBuilder: (_, i) {
                final num = debut + i;
                final agent = 'AGT-${num.toString().padLeft(3, '0')}';
                final bureau = 'B${num.toString().padLeft(3, '0')}';
                final nomBureau = _bureaux.firstWhere(
                    (b) => b.id == bureau,
                    orElse: () => Bureau(id: bureau, nom: bureau, region: commune)).nom;
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(radius: 16,
                    backgroundColor: const Color(0xFF1B5E20).withOpacity(0.1),
                    child: Text(num.toString(),
                        style: const TextStyle(fontSize: 10,
                            fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)))),
                  title: Text(agent,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text(nomBureau,
                      style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                  trailing: Text(bureau,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  // ─── HELPERS ─────────────────────────────────────────────────

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: color));
  }

  Widget _sRow(String l, String v, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Expanded(child: Text(l, style: TextStyle(fontSize: 13,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal))),
      Text(v, style: TextStyle(
          fontWeight: bold ? FontWeight.bold : FontWeight.w600, fontSize: 13)),
    ]),
  );

  Widget _topStat(String l, String v) => Expanded(child: Column(children: [
    Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
    Text(l, style: const TextStyle(color: Colors.white70, fontSize: 10)),
  ]));

  Widget _vDiv() => Container(width: 1, height: 30, color: Colors.white30,
      margin: const EdgeInsets.symmetric(horizontal: 4));

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: const Color(0xFF1B5E20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          _topStat('Bureaux', _filtered.length.toString()),
          _vDiv(),
          _topStat('Inscrits', _totalInscrits.toString()),
          _vDiv(),
          _topStat('Commune', _selectedCommune == 'Toutes communes' ? 'Toutes' : _selectedCommune),
        ]),
      ),
      TabBar(
        controller: _tabCtrl,
        labelColor: const Color(0xFF1B5E20),
        unselectedLabelColor: Colors.grey,
        indicatorColor: const Color(0xFF1B5E20),
        tabs: const [
          Tab(icon: Icon(Icons.list_alt, size: 18), text: 'Bureaux'),
          Tab(icon: Icon(Icons.manage_accounts, size: 18), text: 'Superviseurs'),
          Tab(icon: Icon(Icons.badge, size: 18), text: 'Agents'),
        ],
      ),
      Expanded(
        child: TabBarView(
          controller: _tabCtrl,
          children: [_bureauTab(), _superviseurTab(), _agentsTab()],
        ),
      ),
    ]);
  }

  Widget _bureauTab() {
    return Column(children: [
      Container(
        color: Colors.grey[100],
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(children: [
          _btn(Icons.add, 'Ajouter', Colors.green, _ajouter),
          const SizedBox(width: 6),
          _btn(Icons.bar_chart, 'Stats', Colors.orange, _showStats),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.all(8),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Rechercher un centre...',
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
              value: _selectedCommune,
              isDense: true,
              items: _communes.map((c) => DropdownMenuItem(
                  value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (v) { setState(() => _selectedCommune = v!); _applyFilter(); },
            ),
        ]),
      ),
      Container(
        color: const Color(0xFF1B5E20),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(children: [
          _colH('Code', 65),
          _colH('Centre de vote', 0, flex: true),
          _colH('Commune', 70),
          _colH('Inscrits', 65, center: true),
          _colH('', 44),
        ]),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _filtered.isEmpty
                ? const Center(child: Text('Aucun bureau'))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (ctx, i) {
                        final b = _filtered[i];
                        return Container(
                          decoration: BoxDecoration(
                            color: i % 2 == 0 ? Colors.white : Colors.grey[50],
                            border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                          ),
                          child: Row(children: [
                            _cell(b.id, 65, bold: true, color: const Color(0xFF1B5E20)),
                            _cellFlex(b.nom),
                            _cell(b.region, 70, small: true),
                            _cell(b.inscrits.toString(), 65, center: true, bold: true),
                            SizedBox(
                              width: 44,
                              child: PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                                onSelected: (v) {
                                  if (v == 'inscrits') _modifierInscrits(b);
                                  if (v == 'rename') _renommer(b);
                                  if (v == 'delete') _supprimer(b);
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(value: 'inscrits', child: Row(children: [
                                    Icon(Icons.edit_note, size: 16, color: Colors.blue),
                                    SizedBox(width: 8), Text('Modifier inscrits')])),
                                  const PopupMenuItem(value: 'rename', child: Row(children: [
                                    Icon(Icons.drive_file_rename_outline, size: 16, color: Colors.orange),
                                    SizedBox(width: 8), Text('Renommer')])),
                                  const PopupMenuItem(value: 'delete', child: Row(children: [
                                    Icon(Icons.delete, size: 16, color: Colors.red),
                                    SizedBox(width: 8), Text('Supprimer',
                                        style: TextStyle(color: Colors.red))])),
                                ],
                              ),
                            ),
                          ]),
                        );
                      },
                    ),
                  ),
      ),
    ]);
  }

  Widget _btn(IconData i, String l, Color c, VoidCallback f) => InkWell(
    onTap: f,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withOpacity(0.4)),
      ),
      child: Row(children: [
        Icon(i, size: 16, color: c), const SizedBox(width: 4),
        Text(l, style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.bold)),
      ]),
    ),
  );

  Widget _colH(String t, double w, {bool flex = false, bool center = false}) {
    final child = Text(t, textAlign: center ? TextAlign.center : null,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold));
    return flex
        ? Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: child))
        : SizedBox(width: w, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: child));
  }

  Widget _cell(String t, double w, {bool bold = false, bool center = false,
      bool small = false, Color? color}) =>
      SizedBox(width: w, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Text(t, textAlign: center ? TextAlign.center : TextAlign.left,
              style: TextStyle(fontSize: small ? 10 : 12,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color),
              overflow: TextOverflow.ellipsis)));

  Widget _cellFlex(String t) => Expanded(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Text(t, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)));
}
