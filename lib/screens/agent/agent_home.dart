import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../utils/constants.dart';
import '../login_screen.dart';
import 'agent_bureau_detail.dart';
import 'cartes_screen.dart';

class AgentHome extends StatefulWidget {
  final AppUser user;
  const AgentHome({super.key, required this.user});
  @override
  State<AgentHome> createState() => _AgentHomeState();
}

class _AgentHomeState extends State<AgentHome> {
  final _svc = ElectionService();
  Bureau? _bureau;
  PvResult? _pv;
  List<TurnoutSnapshot> _snapshots = [];
  bool _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _svc.updatePresence(widget.user.code, true);
    // Refresh statut PV toutes les 15s
    _timer = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (_bureau != null) {
        final pv = await _svc.getPvBureau(_bureau!.id);
        if (mounted) setState(() => _pv = pv);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final bid = widget.user.bureauId;
    if (bid != null) {
      final b = await _svc.getBureau(bid);
      final pv = await _svc.getPvBureau(bid);
      final snaps = await _svc.getTurnoutBureau(bid);
      setState(() { _bureau = b; _pv = pv; _snapshots = snaps; _loading = false; });
    } else {
      setState(() => _loading = false);
    }
  }

  int get _heureActuelle => DateTime.now().hour.clamp(7, 17);
  static final DateTime _jourVote = DateTime(2026, 4, 10);
  static final DateTime _debutCartes = DateTime(2026, 3, 10);
  // Retraits: 10/03 → 10/04 inclus jusqu'à 18h
  // Vote: 10/04 de 7h à 18h (les deux phases coexistent le 10/04)

  String get _phaseLabel {
    final now = DateTime.now();
    final isJourVote = now.year == _jourVote.year &&
        now.month == _jourVote.month && now.day == _jourVote.day;

    // Avant le 10/03
    if (now.isBefore(_debutCartes)) return 'avant';

    // Jour du vote (10/04)
    if (isJourVote) {
      if (now.hour >= 7 && now.hour < 18) return 'vote_ouvert';     // Phase 2: vote + retraits
      if (now.hour >= 18) return 'depouillement';                    // Phase 3: dépouillement
    }

    // 10/03 → 09/04 + 10/04 avant 7h : phase retraits uniquement (Phase 1)
    final finRetraits = DateTime(2026, 4, 10, 18);
    if (!now.isAfter(finRetraits)) return 'retraits';

    // Après le 10/04 18h: résultats proclamés
    return 'proclamation';
  }


  String get _badgeTexte {
    switch (_phaseLabel) {
      case 'vote_ouvert':    return '🟢 Bureau ouvert';
      case 'depouillement':  return '🔵 Dépouillement';
      case 'proclamation':   return '🏆 Résultats publiés';
      case 'retraits':       return '🟡 Phase retraits';
      case 'avant':          return '⚪ Avant ouverture';
      default:               return '⚫ Terminé';
    }
  }

  Color get _badgeColor {
    switch (_phaseLabel) {
      case 'vote_ouvert':   return Colors.greenAccent;
      case 'depouillement': return Colors.blue;
      case 'proclamation':  return Colors.amber;
      case 'retraits':      return Colors.orange;
      default:              return Colors.grey;
    }
  }

  bool get _bureauOuvert => _phaseLabel == 'vote_ouvert';

  String get _titreSaisie {
    switch (_phaseLabel) {
      case 'retraits':      return 'Phase 1 — Retraits cartes';
      case 'vote_ouvert':   return 'Phase 2 — Jour du vote';
      case 'depouillement': return 'Phase 3 — Dépouillement';
      case 'proclamation':  return 'Résultats proclamés';
      default:              return 'Saisie des données';
    }
  }

  String get _statutPv {
    if (_pv == null) return 'Non soumis';
    if (_pv!.valide) return 'Validé ✓';
    if (_pv!.rejete) return 'Rejeté';
    return 'En attente';
  }

