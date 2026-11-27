
-- ============================================================
-- SETTLIV SET 2
-- Per-user PostgreSQL ledger schema
-- Strict Row Level Security
-- Atomic settlement RPC functions
-- ============================================================

-- 1. PEOPLE
create table if not exists public.people (
  user_id uuid not null references auth.users(id) on delete cascade,
  id text not null,
  name text not null,
  upi_id text,
  phone text,
  is_current_user boolean not null default false,
  schema_version integer not null default 2,
  updated_at_ms bigint not null,
  primary key (user_id, id)
);

-- 2. GROUPS
create table if not exists public.groups (
  user_id uuid not null references auth.users(id) on delete cascade,
  id text not null,
  name text not null,
  type text not null,
  cover_type text not null,
  member_ids jsonb not null default '[]'::jsonb,
  is_personal boolean not null default false,
  is_pinned boolean not null default false,
  is_archived boolean not null default false,
  default_split_mode text not null default 'equal',
  trip_start_ms bigint,
  trip_end_ms bigint,
  schema_version integer not null default 2,
  updated_at_ms bigint not null,
  primary key (user_id, id)
);

-- 3. EXPENSES
create table if not exists public.expenses (
  user_id uuid not null references auth.users(id) on delete cascade,
  id text not null,
  group_id text not null,
  title text not null,
  total_paise bigint not null,
  paid_by text not null,
  payers jsonb not null default '[]'::jsonb,
  split_mode text not null,
  shares jsonb not null default '{}'::jsonb,
  category text not null,
  date_ms bigint not null,
  notes text,
  is_recurring boolean not null default false,
  deleted_at_ms bigint,
  revisions jsonb not null default '[]'::jsonb,
  schema_version integer not null default 2,
  updated_at_ms bigint not null,
  primary key (user_id, id),
  foreign key (user_id, group_id)
    references public.groups(user_id, id)
    on delete cascade
);

create index if not exists idx_expenses_user_date
  on public.expenses(user_id, date_ms desc);

-- 4. SETTLEMENTS
create table if not exists public.settlements (
  user_id uuid not null references auth.users(id) on delete cascade,
  id text not null,
  group_id text not null,
  from_id text not null,
  to_id text not null,
  paise bigint not null,
  method text not null default 'upi',
  date_ms bigint not null,
  deleted_at_ms bigint,
  note text,
  schema_version integer not null default 2,
  updated_at_ms bigint not null,
  primary key (user_id, id),
  foreign key (user_id, group_id)
    references public.groups(user_id, id)
    on delete cascade
);

create index if not exists idx_settlements_user_date
  on public.settlements(user_id, date_ms desc);

-- 5. IOUS
create table if not exists public.ious (
  user_id uuid not null references auth.users(id) on delete cascade,
  id text not null,
  direction text not null,
  person_name text not null,
  phone text,
  amount_paise bigint not null,
  remaining_paise bigint not null,
  note text not null default '',
  due_date_ms bigint,
  created_at_ms bigint not null,
  payments jsonb not null default '[]'::jsonb,
  deleted_at_ms bigint,
  schema_version integer not null default 2,
  updated_at_ms bigint not null,
  primary key (user_id, id)
);

-- 6. RECURRING
create table if not exists public.recurring (
  user_id uuid not null references auth.users(id) on delete cascade,
  id text not null,
  group_id text not null,
  title text not null,
  amount_paise bigint not null,
  paid_by text not null,
  split_mode text not null,
  shares jsonb not null default '{}'::jsonb,
  category text not null,
  frequency text not null,
  next_due_ms bigint not null,
  last_generated_ms bigint,
  is_paused boolean not null default false,
  schema_version integer not null default 2,
  updated_at_ms bigint not null,
  primary key (user_id, id),
  foreign key (user_id, group_id)
    references public.groups(user_id, id)
    on delete cascade
);

-- 7. BUDGETS
create table if not exists public.budgets (
  user_id uuid primary key references auth.users(id) on delete cascade,
  monthly_budget_paise bigint not null default 5000000,
  category_limits jsonb not null default '{}'::jsonb,
  schema_version integer not null default 2,
  updated_at_ms bigint not null
);

