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
  op text not null check (op in ('add', 'sub', 'mul', 'div', 'all', 'chain', 'seq')),
  diff text not null check (diff in ('easy', 'medium', 'hard', 'goat')),
  score integer not null check (score between 0 and 500),
  time_s real,
  attempts integer check (attempts between 1 and 1000),
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

-- ============================================================
-- Migration du 2026-07-04 (épreuves Cascade et Suites)
-- ============================================================
-- alter table public.scores drop constraint scores_op_check;
-- alter table public.scores add constraint scores_op_check
--   check (op in ('add', 'sub', 'mul', 'div', 'all', 'chain', 'seq'));

-- ============================================================
-- Classement général (vue) + précision par partie
-- Points = somme des meilleurs scores par catégorie,
-- pondérés par difficulté (easy 1, medium 2, hard 4, goat 8)
-- ============================================================

-- Migration : alter table public.scores add column attempts integer check (attempts between 1 and 1000);

create or replace view public.leaderboard_general
with (security_invoker = on) as
select
  b.user_id,
  p.pseudo,
  sum(b.best_score * b.w)::int as points,
  count(*)::int as categories
from (
  select
    user_id, mode, op, diff,
    max(score) as best_score,
    case diff when 'easy' then 1 when 'medium' then 2 when 'hard' then 4 else 8 end as w
  from public.scores
  group by user_id, mode, op, diff
) b
join public.profiles p on p.user_id = b.user_id
group by b.user_id, p.pseudo;