  Color get _couleurPv {
    if (_pv == null) return Colors.grey;
    if (_pv!.valide) return Colors.green;
    if (_pv!.rejete) return Colors.red;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(widget.user.code,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1B5E20),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _load),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              _svc.updatePresence(widget.user.code, false);
              Navigator.pushReplacement(
                  context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _bureau == null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text('Bureau ${widget.user.bureauId ?? "?"} introuvable',
                      style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.all(14), children: [
                    _bureauCard(),
                    const SizedBox(height: 12),
                    _statutCard(),
                    const SizedBox(height: 16),
                    Text(_titreSaisie,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 10),
                    _actionGrid(),
                  ]),
                ),
    );
  }

  Widget _bureauCard() {
    return Card(
      color: const Color(0xFF1B5E20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.location_on, color: Colors.white70, size: 16),
            const SizedBox(width: 6),
            Text(_bureau!.region, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _badgeColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_badgeTexte,
                  style: const TextStyle(color: Colors.white, fontSize: 11)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(_bureau!.nom, style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Text(_bureau!.id, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 10),
          Row(children: [
            _chip(Icons.people, '${_bureau!.inscrits} inscrits'),
            const SizedBox(width: 8),
            _chip(Icons.bar_chart, '${_snapshots.length}/11 relevés'),
          ]),
        ],
      )),
    );
  }

  Widget _chip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
    child: Row(children: [
      Icon(icon, color: Colors.white, size: 14),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
    ]),
  );

  Widget _statutCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
        Row(children: [
          const Text('Statut PV :', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _couleurPv.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _couleurPv.withOpacity(0.4)),
            ),
            child: Text(_statutPv,
                style: TextStyle(color: _couleurPv, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          if (_pv?.rejete == true) ...[
            const Spacer(),
            const Icon(Icons.warning_amber, color: Colors.red, size: 16),
          ],
        ]),
        if (_pv?.motifRejet != null) ...[
          const SizedBox(height: 6),
          Text('Motif: ${_pv!.motifRejet}',
              style: const TextStyle(color: Colors.red, fontSize: 12)),
        ],
      ])),
    );
  }

  Widget _actionGrid() {
    final actions = [
      _ActionItem(
        icon: Icons.access_time,
        label: 'Relevé ${_heureActuelle}h',
        subtitle: 'Participation horaire',
        color: Colors.blue,
        badge: _snapshots.any((s) => s.heure == _heureActuelle) ? '✓' : null,
        onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => AgentBureauDetail(user: widget.user, bureau: _bureau!,
                initialTab: 0))).then((_) => _load()),
      ),
      _ActionItem(
        icon: Icons.how_to_vote,
        label: 'PV Final',
        subtitle: 'Résultats dépouillement',
        color: _pv?.rejete == true ? Colors.red : Colors.green[700]!,
        badge: _pv != null ? (_pv!.valide ? '✓' : _pv!.rejete ? '!' : '…') : null,
        onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => AgentBureauDetail(user: widget.user, bureau: _bureau!,
                initialTab: 1))).then((_) => _load()),
      ),
      _ActionItem(
        icon: Icons.file_copy,
        label: 'Documents',
        subtitle: 'OM et ordonnances',
        color: Colors.orange,
        onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => DocumentsSaisieScreen(user: widget.user, bureau: _bureau!))),
      ),
      _ActionItem(
        icon: Icons.warning_amber,
        label: 'Signaler',
        subtitle: 'Anomalie ou incident',
        color: Colors.red,
        onTap: () => _signalerAnomalie(),
      ),
      _ActionItem(
        icon: Icons.message,
        label: 'Messagerie',
        subtitle: 'Contacter superviseur',
        color: Colors.purple,
        onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => MessagerieAgentScreen(user: widget.user))),
      ),
      _ActionItem(
        icon: Icons.credit_card,
        label: 'Cartes',
        subtitle: 'Retraits électeurs',
        color: Colors.teal,
        onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => CartesScreen(user: widget.user, bureau: _bureau!))).then((_) => _load()),
      ),
      _ActionItem(
        icon: Icons.history,
        label: 'Historique',
        subtitle: 'Mes saisies',
        color: Colors.indigo,
        onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => HistoriqueScreen(user: widget.user, bureau: _bureau!,
                snapshots: _snapshots, pv: _pv))),
      ),
    ];

    return GridView.count(
      crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10,
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.3,
      children: actions.map((a) => _actionCard(a)).toList(),
    );
  }

  Widget _actionCard(_ActionItem a) {
    return InkWell(
      onTap: a.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        child: Stack(children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(a.icon, color: a.color, size: 28),
              const SizedBox(height: 8),
              Text(a.label, textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold,
                      color: Colors.grey[800], fontSize: 13)),
              Text(a.subtitle, textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            ]),
          ),
          if (a.badge != null)
            Positioned(top: 8, right: 8,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: a.badge == '✓' ? Colors.green : a.badge == '!' ? Colors.red : Colors.orange,
                  shape: BoxShape.circle,
                ),
                child: Text(a.badge!, style: const TextStyle(
                    color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              )),
        ]),
      ),
    );
  }

  Future<void> _signalerAnomalie() async {
    final descCtrl = TextEditingController();
    String niveau = 'WARNING';
    await showDialog(context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) => AlertDialog(
        title: const Text('Signaler une anomalie'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: descCtrl, maxLines: 3, autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Décrivez l\'incident...',
                  border: OutlineInputBorder())),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: niveau,
            decoration: const InputDecoration(labelText: 'Niveau', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: 'INFO', child: Text('INFO — Informatif')),
              const DropdownMenuItem(value: 'WARNING', child: Text('⚠ WARNING — Avertissement')),
              const DropdownMenuItem(value: 'CRITIQUE', child: Text('🚨 CRITIQUE — Urgent')),
            ],
            onChanged: (v) => setDlg(() => niveau = v!),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              if (descCtrl.text.trim().isEmpty) return;
              await _svc.signalerAnomalie(
                  _bureau!.id, widget.user.code, descCtrl.text.trim(), niveau);
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Anomalie signalée'), backgroundColor: Colors.orange));
              }
            },
            child: const Text('Signaler'),
          ),
        ],
      )));
  }
}

