-- Access is through the existing Firebase-authenticated backend only.
create table if not exists public.scan_history (
  owner_id text not null,
  id text not null,
  data jsonb not null,
  has_photo boolean not null default false,
  updated_at timestamptz not null default clock_timestamp(),
  primary key (owner_id, id)
);
alter table public.scan_history enable row level security;
revoke all on public.scan_history from anon, authenticated;
grant select, insert, update on public.scan_history to service_role;

-- Keep results immutable; late explanations and translations merge atomically.
create or replace function public.save_scan(p_owner text, p_id text, p_data jsonb)
returns void language plpgsql set search_path = public as $$
begin
  insert into scan_history(owner_id, id, data) values (p_owner, p_id, p_data)
  on conflict(owner_id, id) do update set data =
    scan_history.data || jsonb_build_object(
      'translations', coalesce(scan_history.data->'translations', '{}'::jsonb)
        || coalesce(excluded.data->'translations', '{}'::jsonb),
      'questions', (select jsonb_agg(q.value || case
        when excluded.data->'questions'->(q.ordinality::int-1)->'explanation' is not null
        then jsonb_build_object('explanation', excluded.data->'questions'->(q.ordinality::int-1)->'explanation')
        else '{}'::jsonb end order by q.ordinality)
        from jsonb_array_elements(scan_history.data->'questions') with ordinality q)
    );
end;
$$;
revoke all on function public.save_scan(text, text, jsonb) from public, anon, authenticated;
grant execute on function public.save_scan(text, text, jsonb) to service_role;

create index if not exists scan_history_updates on public.scan_history(owner_id, updated_at, id);
create or replace function public.touch_scan_history() returns trigger language plpgsql set search_path=public as $$
begin new.updated_at = clock_timestamp(); return new; end;
$$;
create trigger scan_history_updated before update on public.scan_history
for each row execute function public.touch_scan_history();
