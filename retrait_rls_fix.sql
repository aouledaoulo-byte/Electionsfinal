-- RLS simplifié sans get_user_role()
-- La table est déjà créée, on ajoute juste les politiques

-- Supprimer les anciennes politiques si elles existent
drop policy if exists "rc_select" on retrait_cartes;
drop policy if exists "rc_insert" on retrait_cartes;
drop policy if exists "rc_update" on retrait_cartes;
drop policy if exists "rc_delete" on retrait_cartes;

-- Politique simple : accès à tous les utilisateurs authentifiés
create policy "rc_select" on retrait_cartes
  for select using (auth.role() = 'authenticated' or auth.role() = 'anon');

create policy "rc_insert" on retrait_cartes
  for insert with check (true);

create policy "rc_update" on retrait_cartes
  for update using (true);

create policy "rc_delete" on retrait_cartes
  for delete using (true);

-- Vérification
select 'Table retrait_cartes OK' as status;