-- 8. GOALS
create table if not exists public.goals (
  user_id uuid not null references auth.users(id) on delete cascade,
  id text not null,
  name text not null,
  target_paise bigint not null,
  saved_paise bigint not null default 0,
  target_date_ms bigint,
  created_at_ms bigint not null,
  schema_version integer not null default 2,
  updated_at_ms bigint not null,
  primary key (user_id, id)
);

-- 9. USER SETTINGS
create table if not exists public.user_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  theme_mode text not null default 'system',
  experience_mode text not null default 'auto',
  seeded_at_ms bigint,
  seed_version integer not null default 3,
  schema_version integer not null default 2,
  updated_at_ms bigint not null
);

-- ============================================================
-- ROW LEVEL SECURITY
-- Each authenticated user can access only their own records.
-- ============================================================

do $$
declare
  tbl text;
begin
  foreach tbl in array array[
    'people',
    'groups',
    'expenses',
    'settlements',
    'ious',
    'recurring',
    'budgets',
    'goals',
    'user_settings'
  ]
  loop
    execute format(
      'alter table public.%I enable row level security;',
      tbl
    );

    execute format(
      'create policy "%s_select_own"
       on public.%I
       for select
       to authenticated
       using (auth.uid() = user_id);',
      tbl, tbl
    );

    execute format(
      'create policy "%s_insert_own"
       on public.%I
       for insert
       to authenticated
       with check (auth.uid() = user_id);',
      tbl, tbl
    );

    execute format(
      'create policy "%s_update_own"
       on public.%I
       for update
       to authenticated
       using (auth.uid() = user_id)
       with check (auth.uid() = user_id);',
      tbl, tbl
    );

    execute format(
      'create policy "%s_delete_own"
       on public.%I
       for delete
       to authenticated
       using (auth.uid() = user_id);',
      tbl, tbl
    );
  end loop;
end $$;

-- ============================================================
-- ATOMIC SETTLEMENT INSERT
-- Used for multi-group settlement operations.
-- ============================================================

create or replace function public.rpc_insert_settlements(
  p_rows jsonb
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if p_rows is null
     or jsonb_typeof(p_rows) <> 'array' then
    raise exception 'p_rows must be a JSON array';
  end if;

  insert into public.settlements (
    user_id,
    id,
    group_id,
    from_id,
    to_id,
    paise,
    method,
    date_ms,
    deleted_at_ms,
    note,
    schema_version,
    updated_at_ms
  )
  select
    auth.uid(),
    item.row_data->>'id',
    item.row_data->>'group_id',
    item.row_data->>'from_id',
    item.row_data->>'to_id',
    (item.row_data->>'paise')::bigint,
    coalesce(item.row_data->>'method', 'upi'),
    (item.row_data->>'date_ms')::bigint,
    (item.row_data->>'deleted_at_ms')::bigint,
    item.row_data->>'note',
    coalesce(
      (item.row_data->>'schema_version')::integer,
      2
    ),
    (item.row_data->>'updated_at_ms')::bigint
  from jsonb_array_elements(p_rows) as item(row_data);
end;
$$;

-- ============================================================
-- ATOMIC SETTLEMENT DELETE
-- Used when undoing a multi-settlement operation.
-- ============================================================

create or replace function public.rpc_delete_settlements(
  p_ids text[]
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  delete from public.settlements
  where user_id = auth.uid()
    and id = any(p_ids);
end;
$$;

-- ============================================================
-- RPC EXECUTION PERMISSIONS
-- Only authenticated users can execute these functions.
-- ============================================================

revoke all on function public.rpc_insert_settlements(jsonb)
  from public;

revoke all on function public.rpc_delete_settlements(text[])
  from public;

grant execute on function public.rpc_insert_settlements(jsonb)
  to authenticated;

grant execute on function public.rpc_delete_settlements(text[])
  to authenticated;

-- ============================================================
-- END OF SETTLIV SET 2 MIGRATION
-- ============================================================
