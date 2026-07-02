-- MathsX : table des scores en ligne
-- À exécuter une seule fois dans Supabase (SQL Editor)

create table public.scores (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  pseudo text not null check (char_length(pseudo) between 2 and 16),
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
