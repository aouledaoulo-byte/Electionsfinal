-- ============================================================
--  ELECTION APP — Schéma Supabase complet
--  2 candidats (A et B) · Français
--  Tables + Vues + RLS + Données de test
-- ============================================================

-- ── Extensions ──────────────────────────────────────────────
create extension if not exists "uuid-ossp";

-- ============================================================
--  1. TABLE : roles
-- ============================================================
create table if not exists roles (
  id   text primary key,  -- 'agent', 'superviseur_regional', 'superviseur_national'
  nom  text not null
);

insert into roles values
  ('agent',                  'Agent terrain'),
  ('superviseur_regional',   'Superviseur régional'),
  ('superviseur_national',   'Superviseur national')
on conflict do nothing;

-- ============================================================
--  2. TABLE : utilisateurs
-- ============================================================
create table if not exists utilisateurs (
  id          uuid primary key default uuid_generate_v4(),
  auth_id     uuid references auth.users(id) on delete cascade,
  code_unique text unique not null,   -- code de connexion agent
  nom         text not null,
  prenom      text,
  role        text references roles(id),
  region      text,                   -- pour superviseur_regional
  actif       boolean default true,
  created_at  timestamptz default now()
);

-- ============================================================
--  3. TABLE : bureaux
-- ============================================================
create table if not exists bureaux (
  id                  uuid primary key default uuid_generate_v4(),
  code                text unique not null,
  nom                 text not null,
  region              text not null,
  commune             text not null,
  centre              text not null,
  inscrits            integer not null default 0,
  ordre_mission       integer not null default 0,  -- rajouts OM
  ordonnance          integer not null default 0,  -- rajouts ordonnance
  agent_id            uuid references utilisateurs(id),
  actif               boolean default true,
  created_at          timestamptz default now()
);

-- Colonne calculée inscrits_corriges
alter table bureaux
  add column if not exists inscrits_corriges integer
  generated always as (inscrits + ordre_mission + ordonnance) stored;

-- ============================================================
--  4. TABLE : turnout_snapshots  (relevés LIVE horaires)
-- ============================================================
create table if not exists turnout_snapshots (
  id            uuid primary key default uuid_generate_v4(),
  bureau_id     uuid references bureaux(id) on delete cascade,
  heure         integer not null check (heure between 7 and 18),  -- 7 = 07h, 18 = 18h
  votants       integer not null check (votants >= 0),
  saisi_par     uuid references utilisateurs(id),
  statut        text default 'soumis' check (statut in ('soumis','valide','rejete')),
  valide_par    uuid references utilisateurs(id),
  note_rejet    text,
  offline       boolean default false,  -- saisi hors ligne
  synced_at     timestamptz,
  created_at    timestamptz default now(),
  unique(bureau_id, heure)              -- 1 relevé max par bureau par heure
);

-- ============================================================
--  5. TABLE : pv_results  (PV final après dépouillement)
-- ============================================================
create table if not exists pv_results (
  id              uuid primary key default uuid_generate_v4(),
  bureau_id       uuid references bureaux(id) on delete cascade unique,
  votants         integer not null check (votants >= 0),
  nuls            integer not null check (nuls >= 0),
  voix_a          integer not null check (voix_a >= 0),
  voix_b          integer not null check (voix_b >= 0),
  photo_url       text,                -- URL photo PV obligatoire
  statut          text default 'soumis' check (statut in ('soumis','valide','rejete')),
  saisi_par       uuid references utilisateurs(id),
  valide_par      uuid references utilisateurs(id),
  note_rejet      text,
  offline         boolean default false,
  synced_at       timestamptz,
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);

-- ============================================================
--  6. VUES ANALYTIQUES
-- ============================================================

