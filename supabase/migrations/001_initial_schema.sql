-- Tiffin Tracker: Initial Supabase PostgreSQL Schema, Triggers, RPCs & RLS
-- Matches context.md + Phase 1 MVP requirements:
--   - Price Snapshotting on tiffin_logs
--   - Single active Space per user + 2-day (48h) join cooldown on leave
--   - Strict Row Level Security (RLS) & Space-scoped Realtime

create extension if not exists pgcrypto;

-- ============================================================================
-- 1. TABLES
-- ============================================================================

create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  avatar_url text,
  last_left_space_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.spaces (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) > 0),
  invite_code text not null unique check (invite_code ~ '^[0-9]{6}$'),
  leader_id uuid not null references public.users(id),
  price_full numeric(10, 2) not null check (price_full >= 0),
  price_half numeric(10, 2) not null check (price_half >= 0),
  cutoff_time time not null default '11:00:00',
  created_at timestamptz not null default now()
);

create table if not exists public.space_members (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.spaces(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  role text not null check (role in ('leader', 'member')),
  joined_at timestamptz not null default now(),
  constraint space_members_space_user_unique unique (space_id, user_id),
  constraint space_members_single_active_space unique (user_id)
);

create table if not exists public.tiffin_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  space_id uuid not null references public.spaces(id) on delete cascade,
  log_date date not null,
  type text not null check (type in ('full', 'half', 'skip')),
  cost numeric(10, 2) not null default 0 check (cost >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint tiffin_logs_daily_unique unique (user_id, space_id, log_date)
);

-- Ensure Phase 1 columns & constraints exist if tables predated this script.
alter table public.users
  add column if not exists full_name text not null default '',
  add column if not exists avatar_url text,
  add column if not exists last_left_space_at timestamptz,
  add column if not exists created_at timestamptz not null default now();

alter table public.spaces
  add column if not exists cutoff_time time not null default '11:00:00',
  add column if not exists created_at timestamptz not null default now();

alter table public.tiffin_logs
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'space_members_single_active_space'
      and conrelid = 'public.space_members'::regclass
  ) then
    alter table public.space_members
      add constraint space_members_single_active_space unique (user_id);
  end if;
exception
  when unique_violation then
    raise notice 'Skipped space_members_single_active_space: duplicate user_id rows exist.';
end $$;

create index if not exists idx_space_members_space_id
  on public.space_members(space_id);

create index if not exists idx_tiffin_logs_space_date
  on public.tiffin_logs(space_id, log_date);

create index if not exists idx_tiffin_logs_user_space_date
  on public.tiffin_logs(user_id, space_id, log_date);

-- ============================================================================
-- 2. AUTH & INTEGRITY TRIGGERS
-- ============================================================================

