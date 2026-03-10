// ── Bureau ──────────────────────────────────────────────────
class Bureau {
  final String id, code, nom, region, commune, centre;
  final int inscrits, ordreMission, ordonnance;
  final String? agentId;

  Bureau({
    required this.id, required this.code, required this.nom,
    required this.region, required this.commune, required this.centre,
    required this.inscrits, required this.ordreMission, required this.ordonnance,
    this.agentId,
  });

  int get inscritsCorriges => inscrits + ordreMission + ordonnance;

  factory Bureau.fromJson(Map<String, dynamic> j) => Bureau(
    id: j['id'], code: j['code'], nom: j['nom'],
    region: j['region'], commune: j['commune'], centre: j['centre'],
    inscrits: j['inscrits'] ?? 0,
    ordreMission: j['ordre_mission'] ?? 0,
    ordonnance: j['ordonnance'] ?? 0,
    agentId: j['agent_id'],
  );
}

// ── TurnoutSnapshot ─────────────────────────────────────────
class TurnoutSnapshot {
  final String? id, bureauId, saisiPar, validesPar, noteRejet;
  final int heure, votants;
  final String statut;
  final bool offline;
  final DateTime? createdAt;

  TurnoutSnapshot({
    this.id, required this.bureauId, required this.heure,
    required this.votants, required this.statut,
    this.saisiPar, this.validesPar, this.noteRejet,
    this.offline = false, this.createdAt,
  });

  factory TurnoutSnapshot.fromJson(Map<String, dynamic> j) => TurnoutSnapshot(
    id: j['id'], bureauId: j['bureau_id'],
    heure: j['heure'], votants: j['votants'],
    statut: j['statut'] ?? 'soumis',
    saisiPar: j['saisi_par'], validesPar: j['valide_par'],
    noteRejet: j['note_rejet'], offline: j['offline'] ?? false,
    createdAt: j['created_at'] != null ? DateTime.parse(j['created_at']) : null,
  );

  Map<String, dynamic> toJson() => {
    'bureau_id': bureauId, 'heure': heure, 'votants': votants,
    'statut': statut, 'saisi_par': saisiPar, 'offline': offline,
  };
}

// ── PvResult ─────────────────────────────────────────────────
class PvResult {
  final String? id, bureauId, saisiPar, validesPar, noteRejet, photoUrl;
  final int votants, nuls, voixA, voixB;
  final String statut;
  final bool offline;
  final DateTime? createdAt;

  PvResult({
    this.id, required this.bureauId, required this.votants,
    required this.nuls, required this.voixA, required this.voixB,
    required this.statut, this.saisiPar, this.validesPar,
    this.noteRejet, this.photoUrl, this.offline = false, this.createdAt,
  });

  int get exprimes => voixA + voixB;
  double get pctA => exprimes > 0 ? voixA / exprimes * 100 : 0;
  double get pctB => exprimes > 0 ? voixB / exprimes * 100 : 0;
  double get pctNuls => votants > 0 ? nuls / votants * 100 : 0;

  factory PvResult.fromJson(Map<String, dynamic> j) => PvResult(
    id: j['id'], bureauId: j['bureau_id'],
    votants: j['votants'] ?? 0, nuls: j['nuls'] ?? 0,
    voixA: j['voix_a'] ?? 0, voixB: j['voix_b'] ?? 0,
    statut: j['statut'] ?? 'soumis',
    saisiPar: j['saisi_par'], validesPar: j['valide_par'],
    noteRejet: j['note_rejet'], photoUrl: j['photo_url'],
    offline: j['offline'] ?? false,
    createdAt: j['created_at'] != null ? DateTime.parse(j['created_at']) : null,
  );

  Map<String, dynamic> toJson() => {
    'bureau_id': bureauId, 'votants': votants, 'nuls': nuls,
    'voix_a': voixA, 'voix_b': voixB, 'statut': statut,
    'saisi_par': saisiPar, 'photo_url': photoUrl, 'offline': offline,
  };
}

// ── Utilisateur ──────────────────────────────────────────────
class Utilisateur {
  final String id, codeUnique, nom, role;
  final String? prenom, region, authId;

  Utilisateur({
    required this.id, required this.codeUnique,
    required this.nom, required this.role,
    this.prenom, this.region, this.authId,
  });

  factory Utilisateur.fromJson(Map<String, dynamic> j) => Utilisateur(
    id: j['id'], codeUnique: j['code_unique'],
    nom: j['nom'], role: j['role'],
    prenom: j['prenom'], region: j['region'], authId: j['auth_id'],
  );
}