-- ── Vue : KPI PV national ────────────────────────────────────
create or replace view kpi_pv_national as
select
  count(b.id)                                           as total_bureaux,
  sum(b.inscrits)                                       as total_inscrits,
  sum(b.ordre_mission + b.ordonnance)                   as total_rajouts,
  sum(b.inscrits_corriges)                              as total_inscrits_corriges,
  coalesce(sum(p.votants) filter (where p.statut='valide'), 0)    as total_votants,
  coalesce(sum(p.nuls)    filter (where p.statut='valide'), 0)    as total_nuls,
  coalesce(sum(p.voix_a)  filter (where p.statut='valide'), 0)    as total_voix_a,
  coalesce(sum(p.voix_b)  filter (where p.statut='valide'), 0)    as total_voix_b,
  count(p.id) filter (where p.statut='valide')          as pv_valides,
  count(p.id) filter (where p.statut='soumis')          as pv_soumis,
  count(p.id) filter (where p.statut='rejete')          as pv_rejetes,
  count(b.id) - count(p.id)                             as pv_manquants,
  round(count(p.id) filter (where p.statut='valide') * 100.0 / nullif(count(b.id),0), 2) as pct_couverture_pv,
  -- Calculs participation
  round(coalesce(sum(p.votants) filter (where p.statut='valide'),0) * 100.0 / nullif(sum(b.inscrits),0), 2)            as taux_participation_inscrits,
  round(coalesce(sum(p.votants) filter (where p.statut='valide'),0) * 100.0 / nullif(sum(b.inscrits_corriges),0), 2)   as taux_participation_corriges,
  -- Calculs candidats
  round(coalesce(sum(p.voix_a) filter (where p.statut='valide'),0) * 100.0 / nullif(sum(p.voix_a+p.voix_b) filter (where p.statut='valide'),0), 2) as pct_candidat_a,
  round(coalesce(sum(p.voix_b) filter (where p.statut='valide'),0) * 100.0 / nullif(sum(p.voix_a+p.voix_b) filter (where p.statut='valide'),0), 2) as pct_candidat_b
from bureaux b
left join pv_results p on p.bureau_id = b.id
where b.actif = true;

-- ── Vue : KPI PV par région ──────────────────────────────────
create or replace view kpi_pv_by_region as
select
  b.region,
  count(b.id)                                           as total_bureaux,
  sum(b.inscrits)                                       as total_inscrits,
  sum(b.inscrits_corriges)                              as total_inscrits_corriges,
  coalesce(sum(p.votants) filter (where p.statut='valide'), 0)   as total_votants,
  coalesce(sum(p.voix_a)  filter (where p.statut='valide'), 0)   as total_voix_a,
  coalesce(sum(p.voix_b)  filter (where p.statut='valide'), 0)   as total_voix_b,
  count(p.id) filter (where p.statut='valide')          as pv_valides,
  count(b.id) - count(p.id)                             as pv_manquants,
  round(count(p.id) filter (where p.statut='valide') * 100.0 / nullif(count(b.id),0), 2) as pct_couverture,
  round(coalesce(sum(p.votants) filter (where p.statut='valide'),0) * 100.0 / nullif(sum(b.inscrits_corriges),0), 2)  as taux_participation,
  round(coalesce(sum(p.voix_a)  filter (where p.statut='valide'),0) * 100.0 / nullif(sum(p.voix_a+p.voix_b) filter (where p.statut='valide'),0), 2) as pct_a,
  round(coalesce(sum(p.voix_b)  filter (where p.statut='valide'),0) * 100.0 / nullif(sum(p.voix_a+p.voix_b) filter (where p.statut='valide'),0), 2) as pct_b
from bureaux b
left join pv_results p on p.bureau_id = b.id
where b.actif = true
group by b.region;

-- ── Vue : Heatmap par commune ────────────────────────────────
create or replace view heatmap_pv_commune as
select
  b.region, b.commune,
  count(b.id)                                                      as total_bureaux,
  count(p.id) filter (where p.statut='valide')                     as pv_valides,
  count(b.id) - count(p.id)                                        as pv_manquants,
  round(count(p.id) filter (where p.statut='valide') * 100.0 / nullif(count(b.id),0), 2) as pct_couverture,
  round(coalesce(sum(p.votants) filter (where p.statut='valide'),0) * 100.0 / nullif(sum(b.inscrits_corriges),0), 2) as taux_participation
from bureaux b
left join pv_results p on p.bureau_id = b.id
where b.actif = true
group by b.region, b.commune;

-- ── Vue : Heatmap par centre ─────────────────────────────────
create or replace view heatmap_pv_centre as
select
  b.region, b.commune, b.centre,
  count(b.id)                                                       as total_bureaux,
  count(p.id) filter (where p.statut='valide')                      as pv_valides,
  count(b.id) - count(p.id)                                         as pv_manquants,
  round(count(p.id) filter (where p.statut='valide') * 100.0 / nullif(count(b.id),0), 2) as pct_couverture,
  round(coalesce(sum(p.votants) filter (where p.statut='valide'),0) * 100.0 / nullif(sum(b.inscrits_corriges),0), 2) as taux_participation
