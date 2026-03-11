import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

final _sb = Supabase.instance.client;

// ============================================================
//  AUTH SERVICE
// ============================================================
class AuthService {
  Future<Utilisateur?> loginWithCode(String codeUnique) async {
    try {
      // Chercher l'utilisateur par code unique
      final res = await _sb
          .from('utilisateurs')
          .select()
          .eq('code_unique', codeUnique)
          .eq('actif', true)
          .single();

      final user = Utilisateur.fromJson(res);

      // Connexion anonyme liée au code unique
      if (_sb.auth.currentSession == null) {
        await _sb.auth.signInAnonymously();
      }

      // Sauvegarder localement
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', user.id);
      await prefs.setString('user_role', user.role);
      await prefs.setString('user_nom', user.nom);
      if (user.region != null) await prefs.setString('user_region', user.region!);
      if (user.commune != null) await prefs.setString('user_commune', user.commune!);

      return user;
    } catch (e) {
      return null;
    }
  }

  Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_role');
  }

  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }

  Future<String?> getUserCommune() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_commune');
  }

  Future<String?> getUserNom() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_nom');
  }

  Future<void> logout() async {
    await _sb.auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}

// ============================================================
//  SUPABASE DATA SERVICE
// ============================================================
class DataService {
  // ── Bureaux ─────────────────────────────────────────────
  Future<List<Bureau>> getBureauxAgent(String agentId) async {
    final res = await _sb.from('bureaux').select().eq('agent_id', agentId).eq('actif', true);
    return (res as List).map((j) => Bureau.fromJson(j)).toList();
  }

  Future<List<Bureau>> getBureauxRegion(String region) async {
    final res = await _sb.from('bureaux').select().eq('region', region).eq('actif', true);
    return (res as List).map((j) => Bureau.fromJson(j)).toList();
  }

  Future<List<Bureau>> getAllBureaux() async {
    final res = await _sb.from('bureaux').select().eq('actif', true).order('region');
    return (res as List).map((j) => Bureau.fromJson(j)).toList();
  }

  // ── Turnout Snapshots ────────────────────────────────────
  Future<List<TurnoutSnapshot>> getSnapshotsBureau(String bureauId) async {
    final res = await _sb
        .from('turnout_snapshots')
        .select()
        .eq('bureau_id', bureauId)
        .order('heure');
    return (res as List).map((j) => TurnoutSnapshot.fromJson(j)).toList();
  }

