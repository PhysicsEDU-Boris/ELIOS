-- Daily Guide progress (decision 0194). Only the Firebase-authenticated backend writes, with the
-- service role; anon/authenticated have no access. owner_id = Firebase uid (guests included).
create table if not exists public.guide_progress (
  owner_id text not null,
  date date not null,
  stops jsonb not null default '{}'::jsonb,   -- stop -> ISO time it was finished (story, physics, quiz, lab)
  quiz jsonb not null default '{}'::jsonb,
  lab jsonb not null default '{}'::jsonb,     -- verdict and reason only; frames are never stored
  xp int not null default 0,
  updated_at timestamptz not null default now(),
  primary key (owner_id, date)
);
create table if not exists public.guide_events (
  owner_id text not null,
  id text not null,
  date date not null,
  type text not null,
  created_at timestamptz not null default now(),
  unique (owner_id, id)
);
create index if not exists guide_events_lab on public.guide_events(owner_id, date, type, created_at);
create table if not exists public.lab_reviews (
  id bigint generated always as identity primary key,
  owner_id text not null,
  date date not null,
  verdict text not null,
  reason text,
  created_at timestamptz not null default now()
);
alter table public.guide_progress enable row level security;
alter table public.guide_events enable row level security;
alter table public.lab_reviews enable row level security;
revoke all on public.guide_progress, public.guide_events, public.lab_reviews from anon, authenticated;
grant select, insert, update on public.guide_progress, public.guide_events, public.lab_reviews to service_role;
