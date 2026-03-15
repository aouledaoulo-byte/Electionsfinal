import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../models/models.dart';

class _Supa {
  static const _url = supabaseUrl;
  static const _key = supabaseAnonKey;

  static Map<String, String> get _h => {
        'apikey': _key,
        'Authorization': 'Bearer $_key',
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      };

  static Future<List<Map<String, dynamic>>> select(String table,
      [String q = '']) async {
    try {
      final String url;
      if (q.isNotEmpty) {
        url = '$_url/rest/v1/$table?$q&limit=1000';
      } else {
        url = '$_url/rest/v1/$table?limit=1000';
      }
      final r = await http
          .get(Uri.parse(url), headers: _h)
          .timeout(const Duration(seconds: 15));
      if (r.statusCode == 200 || r.statusCode == 206) {
        if (r.body.isEmpty || r.body == 'null') return [];
        final decoded = jsonDecode(r.body);
        if (decoded is List) return List<Map<String, dynamic>>.from(decoded);
      }
    } catch (_) {}
    return [];
  }

  static Future<bool> upsert(String table, Map<String, dynamic> data) async {
    try {
      final r = await http
          .post(
            Uri.parse('$_url/rest/v1/$table'),
            headers: {
              ..._h,
              'Prefer': 'resolution=merge-duplicates,return=minimal'
            },
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 15));
      return r.statusCode >= 200 && r.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  // Méthode patch/update robuste avec logging
  static Future<bool> updateById(String table, String id, Map<String, dynamic> data) async {
    try {
      final r = await http
          .patch(
            Uri.parse('$_url/rest/v1/$table?id=eq.$id'),
            headers: {..._h, 'Prefer': 'return=minimal'},
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 15));
      return r.statusCode >= 200 && r.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> insert(String table, Map<String, dynamic> data) async {
    try {
      final r = await http
          .post(
            Uri.parse('$_url/rest/v1/$table'),
            headers: _h,
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 10));
      return r.statusCode >= 200 && r.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> update(
      String table, Map<String, dynamic> data, String filter) async {
    try {
      final r = await http
          .patch(
            Uri.parse('$_url/rest/v1/$table?$filter'),
            headers: _h,
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 10));
      return r.statusCode >= 200 && r.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> delete(String table, String filter) async {
    try {
      final r = await http
          .delete(
            Uri.parse('$_url/rest/v1/$table?$filter'),
            headers: _h,
          )
          .timeout(const Duration(seconds: 10));
      return r.statusCode >= 200 && r.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}

// ─────────────────────────────────────────────
// AuthService
// ─────────────────────────────────────────────
class AuthService {
  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;

  Future<AppUser?> login(String code) async {
    final c = code.trim().toUpperCase();

    // Agent: AGT-001 à AGT-413
    final agentMatch = RegExp(r'^AGT-(\d{3})$').firstMatch(c);
    if (agentMatch != null) {
      final num = int.parse(agentMatch.group(1)!);
      if (num >= 1 && num <= 413) {
        _currentUser = AppUser(code: c, role: AppRoles.agent);
        return _currentUser;
      }
    }

    // Superviseur national — code par défaut
    if (c == 'SUPNAT-2026') {
      _currentUser = AppUser(code: c, role: AppRoles.superviseurNational);
      return _currentUser;
    }

    // Superviseurs régionaux — code par défaut
    if (superviseurRegionMap.containsKey(c)) {
      _currentUser = AppUser(
          code: c,
          role: AppRoles.superviseurRegional,
          region: superviseurRegionMap[c]);
      return _currentUser;
    }

    // Vérifier les codes personnalisés dans Supabase
    try {
      final sups = await _Supa.select('superviseurs');
      for (final s in sups) {
        final perso = s['code_personnalise']?.toString().toUpperCase() ?? '';
        if (perso == c) {
          final region = s['region']?.toString() ?? '';
          if (region == 'National') {
            _currentUser = AppUser(code: c, role: AppRoles.superviseurNational);
          } else {
            _currentUser = AppUser(
                code: c, role: AppRoles.superviseurRegional, region: region);
          }
          return _currentUser;
        }
      }
    } catch (_) {}

    return null;
  }

  void logout() => _currentUser = null;
}

// ─────────────────────────────────────────────
// ElectionService
// ─────────────────────────────────────────────
class ElectionService {
  // Bureaux
  Future<List<Bureau>> getBureaux({String? region}) async {
    final q = region != null
        ? 'region=eq.$region&order=id.asc'
        : 'order=id.asc';
    final data = await _Supa.select('bureaux', q);
    if (data.isNotEmpty) {
      return data.map((e) => Bureau.fromMap(e)).toList();
    }
    // Fallback local si API vide ou inaccessible
    final fallback = kBureauxFallback.where((m) {
      if (region != null) return m['region'] == region;
      return true;
    }).map((m) => Bureau(
          id: m['id']!,
          nom: m['nom']!,
          region: m['region']!,
          inscrits: int.tryParse(m['inscrits'] ?? '440') ?? 440,
        )).toList();
    return fallback;
  }

  Future<Bureau?> getBureau(String id) async {
    final data = await _Supa.select('bureaux', 'id=eq.$id');
    if (data.isNotEmpty) return Bureau.fromMap(data.first);
    // Fallback local
    try {
      final fb = kBureauxFallback.firstWhere((m) => m['id'] == id);
      return Bureau(
        id: fb['id']!, nom: fb['nom']!, region: fb['region']!,
        inscrits: int.tryParse(fb['inscrits'] ?? '440') ?? 440,
      );
    } catch (_) {}
    return null;
  }

  Future<bool> updateInscrits(String bureauId, int inscrits) =>
      _Supa.update('bureaux', {'inscrits': inscrits}, 'id=eq.$bureauId');

  Future<bool> renameBureau(String bureauId, String nom) =>
      _Supa.update('bureaux', {'nom': nom}, 'id=eq.$bureauId');

  Future<bool> addBureau(Bureau b) => _Supa.insert('bureaux', b.toMap());

  Future<bool> deleteBureau(String id) =>
      _Supa.delete('bureaux', 'id=eq.$id');

  // Relevés horaires
  Future<bool> soumettreTurnout(
          String bureauId, String agentCode, int heure, int votants) =>
      _Supa.upsert('turnout_snapshots', {
        'bureau_id': bureauId,
        'agent_code': agentCode,
        'heure': heure,
        'votants': votants,
        'created_at': DateTime.now().toIso8601String(),
      });

  Future<List<TurnoutSnapshot>> getTurnoutAll({String? region}) async {
    if (region != null) {
      final bureaux = await getBureaux(region: region);
      final ids = bureaux.map((b) => b.id).join(',');
      if (ids.isEmpty) return [];
      final data = await _Supa.select('turnout_snapshots',
          'bureau_id=in.($ids)&order=heure.asc');
      return data.map((e) => TurnoutSnapshot.fromMap(e)).toList();
    }
    final data = await _Supa.select('turnout_snapshots', 'order=heure.asc');
    return data.map((e) => TurnoutSnapshot.fromMap(e)).toList();
  }

  Future<List<TurnoutSnapshot>> getTurnoutBureau(String bureauId) async {
    final data = await _Supa.select(
        'turnout_snapshots', 'bureau_id=eq.$bureauId&order=heure.asc');
    return data.map((e) => TurnoutSnapshot.fromMap(e)).toList();
  }

  Future<List<TurnoutSnapshot>> getAllTurnouts({String? region}) async {
    if (region != null) {
      final bureaux = await getBureaux(region: region);
      final ids = bureaux.map((b) => b.id).join(',');
      if (ids.isEmpty) return [];
      final data = await _Supa.select(
          'turnout_snapshots', 'bureau_id=in.($ids)&order=heure.asc');
      return data.map((e) => TurnoutSnapshot.fromMap(e)).toList();
    }
    final data =
        await _Supa.select('turnout_snapshots', 'order=heure.asc');
    return data.map((e) => TurnoutSnapshot.fromMap(e)).toList();
  }

  // PV Résultats
  Future<bool> soumettreResultats(PvResult pv) =>
      _Supa.upsert('pv_results', {
        'bureau_id': pv.bureauId,
        'agent_code': pv.agentCode,
        'total_votants': pv.totalVotants,
        'bulletins_nuls': pv.bulletinsNuls,
        'abstentions': pv.abstentions,
        'voix_candidat_a': pv.voixCandidatA,
        'voix_candidat_b': pv.voixCandidatB,
        'statut': 'en_attente',
        'created_at': DateTime.now().toIso8601String(),
      });

  Future<List<PvResult>> getPvResults({String? region}) async {
    if (region != null) {
      final bureaux = await getBureaux(region: region);
      final ids = bureaux.map((b) => b.id).join(',');
      if (ids.isEmpty) return [];
      final data = await _Supa.select(
          'pv_results', 'bureau_id=in.($ids)&order=created_at.desc');
      return data.map((e) => PvResult.fromMap(e)).toList();
    }
    final data =
        await _Supa.select('pv_results', 'order=created_at.desc');
    return data.map((e) => PvResult.fromMap(e)).toList();
  }

  Future<PvResult?> getPvBureau(String bureauId) async {
    final data = await _Supa.select(
        'pv_results', 'bureau_id=eq.$bureauId&order=created_at.desc');
    if (data.isEmpty) return null;
    return PvResult.fromMap(data.first);
  }

  // Superviseur RÉGIONAL valide → statut = valide_reg
  Future<bool> validerPvRegional(String pvId) =>
      _Supa.update('pv_results', {'statut': 'valide_reg'}, 'id=eq.$pvId');

  Future<bool> rejeterPvRegional(String pvId, String motif) => _Supa.update(
      'pv_results',
      {'statut': 'rejete_reg', 'motif_rejet': motif},
      'id=eq.$pvId');

  // Superviseur NATIONAL valide → statut = publie
  Future<bool> validerPvNational(String pvId) =>
      _Supa.update('pv_results', {'statut': 'publie'}, 'id=eq.$pvId');

  Future<bool> rejeterPvNational(String pvId, String motif) => _Supa.update(
      'pv_results',
      {'statut': 'rejete_nat', 'motif_rejet': motif},
      'id=eq.$pvId');

  // Compat
  Future<bool> validerPv(String pvId) => validerPvRegional(pvId);
  Future<bool> rejeterPv(String pvId, String motif) => rejeterPvRegional(pvId, motif);

  // PV publiés (validés par national)
  Future<List<PvResult>> getPvPublies({String? region}) async {
    if (region != null) {
      final bureaux = await getBureaux(region: region);
      final ids = bureaux.map((b) => b.id).join(',');
      if (ids.isEmpty) return [];
      final data = await _Supa.select('pv_results',
          'bureau_id=in.($ids)&statut=eq.publie&order=created_at.desc');
      return data.map((e) => PvResult.fromMap(e)).toList();
    }
    final data = await _Supa.select('pv_results', 'statut=eq.publie&order=created_at.desc');
    return data.map((e) => PvResult.fromMap(e)).toList();
  }

  // Documents
  Future<bool> soumettreDocuments(String bureauId, String agentCode,
          int nbOm, int nbOrdonnances) =>
      _Supa.upsert('documents', {
        'bureau_id': bureauId,
        'agent_code': agentCode,
        'nb_om': nbOm,
        'nb_ordonnances': nbOrdonnances,
        'valide': false,
        'created_at': DateTime.now().toIso8601String(),
      });

  Future<List<Document>> getDocuments({String? region}) async {
    if (region != null) {
      final bureaux = await getBureaux(region: region);
      final ids = bureaux.map((b) => b.id).join(',');
      if (ids.isEmpty) return [];
      final data = await _Supa.select(
          'documents', 'bureau_id=in.($ids)&order=created_at.desc');
      return data.map((e) => Document.fromMap(e)).toList();
    }
    final data =
        await _Supa.select('documents', 'order=created_at.desc');
    return data.map((e) => Document.fromMap(e)).toList();
  }

  Future<bool> validerDocument(String docId) =>
      _Supa.update('documents', {'valide': true}, 'id=eq.$docId');

  // Messages
  Future<bool> envoyerMessage(
          String expediteur, String destinataire, String contenu) =>
      _Supa.insert('messages', {
        'expediteur': expediteur,
        'destinataire': destinataire,
        'contenu': contenu,
        'lu': false,
        'created_at': DateTime.now().toIso8601String(),
      });

  Future<bool> broadcastMessage(String expediteur, String contenu) =>
      _Supa.insert('messages', {
        'expediteur': expediteur,
        'destinataire': 'TOUS',
        'contenu': contenu,
        'lu': false,
        'created_at': DateTime.now().toIso8601String(),
      });

  Future<List<Message>> getMessages(String userCode) async {
    final data = await _Supa.select(
        'messages',
        'or=(destinataire.eq.$userCode,destinataire.eq.TOUS,expediteur.eq.$userCode)&order=created_at.desc');
    return data.map((e) => Message.fromMap(e)).toList();
  }

  Future<bool> marquerLu(String msgId) =>
      _Supa.update('messages', {'lu': true}, 'id=eq.$msgId');

  // Anomalies
  Future<bool> signalerAnomalie(String bureauId, String agentCode,
          String description, String niveau) =>
      _Supa.insert('anomalies', {
        'bureau_id': bureauId,
        'agent_code': agentCode,
        'description': description,
        'niveau': niveau,
        'traitee': false,
        'created_at': DateTime.now().toIso8601String(),
      });

  Future<List<Anomalie>> getAnomalies({String? region}) async {
    if (region != null) {
      final bureaux = await getBureaux(region: region);
      final ids = bureaux.map((b) => b.id).join(',');
      if (ids.isEmpty) return [];
      final data = await _Supa.select(
          'anomalies', 'bureau_id=in.($ids)&order=created_at.desc');
      return data.map((e) => Anomalie.fromMap(e)).toList();
    }
    final data = await _Supa.select(
        'anomalies', 'traitee=eq.false&order=created_at.desc');
    return data.map((e) => Anomalie.fromMap(e)).toList();
  }

  Future<bool> traiterAnomalie(String anomalieId) =>
      _Supa.update('anomalies', {'traitee': true}, 'id=eq.$anomalieId');

  // Présence agents
  Future<bool> updatePresence(String agentCode, bool enLigne) =>
      _Supa.upsert('agent_presence', {
        'agent_code': agentCode,
        'en_ligne': enLigne,
        'updated_at': DateTime.now().toIso8601String(),
      });

  Future<List<Map<String, dynamic>>> getPresences() async {
    return await _Supa.select('agent_presence');
  }

  // Superviseurs — codes personnalisés
  Future<List<Map<String, dynamic>>> getSuperviseurs() async {
    return await _Supa.select('superviseurs');
  }

  Future<bool> setSuperviseurCode(String region, String codePersonnalise) =>
      _Supa.upsert('superviseurs', {
        'region': region,
        'code_personnalise': codePersonnalise,
        'updated_at': DateTime.now().toIso8601String(),
      });

  // ─── Retraits cartes d'électeur ──────────────────────────
  Future<RetraitCartes?> getRetraitCartes(String bureauId) async {
    final data = await _Supa.select('retrait_cartes',
        'bureau_id=eq.$bureauId&order=updated_at.desc');
    if (data.isEmpty) return null;
    return RetraitCartes.fromMap(data.first);
  }

  Future<List<RetraitCartes>> getAllRetraitCartes({String? region}) async {
    if (region != null) {
      final bureaux = await getBureaux(region: region);
      final ids = bureaux.map((b) => b.id).join(',');
      if (ids.isEmpty) return [];
      final data = await _Supa.select('retrait_cartes',
          'bureau_id=in.($ids)&order=bureau_id.asc');
      return data.map((e) => RetraitCartes.fromMap(e)).toList();
    }
    final data = await _Supa.select('retrait_cartes', 'order=bureau_id.asc');
    return data.map((e) => RetraitCartes.fromMap(e)).toList();
  }

  Future<bool> soumettreRetraitCartes(String bureauId, String agentCode,
      int nbRetraits, int nbNonRetraits, String? observations) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final data = {
      'bureau_id': bureauId,
      'agent_code': agentCode,
      'nb_retraits': nbRetraits,
      'nb_non_retraits': nbNonRetraits,
      'observations': observations,
      'valide': false,
      'date_saisie': today,
      'updated_at': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    };
    // Mettre à jour le dernier retrait connu
    await _Supa.upsert('retrait_cartes', data);
    // Enregistrer dans l'historique par jour
    await _Supa.upsert('retrait_cartes_historique', data);
    return true;
  }

  Future<bool> validerRetraitCartes(String retraitId) =>
      _Supa.update('retrait_cartes', {'valide': true}, 'id=eq.$retraitId');

  // Historique retraits avec filtre date
  Future<List<RetraitCartes>> getRetraitsParDate(String date, {String? region}) async {
    if (region != null) {
      final bureaux = await getBureaux(region: region);
      final ids = bureaux.map((b) => b.id).join(',');
      if (ids.isEmpty) return [];
      final data = await _Supa.select('retrait_cartes_historique',
          'bureau_id=in.($ids)&date_saisie=eq.$date&order=bureau_id.asc');
      return data.map((e) => RetraitCartes.fromMap(e)).toList();
    }
    final data = await _Supa.select('retrait_cartes_historique',
        'date_saisie=eq.$date&order=bureau_id.asc');
    return data.map((e) => RetraitCartes.fromMap(e)).toList();
  }

  // Historique journalier depuis retrait_cartes_horaire (pas besoin de vue SQL)
  Future<List<Map<String, dynamic>>> getStatsSemaineCartes({String? region}) async {
    try {
      if (region != null) {
        final bureaux = await getBureaux(region: region);
        final ids = bureaux.map((b) => b.id).join(',');
        if (ids.isEmpty) return [];
        final data = await _Supa.select('retrait_cartes_horaire',
            'bureau_id=in.($ids)&order=date_saisie.asc,heure.asc');
        return data.cast<Map<String, dynamic>>();
      }
      final data = await _Supa.select('retrait_cartes_horaire',
          'order=date_saisie.asc,heure.asc');
      return data.cast<Map<String, dynamic>>();
    } catch (_) {
      // Fallback: construire depuis retrait_cartes
      final retraits = await getAllRetraitCartes(region: region);
      return retraits.map((r) => {
        'bureau_id': r.bureauId,
        'date_saisie': r.dateSaisie?.toIso8601String().substring(0, 10)
            ?? r.updatedAt.toIso8601String().substring(0, 10),
        'nb_retraits': r.nbRetraits,
        'nb_non_retraits': r.nbNonRetraits,
        'commune': '',
        'heure': 12,
      }).toList();
    }
  }

  // ─── Retraits cartes HORAIRES (1h-24h) ─────────────────
  Future<bool> soumettreRetraitHoraire(String bureauId, String agentCode,
      DateTime date, int heure, int nbRetraits) async {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';
    final inscrits = (await getBureau(bureauId))?.inscrits ?? 440;
    final nonRetraits = (inscrits - nbRetraits).clamp(0, inscrits);
    return _Supa.upsert('retrait_cartes_horaire', {
      'bureau_id': bureauId,
      'agent_code': agentCode,
      'date_saisie': dateStr,
      'heure': heure,
      'nb_retraits': nbRetraits,
      'nb_non_retraits': nonRetraits,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<RetraitCartesHoraire>> getRetraitsHorairesBureau(
      String bureauId, DateTime date) async {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';
    final data = await _Supa.select('retrait_cartes_horaire',
        'bureau_id=eq.$bureauId&date_saisie=eq.$dateStr&order=heure.asc');
    return data.map((e) => RetraitCartesHoraire.fromMap(e)).toList();
  }

  Future<List<RetraitCartesHoraire>> getAllRetraitsHoraires({
    String? region, DateTime? date}) async {
    final dateStr = date != null
        ? '${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}'
        : null;
    if (region != null) {
      final bureaux = await getBureaux(region: region);
      final ids = bureaux.map((b) => b.id).join(',');
      if (ids.isEmpty) return [];
      final q = dateStr != null
          ? 'bureau_id=in.($ids)&date_saisie=eq.$dateStr&order=heure.asc'
          : 'bureau_id=in.($ids)&order=date_saisie.desc,heure.asc';
      final data = await _Supa.select('retrait_cartes_horaire', q);
      return data.map((e) => RetraitCartesHoraire.fromMap(e)).toList();
    }
    final q = dateStr != null
        ? 'date_saisie=eq.$dateStr&order=heure.asc'
        : 'order=date_saisie.desc,heure.asc';
    final data = await _Supa.select('retrait_cartes_horaire', q);
    return data.map((e) => RetraitCartesHoraire.fromMap(e)).toList();
  }
}