  Future<bool> submitSnapshot({
    required String bureauId, required int heure,
    required int votants, required String saisiPar,
  }) async {
    try {
      await _sb.from('turnout_snapshots').upsert({
        'bureau_id': bureauId, 'heure': heure, 'votants': votants,
        'saisi_par': saisiPar, 'statut': 'soumis', 'offline': false,
      }, onConflict: 'bureau_id,heure');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> validerSnapshot(String snapshotId, String validesPar) async {
    try {
      await _sb.from('turnout_snapshots').update({
        'statut': 'valide', 'valide_par': validesPar,
      }).eq('id', snapshotId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> rejeterSnapshot(String snapshotId, String noteRejet, String validesPar) async {
    try {
      await _sb.from('turnout_snapshots').update({
        'statut': 'rejete', 'note_rejet': noteRejet, 'valide_par': validesPar,
      }).eq('id', snapshotId);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── PV Results ───────────────────────────────────────────
  Future<PvResult?> getPvBureau(String bureauId) async {
    try {
      final res = await _sb.from('pv_results').select().eq('bureau_id', bureauId).single();
      return PvResult.fromJson(res);
    } catch (_) {
      return null;
    }
  }

  Future<List<PvResult>> getPvRegion(String region) async {
    final bureaux = await getBureauxRegion(region);
    final ids = bureaux.map((b) => b.id).toList();
    if (ids.isEmpty) return [];
    final res = await _sb.from('pv_results').select().inFilter('bureau_id', ids);
    return (res as List).map((j) => PvResult.fromJson(j)).toList();
  }

  Future<List<PvResult>> getAllPv() async {
    final res = await _sb.from('pv_results').select();
    return (res as List).map((j) => PvResult.fromJson(j)).toList();
  }

  Future<bool> submitPv({
    required String bureauId, required int votants, required int nuls,
    required int voixA, required int voixB,
    required String saisiPar, String? photoUrl,
  }) async {
    try {
      await _sb.from('pv_results').upsert({
        'bureau_id': bureauId, 'votants': votants, 'nuls': nuls,
        'voix_a': voixA, 'voix_b': voixB, 'saisi_par': saisiPar,
        'photo_url': photoUrl, 'statut': 'soumis', 'offline': false,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'bureau_id');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> validerPv(String pvId, String validesPar) async {
    try {
      await _sb.from('pv_results').update({'statut': 'valide', 'valide_par': validesPar}).eq('id', pvId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> rejeterPv(String pvId, String noteRejet, String validesPar) async {
    try {
      await _sb.from('pv_results').update({'statut': 'rejete', 'note_rejet': noteRejet, 'valide_par': validesPar}).eq('id', pvId);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── Dashboards (vues Supabase) ───────────────────────────
  Future<Map<String, dynamic>?> getKpiNational() async {
    try {
      final res = await _sb.from('kpi_pv_national').select().single();
      return res;
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getKpiByRegion() async {
    final res = await _sb.from('kpi_pv_by_region').select().order('region');
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> getLiveCoverage({String? commune}) async {
    if (commune != null && commune.isNotEmpty) {
      // Filtrage par commune via requête directe
      final bureaux = await _sb.from('bureaux').select('id').eq('commune', commune);
      final ids = (bureaux as List).map((b) => b['id'].toString()).toList();
      if (ids.isEmpty) return [];
      final snaps = await _sb.from('turnout_snapshots')
          .select('heure, votants, bureau_id')
          .inFilter('bureau_id', ids)
          .order('heure');
      // Agréger par heure
      final Map<int, Map<String, dynamic>> byHeure = {};
      final totalBureaux = ids.length;
      for (final s in snaps as List) {
        final h = s['heure'] as int;
        if (!byHeure.containsKey(h)) {
          byHeure[h] = {'heure': h, 'nb_snapshots': 0, 'bureaux_actifs': <String>{}, 'total_votants': 0, 'total_bureaux': totalBureaux};
        }
        byHeure[h]!['nb_snapshots'] = (byHeure[h]!['nb_snapshots'] as int) + 1;
        (byHeure[h]!['bureaux_actifs'] as Set<String>).add(s['bureau_id'].toString());
        byHeure[h]!['total_votants'] = (byHeure[h]!['total_votants'] as int) + (s['votants'] as int? ?? 0);
      }
      return byHeure.values.map((h) {
        final actifs = (h['bureaux_actifs'] as Set<String>).length;
        return {
          'heure': h['heure'],
          'nb_snapshots': h['nb_snapshots'],
          'bureaux_actifs': actifs,
          'bureaux_valides': actifs,
          'total_bureaux': h['total_bureaux'],
          'moy_votants': actifs > 0 ? h['total_votants'] / actifs : 0,
          'taux_participation': 0,
          'pct_couverture': totalBureaux > 0 ? (actifs / totalBureaux * 100) : 0,
        };
      }).toList()..sort((a, b) => (a['heure'] as int).compareTo(b['heure'] as int));
    }
    final res = await _sb.from('kpi_live_coverage_by_hour').select().order('heure');
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> getAnomalies() async {
    final res = await _sb.from('v_audit_pv_anomalies').select().neq('niveau_anomalie', 'OK');
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> getComparaisonLivePv() async {
    final res = await _sb.from('v_compare_live18_pv').select();
    return List<Map<String, dynamic>>.from(res);
  }

  // ── Upload photo PV ──────────────────────────────────────
  Future<String?> uploadPhotoPv(String bureauId, List<int> bytes) async {
    try {
      final path = 'pv/$bureauId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _sb.storage.from('pv-photos').uploadBinary(path, bytes);
      final url = _sb.storage.from('pv-photos').getPublicUrl(path);
      return url;
    } catch (_) {
      return null;
    }
  }
}

// ============================================================
//  OFFLINE SERVICE
// ============================================================
class OfflineService {
  static const _keySnapshots = 'offline_snapshots';
  static const _keyPv = 'offline_pv';

  Future<void> saveSnapshotOffline(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keySnapshots) ?? [];
    list.add(data.toString());
    await prefs.setStringList(_keySnapshots, list);
  }

  Future<void> savePvOffline(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyPv) ?? [];
    list.add(data.toString());
    await prefs.setStringList(_keyPv, list);
  }

  Future<int> getPendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getStringList(_keySnapshots) ?? [];
    final p = prefs.getStringList(_keyPv) ?? [];
    return s.length + p.length;
  }
}
