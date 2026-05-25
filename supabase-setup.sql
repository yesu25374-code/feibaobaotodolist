create table if not exists public.xiaoxiaoyu_sync (
  sync_code text primary key,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.xiaoxiaoyu_sync enable row level security;

drop policy if exists "xiaoxiaoyu sync deny read" on public.xiaoxiaoyu_sync;
drop policy if exists "xiaoxiaoyu sync deny insert" on public.xiaoxiaoyu_sync;
drop policy if exists "xiaoxiaoyu sync deny update" on public.xiaoxiaoyu_sync;
drop function if exists public.xiaoxiaoyu_pull(text);
drop function if exists public.xiaoxiaoyu_push(text, jsonb, timestamptz);

create policy "xiaoxiaoyu sync deny read"
on public.xiaoxiaoyu_sync
for select
to anon
using (false);

create policy "xiaoxiaoyu sync deny insert"
on public.xiaoxiaoyu_sync
for insert
to anon
with check (false);

create policy "xiaoxiaoyu sync deny update"
on public.xiaoxiaoyu_sync
for update
to anon
using (false)
with check (false);

create or replace function public.xiaoxiaoyu_pull(p_sync_code text)
returns table(data jsonb, updated_at timestamptz)
language sql
security definer
set search_path = public
as $$
  select s.data, s.updated_at
  from public.xiaoxiaoyu_sync s
  where s.sync_code = p_sync_code
  limit 1;
$$;

create or replace function public.xiaoxiaoyu_push(
  p_sync_code text,
  p_data jsonb,
  p_updated_at timestamptz
)
returns table(data jsonb, updated_at timestamptz)
language sql
security definer
set search_path = public
as $$
  insert into public.xiaoxiaoyu_sync(sync_code, data, updated_at)
  values (p_sync_code, p_data, coalesce(p_updated_at, now()))
  on conflict (sync_code)
  do update set
    data = excluded.data,
    updated_at = excluded.updated_at
  returning xiaoxiaoyu_sync.data, xiaoxiaoyu_sync.updated_at;
$$;

revoke all on public.xiaoxiaoyu_sync from anon, authenticated;
grant execute on function public.xiaoxiaoyu_pull(text) to anon;
grant execute on function public.xiaoxiaoyu_push(text, jsonb, timestamptz) to anon;
