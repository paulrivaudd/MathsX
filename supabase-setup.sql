-- MathsX : schéma Supabase complet (profils + scores)
-- Historique : la table scores a d'abord été créée avec une colonne pseudo,
-- remplacée ensuite par la table profiles (pseudos uniques). Ce fichier
-- reflète l'état final ; la migration exécutée est en bas de fichier.

-- Table des profils : un pseudo unique par joueur (insensible à la casse)
create table public.profiles (
  user_id uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  pseudo text not null check (char_length(pseudo) between 2 and 16),
  created_at timestamptz not null default now()
);

create unique index profiles_pseudo_unique on public.profiles (lower(pseudo));

alter table public.profiles enable row level security;

create policy "lecture publique profils"
  on public.profiles for select
  using (true);

create policy "insertion de son profil"
  on public.profiles for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "modification de son profil"
  on public.profiles for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Table des scores (le pseudo vient de profiles via la clé étrangère)
create table public.scores (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references public.profiles (user_id) on delete cascade,
  mode text not null check (mode in ('classic', 'timed', 'survival')),
  op text not null check (op in ('add', 'sub', 'mul', 'div', 'all')),
  diff text not null check (diff in ('easy', 'medium', 'hard', 'goat')),
  score integer not null check (score between 0 and 500),
  time_s real,
  created_at timestamptz not null default now()
);

alter table public.scores enable row level security;

create policy "lecture publique"
  on public.scores for select
  using (true);

create policy "insertion par son proprietaire"
  on public.scores for insert
  to authenticated
  with check (auth.uid() = user_id);

create index scores_board_idx
  on public.scores (mode, op, diff, score desc, time_s asc);

-- ============================================================
-- Migration exécutée le 2026-07-02 (scores.pseudo -> profiles)
-- ============================================================
-- create table public.profiles (... comme ci-dessus ...);
-- truncate table public.scores;
-- alter table public.scores drop column pseudo;
-- alter table public.scores
--   add constraint scores_profiles_fk
--   foreign key (user_id) references public.profiles (user_id) on delete cascade;
