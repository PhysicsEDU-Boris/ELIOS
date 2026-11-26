-- Latest learning-tab snapshot per student (videos and clovers) for the ELIOS Insights dashboard.
-- Only the Firebase-authenticated backend writes it, with the service role. owner_id = Firebase uid.
create table if not exists public.learning_snapshots (
  owner_id text primary key,
  started_video_ids text[] not null default '{}',  -- every video the student opened (watched ones included)
  watched_video_ids text[] not null default '{}',  -- videos the app marked as completed
  clovers_earned int not null default 0,
  clovers_possible int not null default 0,
  updated_at timestamptz not null default now()
);
alter table public.learning_snapshots enable row level security;
revoke all on public.learning_snapshots from anon, authenticated;
grant select, insert, update on public.learning_snapshots to service_role;