from bureaux b
left join pv_results p on p.bureau_id = b.id
where b.actif = true
group by b.region, b.commune, b.centre;

-- ── Vue : Couverture LIVE par heure ─────────────────────────
create or replace view kpi_live_coverage_by_hour as
select
  h.heure,
  count(b.id)                                           as total_bureaux,
  count(t.id)                                           as bureaux_avec_releve,
  count(t.id) filter (where t.statut='valide')          as bureaux_valides,
  round(count(t.id) * 100.0 / nullif(count(b.id),0), 2) as pct_couverture,
  coalesce(sum(t.votants) filter (where t.statut='valide'), 0) as total_votants,
  round(coalesce(sum(t.votants) filter (where t.statut='valide'),0) * 100.0 / nullif(sum(b.inscrits_corriges),0), 2) as taux_participation
from generate_series(7,18) as h(heure)
cross join bureaux b
left join turnout_snapshots t on t.bureau_id = b.id and t.heure = h.heure
where b.actif = true
group by h.heure
order by h.heure;

-- ── Vue : Comparaison LIVE 18h vs PV ────────────────────────
create or replace view v_compare_live18_pv as
select
  b.id, b.code, b.nom, b.region, b.commune, b.centre,
  b.inscrits_corriges,
  t18.votants                                           as live18_votants,
  p.votants                                             as pv_votants,
  p.votants - t18.votants                               as ecart_votants,
  round((p.votants - t18.votants) * 100.0 / nullif(t18.votants,0), 2) as ecart_pct,
  case
    when abs(p.votants - t18.votants) > b.inscrits_corriges * 0.1 then 'CRITIQUE'
    when abs(p.votants - t18.votants) > b.inscrits_corriges * 0.05 then 'WARNING'
    else 'OK'
  end as niveau_alerte
from bureaux b
left join turnout_snapshots t18 on t18.bureau_id = b.id and t18.heure = 18 and t18.statut = 'valide'
left join pv_results p on p.bureau_id = b.id and p.statut = 'valide'
where b.actif = true and (t18.id is not null or p.id is not null);

-- ── Vue : Audit anomalies PV ─────────────────────────────────
create or replace view v_audit_pv_anomalies as
select
  b.id, b.code, b.nom, b.region, b.commune, b.centre,
  b.inscrits_corriges,
  p.votants, p.nuls, p.voix_a, p.voix_b,
  p.voix_a + p.voix_b                                    as exprimes,
  p.photo_url,
  -- Anomalies CRITIQUE
  case when p.votants > b.inscrits_corriges then true else false end  as anomalie_votants_sup_inscrits,
  case when p.votants != (p.voix_a + p.voix_b + p.nuls) then true else false end as anomalie_total_incorrect,
  -- Anomalies WARNING
  case when p.nuls * 1.0 / nullif(p.votants,0) > 0.15 then true else false end  as anomalie_nuls_eleves,
  case when (p.voix_a + p.voix_b) = 0 and p.votants > 0 then true else false end as anomalie_zero_exprimes,
  case when p.photo_url is null or p.photo_url = '' then true else false end      as anomalie_photo_manquante,
  -- Niveau global
  case
    when p.votants > b.inscrits_corriges
      or p.votants != (p.voix_a + p.voix_b + p.nuls)    then 'CRITIQUE'
    when p.nuls * 1.0 / nullif(p.votants,0) > 0.15
      or (p.voix_a + p.voix_b) = 0 and p.votants > 0
      or p.photo_url is null                             then 'WARNING'
    else 'OK'
  end as niveau_anomalie
from bureaux b
join pv_results p on p.bureau_id = b.id
where b.actif = true and p.statut = 'valide';

-- ============================================================
--  7. ROW LEVEL SECURITY (RLS)
-- ============================================================

alter table utilisateurs        enable row level security;
alter table bureaux             enable row level security;
alter table turnout_snapshots   enable row level security;
alter table pv_results          enable row level security;

-- Fonction utilitaire : récupérer le rôle de l'utilisateur connecté
create or replace function get_user_role()
returns text language sql security definer as $$
  select role from utilisateurs where auth_id = auth.uid() limit 1;
$$;

create or replace function get_user_region()
returns text language sql security definer as $$
  select region from utilisateurs where auth_id = auth.uid() limit 1;
$$;

create or replace function get_user_id()
returns uuid language sql security definer as $$
  select id from utilisateurs where auth_id = auth.uid() limit 1;
$$;

