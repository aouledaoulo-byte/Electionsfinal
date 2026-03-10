# ELECTION — Application Android
## Suivi électoral en temps réel · com.ynet.election

---

## 📁 Structure du projet

```
election_app/
├── lib/
│   ├── main.dart                          # Point d'entrée
│   ├── utils/constants.dart               # ⚠️ Mettre vos credentials Supabase ici
│   ├── models/models.dart                 # Modèles de données
│   ├── services/services.dart             # Auth + Data + Offline
│   └── screens/
│       ├── login_screen.dart              # Écran connexion
│       ├── agent/
│       │   ├── agent_home.dart            # Liste bureaux agent
│       │   └── agent_bureau_detail.dart   # Saisie LIVE + PV
│       └── superviseur/
│           ├── superviseur_home.dart      # Navigation superviseur
│           ├── dashboard_national.dart    # Résultats + candidats
│           ├── dashboard_live.dart        # Couverture horaire + Validation + Anomalies
│           └── ...
├── android/app/src/main/
│   └── AndroidManifest.xml
└── pubspec.yaml
```

---

## ⚙️ ÉTAPE 1 — Configurer Supabase

### 1.1 Créer le projet Supabase
1. Aller sur https://supabase.com
2. Cliquer **New project**
3. Choisir un nom : `election`
4. Choisir une région proche (ex: Europe West)
5. Définir un mot de passe de base de données

### 1.2 Exécuter le SQL
1. Dans Supabase → **SQL Editor** → **New query**
2. Copier le contenu de `supabase_schema.sql`
3. Cliquer **Run**

### 1.3 Récupérer vos credentials
Dans Supabase → **Settings** → **API** :
- **Project URL** : `https://xxxxx.supabase.co`
- **anon public key** : `eyJhbGci...`

### 1.4 Mettre à jour le code
Dans `lib/utils/constants.dart`, remplacer :
```dart
static const String supabaseUrl = 'https://VOTRE-PROJECT-ID.supabase.co';
static const String supabaseAnonKey = 'VOTRE-ANON-KEY';
```

---

## 📱 ÉTAPE 2 — Créer un utilisateur test

Dans Supabase → **Table Editor** → `utilisateurs` → **Insert row** :
```
code_unique : AGENT-001
nom         : Agent Test
role        : agent
actif       : true
```

Puis affecter ce agent à un bureau dans la table `bureaux` :
```sql
UPDATE bureaux SET agent_id = 'UUID-DE-AGENT-001' WHERE code = 'BV-001';
```

---

## 🚀 ÉTAPE 3 — Compiler avec Codemagic (depuis votre téléphone)

### 3.1 Uploader sur GitHub
1. Aller sur https://github.com (depuis votre navigateur)
2. **New repository** → nom : `election-app` → Public → Create
3. Cliquer **uploading an existing file**
4. Uploader tous les fichiers du projet

### 3.2 Compiler sur Codemagic
1. Aller sur https://codemagic.io
2. **Sign up with GitHub** (gratuit, 500 min/mois)
3. **Add application** → sélectionner `election-app`
4. **Flutter App** → choisir le repo
5. **Start your first build**
6. Attendre 10-15 minutes
7. Télécharger **app-release.apk**

### 3.3 Installer l'APK
1. Transférer l'APK sur votre téléphone Android
2. Paramètres → Sécurité → **Sources inconnues** : Autoriser
3. Ouvrir le fichier APK → Installer

---

## 👥 Rôles et codes de connexion

| Rôle | Code exemple | Accès |
|------|-------------|-------|
| Agent terrain | AGENT-001 | Ses bureaux uniquement |
| Superviseur régional | SUP-REG-01 | Tous les bureaux de sa région |
| Superviseur national | SUP-NAT-01 | Tout le pays |

---

## 📊 Fonctionnalités

### Agent terrain
- ✅ Connexion par code unique
- ✅ Liste de ses bureaux affectés
- ✅ Saisie relevé LIVE par heure (07h-18h)
- ✅ Calcul participation automatique
- ✅ Saisie PV final (votants, nuls, voix A, voix B)
- ✅ Photo du PV obligatoire
- ✅ Vérification cohérence (votants = nuls + A + B)

### Superviseur
- ✅ Dashboard national avec résultats
- ✅ Graphique candidats A vs B (camembert)
- ✅ Couverture LIVE par heure
- ✅ Validation / rejet des PV
- ✅ Détection anomalies automatique

---

## 🔒 Sécurité (RLS Supabase)
- Agent : accès uniquement à ses bureaux
- Superviseur régional : accès à sa région
- Superviseur national : accès total
- Photos PV : stockage privé

---

## ⚠️ Support
Pour toute question, contactez votre administrateur système.
