import '../utils/constants.dart';

class AppUser {
  final String code;
  final AppRoles role;
  final String? region;

  AppUser({required this.code, required this.role, this.region});

  bool get isAgent => role == AppRoles.agent;
  bool get isSuperviseurNational => role == AppRoles.superviseurNational;
  bool get isSuperviseurRegional => role == AppRoles.superviseurRegional;
  bool get isSuperviseur => role != AppRoles.agent;

  String get displayName {
    if (isAgent) return 'Agent $code';
    if (isSuperviseurNational) return 'Superviseur National';
    return 'Superviseur ${region ?? ''}';
  }

  String? get bureauId => isAgent ? getBureauForAgent(code) : null;
}

class Bureau {
  final String id;
  String nom;
  String region;
  int inscrits;
  int inscritsCorrection;

  Bureau({
    required this.id,
    required this.nom,
    required this.region,
    this.inscrits = 440,
    this.inscritsCorrection = 0,
  });

  int get inscritsEffectifs =>
      inscritsCorrection > 0 ? inscritsCorrection : inscrits;

  factory Bureau.fromMap(Map<String, dynamic> m) => Bureau(
        id: m['id']?.toString() ?? '',
        nom: m['nom']?.toString() ?? '',
        region: m['region']?.toString() ?? '',
        inscrits: (m['inscrits'] as num?)?.toInt() ?? 440,
        inscritsCorrection:
            (m['inscrits_correction'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'nom': nom,
        'region': region,
        'inscrits': inscrits,
      };
}

class TurnoutSnapshot {
  final String id;
  final String bureauId;
  final String agentCode;
  final int heure;
  final int votants;
  final DateTime createdAt;

  TurnoutSnapshot({
    required this.id,
    required this.bureauId,
    required this.agentCode,
    required this.heure,
    required this.votants,
    required this.createdAt,
  });

  factory TurnoutSnapshot.fromMap(Map<String, dynamic> m) => TurnoutSnapshot(
        id: m['id']?.toString() ?? '',
        bureauId: m['bureau_id']?.toString() ?? '',
        agentCode: m['agent_code']?.toString() ?? '',
        heure: (m['heure'] as num?)?.toInt() ?? 0,
        votants: (m['votants'] as num?)?.toInt() ?? 0,
        createdAt:
            DateTime.tryParse(m['created_at']?.toString() ?? '') ?? DateTime.now(),
      );
}

class PvResult {
  final String id;
  final String bureauId;
  final String agentCode;
  final int totalVotants;
  final int bulletinsNuls;
  final int abstentions;
  final int voixCandidatA;
  final int voixCandidatB;
  String statut;
  // Workflow: soumis → valide_reg → valide_nat → publie
  //           soumis → rejete_reg (superviseur régional rejette)
  //           valide_reg → rejete_nat (superviseur national rejette)
  String? motifRejet;
  final DateTime createdAt;

  PvResult({
    required this.id,
    required this.bureauId,
    required this.agentCode,
    required this.totalVotants,
    required this.bulletinsNuls,
    required this.abstentions,
    required this.voixCandidatA,
    required this.voixCandidatB,
    this.statut = 'soumis',
    this.motifRejet,
    required this.createdAt,
  });

  bool get valide => statut == 'valide_reg' || statut == 'valide_nat' || statut == 'publie';
  bool get valideReg => statut == 'valide_reg';
  bool get valideNat => statut == 'valide_nat' || statut == 'publie';
  bool get publie => statut == 'publie';
  bool get rejete => statut == 'rejete_reg' || statut == 'rejete_nat';
  bool get rejeteReg => statut == 'rejete_reg';
  bool get rejeteNat => statut == 'rejete_nat';
  bool get enAttente => statut == 'soumis';
  int get bulletinsValides => voixCandidatA + voixCandidatB;

  factory PvResult.fromMap(Map<String, dynamic> m) => PvResult(
        id: m['id']?.toString() ?? '',
        bureauId: m['bureau_id']?.toString() ?? '',
        agentCode: m['agent_code']?.toString() ?? '',
        totalVotants: (m['total_votants'] as num?)?.toInt() ?? 0,
        bulletinsNuls: (m['bulletins_nuls'] as num?)?.toInt() ?? 0,
        abstentions: (m['abstentions'] as num?)?.toInt() ?? 0,
        voixCandidatA: (m['voix_candidat_a'] as num?)?.toInt() ?? 0,
        voixCandidatB: (m['voix_candidat_b'] as num?)?.toInt() ?? 0,
        statut: m['statut']?.toString() ?? 'soumis',
        motifRejet: m['motif_rejet']?.toString(),
        createdAt:
            DateTime.tryParse(m['created_at']?.toString() ?? '') ?? DateTime.now(),
      );
}

class Document {
  final String id;
  final String bureauId;
  final String agentCode;
  final int nbOm;
  final int nbOrdonnances;
  bool valide;
  final DateTime createdAt;

  Document({
    required this.id,
    required this.bureauId,
    required this.agentCode,
    required this.nbOm,
    required this.nbOrdonnances,
    this.valide = false,
    required this.createdAt,
  });

  factory Document.fromMap(Map<String, dynamic> m) => Document(
        id: m['id']?.toString() ?? '',
        bureauId: m['bureau_id']?.toString() ?? '',
        agentCode: m['agent_code']?.toString() ?? '',
        nbOm: (m['nb_om'] as num?)?.toInt() ?? 0,
        nbOrdonnances: (m['nb_ordonnances'] as num?)?.toInt() ?? 0,
        valide: m['valide'] == true,
        createdAt:
            DateTime.tryParse(m['created_at']?.toString() ?? '') ?? DateTime.now(),
      );
}

class Message {
  final String id;
  final String expediteur;
  final String destinataire;
  final String contenu;
  bool lu;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.expediteur,
    required this.destinataire,
    required this.contenu,
    this.lu = false,
    required this.createdAt,
  });