class _ActionItem {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final String? badge;
  final VoidCallback onTap;
  _ActionItem({required this.icon, required this.label, required this.subtitle,
      required this.color, required this.onTap, this.badge});
}

// ─── Écran Documents saisie ───────────────────────────────────
class DocumentsSaisieScreen extends StatefulWidget {
  final AppUser user;
  final Bureau bureau;
  const DocumentsSaisieScreen({super.key, required this.user, required this.bureau});
  @override State<DocumentsSaisieScreen> createState() => _DocumentsSaisieScreenState();
}

class _DocumentsSaisieScreenState extends State<DocumentsSaisieScreen> {
  final _svc = ElectionService();
  Document? _doc;
  bool _loading = true;
  final _omCtrl = TextEditingController();
  final _ordCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final docs = await _svc.getDocuments();
    Document? d;
    try { d = docs.firstWhere((doc) => doc.bureauId == widget.bureau.id); } catch (_) {}
    setState(() { _doc = d; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Documents'),
          backgroundColor: const Color(0xFF1B5E20), foregroundColor: Colors.white),
      body: _loading ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              Card(color: Colors.orange[50], child: Padding(padding: const EdgeInsets.all(12),
                  child: Text(widget.bureau.nom,
                      style: const TextStyle(fontWeight: FontWeight.bold)))),
              const SizedBox(height: 16),
              if (_doc != null)
                Card(
                  color: _doc!.valide ? Colors.green[50] : Colors.orange[50],
                  child: ListTile(
                    leading: Icon(_doc!.valide ? Icons.verified : Icons.pending,
                        color: _doc!.valide ? Colors.green : Colors.orange),
                    title: Text(_doc!.valide ? 'Documents validés ✓' : 'En attente de validation'),
                    subtitle: Text('OM: ${_doc!.nbOm} | Ordonnances: ${_doc!.nbOrdonnances}'),
                  ),
                ),
              if (_doc == null || !_doc!.valide) ...[
                const SizedBox(height: 8),
                Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Saisir les documents',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 16),
                    TextField(controller: _omCtrl, keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Nombre d\'OM',
                            border: OutlineInputBorder(), prefixIcon: Icon(Icons.description))),
                    const SizedBox(height: 12),
                    TextField(controller: _ordCtrl, keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Nombre d\'ordonnances',
                            border: OutlineInputBorder(), prefixIcon: Icon(Icons.file_present))),
                    const SizedBox(height: 20),
                    SizedBox(width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.upload),
                        label: const Text('Soumettre les documents'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B5E20), foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: () async {
                          final om = int.tryParse(_omCtrl.text);
                          final ord = int.tryParse(_ordCtrl.text);
                          if (om == null || ord == null) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text('Remplissez tous les champs')));
                            return;
                          }
                          await _svc.soumettreDocuments(
                              widget.bureau.id, widget.user.code, om, ord);
                          await _load();
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Documents soumis ✓'),
                                  backgroundColor: Colors.green));
                        },
                      ),
                    ),
                  ],
                ))),
              ],
            ]),
    );
  }
}

// ─── Messagerie agent ─────────────────────────────────────────
class MessagerieAgentScreen extends StatefulWidget {
  final AppUser user;
  const MessagerieAgentScreen({super.key, required this.user});
  @override State<MessagerieAgentScreen> createState() => _MessagerieAgentScreenState();
}