-- ── Politiques : utilisateurs ────────────────────────────────
create policy "utilisateurs_select_own"
  on utilisateurs for select
  using (auth_id = auth.uid() or get_user_role() in ('superviseur_regional','superviseur_national'));

-- ── Politiques : bureaux ─────────────────────────────────────
-- Agent : seulement ses bureaux
create policy "bureaux_agent"
  on bureaux for select
  using (
    get_user_role() = 'superviseur_national'
    or (get_user_role() = 'superviseur_regional' and region = get_user_region())
    or (get_user_role() = 'agent' and agent_id = get_user_id())
  );

-- ── Politiques : turnout_snapshots ───────────────────────────
create policy "snapshots_select"
  on turnout_snapshots for select
  using (
    get_user_role() = 'superviseur_national'
    or (get_user_role() = 'superviseur_regional' and
        bureau_id in (select id from bureaux where region = get_user_region()))
    or (get_user_role() = 'agent' and saisi_par = get_user_id())
  );

create policy "snapshots_insert"
  on turnout_snapshots for insert
  with check (
    get_user_role() = 'agent'
    and saisi_par = get_user_id()
    and bureau_id in (select id from bureaux where agent_id = get_user_id())
  );

create policy "snapshots_update_superviseur"
  on turnout_snapshots for update
  using (
    get_user_role() in ('superviseur_regional','superviseur_national')
  );

-- ── Politiques : pv_results ──────────────────────────────────
create policy "pv_select"
  on pv_results for select
  using (
    get_user_role() = 'superviseur_national'
    or (get_user_role() = 'superviseur_regional' and
        bureau_id in (select id from bureaux where region = get_user_region()))
    or (get_user_role() = 'agent' and saisi_par = get_user_id())
  );

create policy "pv_insert"
  on pv_results for insert
  with check (
    get_user_role() = 'agent'
    and saisi_par = get_user_id()
    and bureau_id in (select id from bureaux where agent_id = get_user_id())
  );

create policy "pv_update"
  on pv_results for update
  using (
    (get_user_role() = 'agent' and saisi_par = get_user_id() and statut = 'soumis')
    or get_user_role() in ('superviseur_regional','superviseur_national')
  );

-- ── Storage : photos PV ──────────────────────────────────────
insert into storage.buckets (id, name, public)
values ('pv-photos', 'pv-photos', false)
on conflict do nothing;

create policy "pv_photos_upload"
  on storage.objects for insert
  with check (bucket_id = 'pv-photos' and get_user_role() = 'agent');

create policy "pv_photos_read"
  on storage.objects for select
  using (bucket_id = 'pv-photos' and get_user_role() is not null);

-- ============================================================
--  8. DONNÉES DE TEST
-- ============================================================

-- Bureaux de test (3 régions, 2 communes par région)
insert into bureaux (code, nom, region, commune, centre, inscrits, ordre_mission, ordonnance) values
  ('BV-001', 'Bureau 1', 'Région Nord',  'Commune A', 'Centre Alpha',  850, 12, 5),
  ('BV-002', 'Bureau 2', 'Région Nord',  'Commune A', 'Centre Alpha',  720, 8,  3),
  ('BV-003', 'Bureau 3', 'Région Nord',  'Commune B', 'Centre Beta',   930, 15, 7),
  ('BV-004', 'Bureau 4', 'Région Sud',   'Commune C', 'Centre Gamma',  640, 6,  2),
  ('BV-005', 'Bureau 5', 'Région Sud',   'Commune C', 'Centre Gamma',  780, 10, 4),
  ('BV-006', 'Bureau 6', 'Région Sud',   'Commune D', 'Centre Delta',  550, 5,  1),
  ('BV-007', 'Bureau 7', 'Région Est',   'Commune E', 'Centre Epsilon',900, 14, 6),
  ('BV-008', 'Bureau 8', 'Région Est',   'Commune E', 'Centre Epsilon',670, 9,  3),
  ('BV-009', 'Bureau 9', 'Région Est',   'Commune F', 'Centre Zeta',   810, 11, 5),
  ('BV-010', 'Bureau 10','Région Est',   'Commune F', 'Centre Zeta',   760, 7,  2)
on conflict do nothing;

-- ============================================================
--  FIN DU SCRIPT
-- ============================================================
-- Instructions :
-- 1. Aller sur https://supabase.com → nouveau projet
-- 2. SQL Editor → New query → coller ce script → Run
-- 3. Copier votre Project URL et anon key dans l'app Flutter
-- ============================================================