create or replace function public.ensure_user_profile(p_uid uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (id, full_name, avatar_url)
  select
    u.id,
    coalesce(
      nullif(trim(u.raw_user_meta_data ->> 'full_name'), ''),
      nullif(split_part(coalesce(u.email, ''), '@', 1), ''),
      'Colleague'
    ),
    u.raw_user_meta_data ->> 'avatar_url'
  from auth.users u
  where u.id = p_uid
  on conflict (id) do nothing;
end;
$$;

revoke all on function public.ensure_user_profile(uuid) from public;

-- Automatically create a public.users row when a user signs up in auth.users.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (id, full_name, avatar_url)
  values (
    new.id,
    coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
      nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
      'Colleague'
    ),
    new.raw_user_meta_data ->> 'avatar_url'
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Backfill any pre-existing auth.users rows missing from public.users.
insert into public.users (id, full_name, avatar_url)
select
  u.id,
  coalesce(
    nullif(trim(u.raw_user_meta_data ->> 'full_name'), ''),
    nullif(split_part(coalesce(u.email, ''), '@', 1), ''),
    'Colleague'
  ),
  u.raw_user_meta_data ->> 'avatar_url'
from auth.users u
on conflict (id) do nothing;

-- Prevent direct client edits to protected cooldown timestamp on public.users.
create or replace function public.protect_user_cooldown_column()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if current_user in ('authenticated', 'anon')
     and new.last_left_space_at is distinct from old.last_left_space_at then
    raise exception 'last_left_space_at is system-managed and cannot be edited directly.';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_protect_user_cooldown on public.users;
create trigger trg_protect_user_cooldown
  before update on public.users
  for each row execute function public.protect_user_cooldown_column();

-- Snapshot price on tiffin_logs from spaces at log time and guard past logs.
create or replace function public.snapshot_tiffin_log_cost()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_price_full numeric(10, 2);
  v_price_half numeric(10, 2);
begin
  if tg_op = 'UPDATE' and new.log_date is distinct from old.log_date then
    raise exception 'log_date cannot be modified.';
  end if;

  -- Allow +/- 1 day around Postgres UTC current_date to accommodate local timezones (e.g. IST).
  if abs(new.log_date - current_date) > 1 then
    raise exception 'Past tiffin logs are read-only and cannot be modified.';
  end if;

  select s.price_full, s.price_half
  into v_price_full, v_price_half
  from public.spaces s
  where s.id = new.space_id;

  if not found then
    raise exception 'Space not found.';
  end if;

  new.cost := case new.type
    when 'full' then v_price_full
    when 'half' then v_price_half
    when 'skip' then 0
  end;

  if tg_op = 'UPDATE' then
    new.created_at := old.created_at;
  end if;
  new.updated_at := now();

  return new;
end;
$$;

drop trigger if exists trg_snapshot_tiffin_log_cost on public.tiffin_logs;
create trigger trg_snapshot_tiffin_log_cost
  before insert or update on public.tiffin_logs
  for each row execute function public.snapshot_tiffin_log_cost();

-- ============================================================================
-- 3. RLS HELPER FUNCTIONS
-- ============================================================================

create or replace function public.is_space_member(p_space_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.space_members sm
    where sm.space_id = p_space_id
      and sm.user_id = auth.uid()
  );
$$;

create or replace function public.shares_space_with(p_other_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_other_user_id = auth.uid()
    or exists (
      select 1
      from public.space_members me
      join public.space_members other
        on me.space_id = other.space_id
      where me.user_id = auth.uid()
        and other.user_id = p_other_user_id
    );
$$;

-- ============================================================================
-- 4. SPACE LIFECYCLE RPCS (ATOMIC & COOLDOWN-SAFE)
-- ============================================================================

create or replace function public.generate_unique_invite_code()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text;
  v_attempts int := 0;
begin
  loop
    v_attempts := v_attempts + 1;
    v_code := lpad((floor(random() * 1000000))::int::text, 6, '0');
    exit when not exists (
      select 1 from public.spaces where invite_code = v_code
    );
    if v_attempts >= 25 then
      raise exception 'Unable to generate a unique invite code. Please try again.';
    end if;
  end loop;

  return v_code;
end;
$$;

create or replace function public.create_space(
  p_name text,
  p_price_full numeric,
  p_price_half numeric,
  p_cutoff_time time default '11:00:00'
)
returns public.spaces
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_space public.spaces;
begin
  if v_uid is null then
    raise exception 'Authentication required.';
  end if;

  if char_length(trim(coalesce(p_name, ''))) = 0 then
    raise exception 'Space name cannot be empty.';
  end if;

  if p_price_full < 0 or p_price_half < 0 then
    raise exception 'Prices cannot be negative.';
  end if;

  -- Defensive profile check in case user predates auth trigger.
  perform public.ensure_user_profile(v_uid);

  if exists (select 1 from public.space_members where user_id = v_uid) then
    raise exception 'You are already a member of a space. Leave your current space first.';
  end if;

  insert into public.spaces (name, invite_code, leader_id, price_full, price_half, cutoff_time)
  values (
    trim(p_name),
    public.generate_unique_invite_code(),
    v_uid,
    round(p_price_full, 2),
    round(p_price_half, 2),
    coalesce(p_cutoff_time, '11:00:00')
  )
  returning * into v_space;

  insert into public.space_members (space_id, user_id, role)
  values (v_space.id, v_uid, 'leader');

  return v_space;
end;
$$;

create or replace function public.join_space_by_code(p_invite_code text)
returns public.spaces
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_code text := trim(coalesce(p_invite_code, ''));
  v_last_left timestamptz;
  v_unlock_at timestamptz;
  v_space public.spaces;
begin
  if v_uid is null then
    raise exception 'Authentication required.';
  end if;

  if v_code !~ '^[0-9]{6}$' then
    raise exception 'Please enter a valid 6-digit invite code.';
  end if;

  perform public.ensure_user_profile(v_uid);

  if exists (select 1 from public.space_members where user_id = v_uid) then
    raise exception 'You are already a member of a space.';
  end if;

  select u.last_left_space_at
  into v_last_left
  from public.users u
  where u.id = v_uid;

  if v_last_left is not null then
    v_unlock_at := v_last_left + interval '2 days';
    if now() < v_unlock_at then
      raise exception 'COOLDOWN_ACTIVE:%', to_char(v_unlock_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"');
    end if;
  end if;

  select *
  into v_space
  from public.spaces s
  where s.invite_code = v_code;

  if not found then
    raise exception 'No space found for invite code %.', v_code;
  end if;

  insert into public.space_members (space_id, user_id, role)
  values (v_space.id, v_uid, 'member');

  return v_space;
end;
$$;

create or replace function public.transfer_leadership(p_new_leader_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_space_id uuid;
begin
  if v_uid is null then
    raise exception 'Authentication required.';
  end if;

  select sm.space_id
  into v_space_id
  from public.space_members sm
  where sm.user_id = v_uid
    and sm.role = 'leader';

  if not found then
    raise exception 'Only the current space leader can transfer leadership.';
  end if;

  if p_new_leader_id = v_uid then
    raise exception 'You are already the space leader.';
  end if;

  if not exists (
    select 1
    from public.space_members sm
    where sm.space_id = v_space_id
      and sm.user_id = p_new_leader_id
  ) then
    raise exception 'Selected colleague is not a member of this space.';
  end if;

  update public.spaces
  set leader_id = p_new_leader_id
  where id = v_space_id;

  update public.space_members
  set role = 'member'
  where space_id = v_space_id and user_id = v_uid;

  update public.space_members
  set role = 'leader'
  where space_id = v_space_id and user_id = p_new_leader_id;
end;
$$;

create or replace function public.leave_space()
returns timestamptz
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_space_id uuid;
  v_role text;
  v_member_count int;
  v_left_at timestamptz := now();
begin
  if v_uid is null then
    raise exception 'Authentication required.';
  end if;

  select sm.space_id, sm.role
  into v_space_id, v_role
  from public.space_members sm
  where sm.user_id = v_uid;

  if not found then
    raise exception 'You are not currently in a space.';
  end if;

  select count(*)
  into v_member_count
  from public.space_members sm
  where sm.space_id = v_space_id;

  if v_role = 'leader' and v_member_count > 1 then
    raise exception 'Transfer leadership to another colleague before leaving this space.';
  end if;

  delete from public.space_members
  where space_id = v_space_id and user_id = v_uid;

  if v_role = 'leader' and v_member_count = 1 then
    delete from public.spaces where id = v_space_id;
  end if;

  update public.users
  set last_left_space_at = v_left_at
  where id = v_uid;

  return v_left_at + interval '2 days';
end;
$$;

grant execute on function public.create_space(text, numeric, numeric, time) to authenticated;
grant execute on function public.join_space_by_code(text) to authenticated;
grant execute on function public.transfer_leadership(uuid) to authenticated;
grant execute on function public.leave_space() to authenticated;

-- ============================================================================
-- 5. ROW LEVEL SECURITY (RLS)
-- ============================================================================

alter table public.users enable row level security;
alter table public.spaces enable row level security;
alter table public.space_members enable row level security;
alter table public.tiffin_logs enable row level security;

-- Remove all pre-existing policies on these 4 tables (e.g. older dashboard
-- policies like "Users can view members of their spaces" or "Users can join spaces")
-- before recreating the non-recursive SECURITY DEFINER policies below.
do $$
declare
  v_pol record;
begin
  for v_pol in
    select schemaname, tablename, policyname
    from pg_policies
    where schemaname = 'public'
      and tablename in ('users', 'spaces', 'space_members', 'tiffin_logs')
  loop
    execute format(
      'drop policy if exists %I on %I.%I',
      v_pol.policyname,
      v_pol.schemaname,
      v_pol.tablename
    );
  end loop;
end $$;

-- public.users
create policy users_select_space_or_self
  on public.users for select
  to authenticated
  using (id = auth.uid() or public.shares_space_with(id));

create policy users_update_self
  on public.users for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- public.spaces
create policy spaces_select_member
  on public.spaces for select
  to authenticated
  using (public.is_space_member(id));

create policy spaces_update_leader
  on public.spaces for update
  to authenticated
  using (leader_id = auth.uid() and public.is_space_member(id))
  with check (leader_id = auth.uid() and public.is_space_member(id));

-- public.space_members (reads only; mutations via security-definer RPCs)
create policy space_members_select_member
  on public.space_members for select
  to authenticated
  using (user_id = auth.uid() or public.is_space_member(space_id));

-- public.tiffin_logs
create policy tiffin_logs_select_space_member
  on public.tiffin_logs for select
  to authenticated
  using (public.is_space_member(space_id));

create policy tiffin_logs_insert_own
  on public.tiffin_logs for insert
  to authenticated
  with check (user_id = auth.uid() and public.is_space_member(space_id));

create policy tiffin_logs_update_own
  on public.tiffin_logs for update
  to authenticated
  using (user_id = auth.uid() and public.is_space_member(space_id))
  with check (user_id = auth.uid() and public.is_space_member(space_id));

create policy tiffin_logs_delete_own
  on public.tiffin_logs for delete
  to authenticated
  using (user_id = auth.uid() and public.is_space_member(space_id));

-- ============================================================================
-- 6. REALTIME PUBLICATION
-- ============================================================================

do $$
begin
  alter publication supabase_realtime add table public.tiffin_logs;
exception
  when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.space_members;
exception
  when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.spaces;
exception
  when duplicate_object then null;
end $$;