class _MessagerieAgentScreenState extends State<MessagerieAgentScreen> {
  final _svc = ElectionService();
  List<Message> _messages = [];
  bool _loading = true;
  final _ctrl = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final msgs = await _svc.getMessages(widget.user.code);
    setState(() { _messages = msgs; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messagerie'),
          backgroundColor: const Color(0xFF1B5E20), foregroundColor: Colors.white,
          actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)]),
      body: Column(children: [
        Expanded(
          child: _loading ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? const Center(child: Text('Aucun message'))
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length,
                      itemBuilder: (ctx, i) {
                        final m = _messages[i];
                        final isMine = m.expediteur == widget.user.code;
                        return Align(
                          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            padding: const EdgeInsets.all(10),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                            decoration: BoxDecoration(
                              color: isMine ? const Color(0xFF1B5E20) : Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                if (!isMine) Text(m.expediteur,
                                    style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                                Text(m.contenu, style: TextStyle(
                                    color: isMine ? Colors.white : Colors.black)),
                                Text('${m.createdAt.hour}:${m.createdAt.minute.toString().padLeft(2,'0')}',
                                    style: TextStyle(fontSize: 9,
                                        color: isMine ? Colors.white60 : Colors.grey)),
                              ],
                            ),
                          ),
                        );
                      }),
        ),
        Container(
          padding: const EdgeInsets.all(8), color: Colors.white,
          child: Row(children: [
            Expanded(child: TextField(controller: _ctrl,
                decoration: const InputDecoration(hintText: 'Message au superviseur...',
                    border: OutlineInputBorder(), isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)))),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.send, color: Color(0xFF1B5E20)),
              onPressed: () async {
                if (_ctrl.text.trim().isEmpty) return;
                await _svc.envoyerMessage(widget.user.code, 'SUPERVISEUR', _ctrl.text.trim());
                _ctrl.clear();
                await _load();
              },
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─── Historique des saisies ──────────────────────────────────
class HistoriqueScreen extends StatelessWidget {
  final AppUser user;
  final Bureau bureau;
  final List<TurnoutSnapshot> snapshots;
  final PvResult? pv;
  const HistoriqueScreen({super.key, required this.user, required this.bureau,
      required this.snapshots, this.pv});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historique des saisies'),
          backgroundColor: const Color(0xFF1B5E20), foregroundColor: Colors.white),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        // Relevés
        const Text('Relevés horaires', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        if (snapshots.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(16),
              child: Text('Aucun relevé saisi', style: TextStyle(color: Colors.grey))))
        else
          ...snapshots.map((s) => Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.withOpacity(0.1),
                child: Text('${s.heure}h', style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue))),
              title: Text('${s.votants} votants',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Taux: ${bureau.inscrits > 0 ? (s.votants / bureau.inscrits * 100).toStringAsFixed(1) : 0}%'),
              trailing: const Icon(Icons.check_circle, color: Colors.green, size: 18),
            ),
          )),
        const SizedBox(height: 16),

        // PV
        const Text('PV Final', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        if (pv == null)
          const Card(child: Padding(padding: EdgeInsets.all(16),
              child: Text('PV non soumis', style: TextStyle(color: Colors.grey))))
        else
          Card(
            color: pv!.valide ? Colors.green[50] : pv!.rejete ? Colors.red[50] : Colors.orange[50],
            child: Padding(padding: const EdgeInsets.all(14), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(pv!.valide ? Icons.verified : pv!.rejete ? Icons.cancel : Icons.pending,
                      color: pv!.valide ? Colors.green : pv!.rejete ? Colors.red : Colors.orange),
                  const SizedBox(width: 8),
                  Text(pv!.valide ? 'Validé' : pv!.rejete ? 'Rejeté' : 'En attente',
                      style: TextStyle(fontWeight: FontWeight.bold,
                          color: pv!.valide ? Colors.green : pv!.rejete ? Colors.red : Colors.orange)),
                ]),
                const Divider(),
                _row('Total votants', pv!.totalVotants),
                _row('Candidat A', pv!.voixCandidatA),
                _row('Candidat B', pv!.voixCandidatB),
                _row('Nuls', pv!.bulletinsNuls),
                _row('Abstentions', pv!.abstentions),
                if (pv!.motifRejet != null) ...[
                  const Divider(),
                  Text('Motif rejet: ${pv!.motifRejet}',
                      style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
              ],
            )),
          ),
      ]),
    );
  }

  Widget _row(String l, int v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      Expanded(child: Text(l, style: const TextStyle(fontSize: 13))),
      Text(v.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
    ]),
  );
}
