-- Settliv Set 1: Profiles table and Row Level Security
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  username text unique,
  email text,
  provider text not null check (provider in ('google', 'password-email', 'password-username')),
  created_at timestamptz not null default now(),
  last_login_at_ms bigint not null,
  layout text not null check (layout in ('app', 'web')),
  onboarded boolean not null default false,
  upi_id text,
  schema_version integer not null default 1
);

alter table public.profiles enable row level security;

create policy "profiles_select_own"
  on public.profiles
  for select
  to authenticated
  using (auth.uid() = id);

create policy "profiles_insert_own"
  on public.profiles
  for insert
  to authenticated
  with check (auth.uid() = id);

create policy "profiles_update_own"
  on public.profiles
  for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);