  factory Message.fromMap(Map<String, dynamic> m) => Message(
        id: m['id']?.toString() ?? '',
        expediteur: m['expediteur']?.toString() ?? '',
        destinataire: m['destinataire']?.toString() ?? '',
        contenu: m['contenu']?.toString() ?? '',
        lu: m['lu'] == true,
        createdAt:
            DateTime.tryParse(m['created_at']?.toString() ?? '') ?? DateTime.now(),
      );
}

class AgentStatus {
  final String agentCode;
  final String bureauId;
  final String commune;
  final bool enLigne;
  final int nbReleves;
  final bool pvSoumis;
  final String statutPv;
  final DateTime? derniereActivite;

  AgentStatus({
    required this.agentCode,
    required this.bureauId,
    required this.commune,
    required this.enLigne,
    required this.nbReleves,
    required this.pvSoumis,
    required this.statutPv,
    this.derniereActivite,
  });

  factory AgentStatus.fromMap(Map<String, dynamic> m) => AgentStatus(
        agentCode: m['agent_code']?.toString() ?? '',
        bureauId: m['bureau_id']?.toString() ?? '',
        commune: m['commune']?.toString() ?? '',
        enLigne: m['en_ligne'] == true,
        nbReleves: (m['nb_releves'] as num?)?.toInt() ?? 0,
        pvSoumis: m['pv_soumis'] == true,
        statutPv: m['statut_pv']?.toString() ?? 'absent',
        derniereActivite:
            DateTime.tryParse(m['derniere_activite']?.toString() ?? ''),
      );
}

class Anomalie {
  final String id;
  final String bureauId;
  final String agentCode;
  final String description;
  final String niveau; // 'CRITIQUE', 'WARNING', 'INFO'
  final bool traitee;
  final DateTime createdAt;

  Anomalie({
    required this.id,
    required this.bureauId,
    required this.agentCode,
    required this.description,
    required this.niveau,
    this.traitee = false,
    required this.createdAt,
  });

  factory Anomalie.fromMap(Map<String, dynamic> m) => Anomalie(
        id: m['id']?.toString() ?? '',
        bureauId: m['bureau_id']?.toString() ?? '',
        agentCode: m['agent_code']?.toString() ?? '',
        description: m['description']?.toString() ?? '',
        niveau: m['niveau']?.toString() ?? 'INFO',
        traitee: m['traitee'] == true,
        createdAt:
            DateTime.tryParse(m['created_at']?.toString() ?? '') ?? DateTime.now(),
      );
}

class RetraitCartes {
  final String id;
  final String bureauId;
  final String agentCode;
  int nbRetraits;
  int nbNonRetraits;
  String? observations;
  bool valide;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? dateSaisie;

  RetraitCartes({
    required this.id,
    required this.bureauId,
    required this.agentCode,
    required this.nbRetraits,
    required this.nbNonRetraits,
    this.observations,
    this.valide = false,
    required this.createdAt,
    required this.updatedAt,
    this.dateSaisie,
  });

  double tauxRetrait(int inscrits) =>
      inscrits > 0 ? nbRetraits / inscrits * 100 : 0;

  factory RetraitCartes.fromMap(Map<String, dynamic> m) => RetraitCartes(
        id: m['id']?.toString() ?? '',
        bureauId: m['bureau_id']?.toString() ?? '',
        agentCode: m['agent_code']?.toString() ?? '',
        nbRetraits: (m['nb_retraits'] as num?)?.toInt() ?? 0,
        nbNonRetraits: (m['nb_non_retraits'] as num?)?.toInt() ?? 0,
        observations: m['observations']?.toString(),
        valide: m['valide'] == true,
        createdAt: DateTime.tryParse(m['created_at']?.toString() ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(m['updated_at']?.toString() ?? '') ?? DateTime.now(),
        dateSaisie: DateTime.tryParse(m['date_saisie']?.toString() ?? ''),
      );
}

class RetraitCartesHoraire {
  final String id;
  final String bureauId;
  final String agentCode;
  final DateTime dateSaisie;
  final int heure; // 1 à 24
  final int nbRetraits; // cumulatif à cette heure
  final int nbNonRetraits;
  final DateTime createdAt;

  RetraitCartesHoraire({
    required this.id,
    required this.bureauId,
    required this.agentCode,
    required this.dateSaisie,
    required this.heure,
    required this.nbRetraits,
    required this.nbNonRetraits,
    required this.createdAt,
  });

  factory RetraitCartesHoraire.fromMap(Map<String, dynamic> m) => RetraitCartesHoraire(
        id: m['id']?.toString() ?? '',
        bureauId: m['bureau_id']?.toString() ?? '',
        agentCode: m['agent_code']?.toString() ?? '',
        dateSaisie: DateTime.tryParse(m['date_saisie']?.toString() ?? '') ?? DateTime.now(),
        heure: (m['heure'] as num?)?.toInt() ?? 0,
        nbRetraits: (m['nb_retraits'] as num?)?.toInt() ?? 0,
        nbNonRetraits: (m['nb_non_retraits'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse(m['created_at']?.toString() ?? '') ?? DateTime.now(),
      );
}
