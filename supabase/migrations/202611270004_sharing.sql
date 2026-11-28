-- Settliv P5: Multi-user shared groups, join codes, username invites, and placeholder claiming

alter table public.profiles
  add column if not exists allow_username_invites boolean not null default true;

alter table public.groups
  add column if not exists owner_id uuid references auth.users(id),
  add column if not exists join_code text,
  add column if not exists join_code_enabled boolean not null default true;

create unique index if not exists groups_join_code_unique_idx
  on public.groups (join_code)
  where join_code is not null;

alter table public.people
  add column if not exists linked_user_id uuid references auth.users(id);

create table if not exists public.group_members (
  group_id text not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'admin', 'member')),
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

create table if not exists public.group_invites (
  id uuid primary key default gen_random_uuid(),
  group_id text not null,
  inviter_id uuid not null references auth.users(id) on delete cascade,
  invitee_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined', 'cancelled', 'expired')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '14 days'),
  responded_at timestamptz
);

create index if not exists group_invites_invitee_idx
  on public.group_invites (invitee_id, status);

create table if not exists public.group_join_attempts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  window_start timestamptz not null default now(),
  fail_count int not null default 0
);

alter table public.group_members enable row level security;
alter table public.group_invites enable row level security;
alter table public.group_join_attempts enable row level security;

grant select, insert, update, delete on public.group_members to authenticated;
grant select, insert, update, delete on public.group_invites to authenticated;
grant select, insert, update, delete on public.group_join_attempts to authenticated;

create or replace function public._generate_join_code()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  alphabet constant text := '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
  result text := '';
  i int;
  candidate text;
begin
  loop
    result := '';
    for i in 1..8 loop
      result := result || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    select g.join_code into candidate from public.groups g where g.join_code = result limit 1;
    exit when candidate is null;
  end loop;
  return result;
end;
$$;

create or replace function public.is_group_member(p_group_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.group_members gm
    where gm.group_id = p_group_id
      and gm.user_id = auth.uid()
  );
$$;

create or replace function public.is_group_admin(p_group_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.group_members gm
    where gm.group_id = p_group_id
      and gm.user_id = auth.uid()
      and gm.role in ('owner', 'admin')
  );
$$;

grant execute on function public.is_group_member(text) to authenticated;
grant execute on function public.is_group_admin(text) to authenticated;

-- Backfill existing groups
update public.groups
set owner_id = user_id
where owner_id is null;

update public.groups
set join_code = public._generate_join_code()
where join_code is null
  and coalesce(is_personal, false) = false;

insert into public.group_members (group_id, user_id, role)
select g.id, coalesce(g.owner_id, g.user_id), 'owner'
from public.groups g
where coalesce(g.is_personal, false) = false
on conflict (group_id, user_id) do nothing;

-- RLS policies for new tables
drop policy if exists "group_members_select" on public.group_members;
create policy "group_members_select"
  on public.group_members for select
  to authenticated
  using (public.is_group_member(group_id));

drop policy if exists "group_members_insert" on public.group_members;
create policy "group_members_insert"
  on public.group_members for insert
  to authenticated
  with check (public.is_group_admin(group_id) or user_id = auth.uid());

drop policy if exists "group_members_delete" on public.group_members;
create policy "group_members_delete"
  on public.group_members for delete
  to authenticated
  using (public.is_group_admin(group_id) or user_id = auth.uid());

drop policy if exists "group_invites_select" on public.group_invites;
create policy "group_invites_select"
  on public.group_invites for select
  to authenticated
  using (
    invitee_id = auth.uid()
    or inviter_id = auth.uid()
    or public.is_group_admin(group_id)
  );

drop policy if exists "group_invites_insert" on public.group_invites;
create policy "group_invites_insert"
  on public.group_invites for insert
  to authenticated
  with check (
    inviter_id = auth.uid()
    and public.is_group_member(group_id)
  );

drop policy if exists "group_invites_update" on public.group_invites;
create policy "group_invites_update"
  on public.group_invites for update
  to authenticated
  using (
    invitee_id = auth.uid()
    or inviter_id = auth.uid()
    or public.is_group_admin(group_id)
  );

drop policy if exists "group_join_attempts_self" on public.group_join_attempts;
create policy "group_join_attempts_self"
  on public.group_join_attempts for all
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Shared group policies on existing ledger tables
drop policy if exists "groups_shared_select" on public.groups;
create policy "groups_shared_select"
  on public.groups for select
  to authenticated
  using (user_id = auth.uid() or public.is_group_member(id));

drop policy if exists "groups_shared_update" on public.groups;
create policy "groups_shared_update"
  on public.groups for update
  to authenticated
  using (user_id = auth.uid() or public.is_group_admin(id));

drop policy if exists "expenses_shared_all" on public.expenses;
create policy "expenses_shared_all"
  on public.expenses for all
  to authenticated
  using (
    user_id = auth.uid()
    or (group_id <> 'group_personal' and public.is_group_member(group_id))
  )
  with check (
    user_id = auth.uid()
    or (group_id <> 'group_personal' and public.is_group_member(group_id))
  );

drop policy if exists "settlements_shared_all" on public.settlements;
create policy "settlements_shared_all"
  on public.settlements for all
  to authenticated
  using (
    user_id = auth.uid()
    or (group_id <> 'group_personal' and public.is_group_member(group_id))
  )
  with check (
    user_id = auth.uid()
    or (group_id <> 'group_personal' and public.is_group_member(group_id))
  );

drop policy if exists "recurring_shared_all" on public.recurring;
create policy "recurring_shared_all"
  on public.recurring for all
  to authenticated
  using (
    user_id = auth.uid()
    or (group_id <> 'group_personal' and public.is_group_member(group_id))
  )
  with check (
    user_id = auth.uid()
    or (group_id <> 'group_personal' and public.is_group_member(group_id))
  );

-- RPCs
create or replace function public.rpc_search_users_for_invite(p_query text)
returns table (
  id uuid,
  display_name text,
  username text,
  avatar_kind text,
  avatar_ref text
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  q text := lower(trim(coalesce(p_query, '')));
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if length(q) < 3 then
    return;
  end if;
  return query
  select
    p.id,
    p.display_name,
    p.username,
    coalesce(p.avatar_kind, 'initials') as avatar_kind,
    p.avatar_ref
  from public.profiles p
  where p.id <> auth.uid()
    and coalesce(p.allow_username_invites, true) = true
    and p.username is not null
    and lower(p.username) like q || '%'
  order by (lower(p.username) = q) desc, p.username asc
  limit 5;
end;
$$;

create or replace function public.rpc_invite_user(p_group_id text, p_invitee_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invite_id uuid;
  v_allows boolean;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if not public.is_group_member(p_group_id) then
    raise exception 'Only group members can send invites';
  end if;
  if p_invitee_id = auth.uid() then
    raise exception 'You are already in this group';
  end if;
  if exists (
    select 1 from public.group_members gm
    where gm.group_id = p_group_id and gm.user_id = p_invitee_id
  ) then
    raise exception 'User is already a member of this group';
  end if;
  select coalesce(p.allow_username_invites, true)
    into v_allows
  from public.profiles p
  where p.id = p_invitee_id;
  if not coalesce(v_allows, false) then
    raise exception 'This user is not accepting username invites';
  end if;

  insert into public.group_invites (group_id, inviter_id, invitee_id, status)
  values (p_group_id, auth.uid(), p_invitee_id, 'pending')
  returning id into v_invite_id;

  return v_invite_id;
end;
$$;

create or replace function public.rpc_respond_invite(p_invite_id uuid, p_accept boolean)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inv public.group_invites%rowtype;
  v_uid_text text := auth.uid()::text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  select * into v_inv
  from public.group_invites
  where id = p_invite_id
    and invitee_id = auth.uid();

  if not found then
    raise exception 'Invite not found';
  end if;
  if v_inv.status <> 'pending' then
    raise exception 'Invite is no longer pending';
  end if;
  if v_inv.expires_at < now() then
    update public.group_invites
    set status = 'expired', responded_at = now()
    where id = p_invite_id;
    raise exception 'Invite has expired';
  end if;

  if p_accept then
    update public.group_invites
    set status = 'accepted', responded_at = now()
    where id = p_invite_id;

    insert into public.group_members (group_id, user_id, role)
    values (v_inv.group_id, auth.uid(), 'member')
    on conflict (group_id, user_id) do nothing;

    update public.groups
    set member_ids = array_append(member_ids, v_uid_text)
    where id = v_inv.group_id
      and not (v_uid_text = any(coalesce(member_ids, '{}')));
  else
    update public.group_invites
    set status = 'declined', responded_at = now()
    where id = p_invite_id;
  end if;

  return v_inv.group_id;
end;
$$;

create or replace function public.rpc_cancel_invite(p_invite_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inv public.group_invites%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  select * into v_inv from public.group_invites where id = p_invite_id;
  if not found then
    raise exception 'Invite not found';
  end if;
  if v_inv.inviter_id <> auth.uid() and not public.is_group_admin(v_inv.group_id) then
    raise exception 'Not allowed to cancel this invite';
  end if;
  update public.group_invites
  set status = 'cancelled', responded_at = now()
  where id = p_invite_id and status = 'pending';
end;
$$;

create or replace function public.rpc_join_by_code(p_code text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text := upper(trim(coalesce(p_code, '')));
  v_attempt public.group_join_attempts%rowtype;
  v_group_id text;
  v_uid_text text := auth.uid()::text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select * into v_attempt
  from public.group_join_attempts
  where user_id = auth.uid();

  if found and v_attempt.window_start > (now() - interval '1 hour') and v_attempt.fail_count >= 10 then
    raise exception 'Too many failed attempts. Try again in an hour.';
  end if;

  select g.id into v_group_id
  from public.groups g
  where g.join_code = v_code
    and coalesce(g.join_code_enabled, true) = true
    and coalesce(g.is_personal, false) = false
  limit 1;

  if v_group_id is null then
    insert into public.group_join_attempts (user_id, window_start, fail_count)
    values (auth.uid(), now(), 1)
    on conflict (user_id) do update
      set fail_count = case
            when group_join_attempts.window_start <= (now() - interval '1 hour') then 1
            else group_join_attempts.fail_count + 1
          end,
          window_start = case
            when group_join_attempts.window_start <= (now() - interval '1 hour') then now()
            else group_join_attempts.window_start
          end;
    raise exception 'Invalid or disabled join code';
  end if;

  delete from public.group_join_attempts where user_id = auth.uid();

  insert into public.group_members (group_id, user_id, role)
  values (v_group_id, auth.uid(), 'member')
  on conflict (group_id, user_id) do nothing;

  update public.groups
  set member_ids = array_append(member_ids, v_uid_text)
  where id = v_group_id
    and not (v_uid_text = any(coalesce(member_ids, '{}')));

  return v_group_id;
end;
$$;

create or replace function public.rpc_regenerate_join_code(p_group_id text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_new_code text;
begin
  if auth.uid() is null or not public.is_group_admin(p_group_id) then
    raise exception 'Only group admins can regenerate join codes';
  end if;
  v_new_code := public._generate_join_code();
  update public.groups
  set join_code = v_new_code, join_code_enabled = true
  where id = p_group_id;
  return v_new_code;
end;
$$;

create or replace function public.rpc_set_join_code_enabled(p_group_id text, p_enabled boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or not public.is_group_admin(p_group_id) then
    raise exception 'Only group admins can update join code settings';
  end if;
  update public.groups
  set join_code_enabled = p_enabled
  where id = p_group_id;
end;
$$;

create or replace function public.rpc_remove_group_member(p_group_id text, p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text;
begin
  if auth.uid() is null or not public.is_group_admin(p_group_id) then
    raise exception 'Only group admins can remove members';
  end if;
  select role into v_role
  from public.group_members
  where group_id = p_group_id and user_id = p_user_id;
  if v_role = 'owner' then
    raise exception 'Group owner cannot be removed';
  end if;
  delete from public.group_members
  where group_id = p_group_id and user_id = p_user_id;
  update public.groups
  set member_ids = array_remove(member_ids, p_user_id::text)
  where id = p_group_id;
end;
$$;

create or replace function public.rpc_leave_group(p_group_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text;
  v_other_count int;
begin
  if auth.uid() is null or not public.is_group_member(p_group_id) then
    raise exception 'Not a member of this group';
  end if;
  select role into v_role
  from public.group_members
  where group_id = p_group_id and user_id = auth.uid();
  if v_role = 'owner' then
    select count(*) into v_other_count
    from public.group_members
    where group_id = p_group_id and user_id <> auth.uid();
    if v_other_count > 0 then
      raise exception 'Group owner cannot leave while other members remain';
    end if;
  end if;
  delete from public.group_members
  where group_id = p_group_id and user_id = auth.uid();
  update public.groups
  set member_ids = array_remove(member_ids, auth.uid()::text)
  where id = p_group_id;
end;
$$;

create or replace function public.rpc_claim_placeholder(p_group_id text, p_placeholder_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid_text text := auth.uid()::text;
begin
  if auth.uid() is null or not public.is_group_member(p_group_id) then
    raise exception 'Must be a member of the group to claim a placeholder';
  end if;

  update public.groups
  set member_ids = array_remove(
    case
      when v_uid_text = any(coalesce(member_ids, '{}')) then member_ids
      else array_append(member_ids, v_uid_text)
    end,
    p_placeholder_id
  )
  where id = p_group_id;

  update public.expenses
  set paid_by = case when paid_by = p_placeholder_id then v_uid_text else paid_by end,
      shares = case
        when shares ? p_placeholder_id then (shares - p_placeholder_id) || jsonb_build_object(v_uid_text, shares -> p_placeholder_id)
        else shares
      end
  where group_id = p_group_id;

  update public.settlements
  set from_id = case when from_id = p_placeholder_id then v_uid_text else from_id end,
      to_id = case when to_id = p_placeholder_id then v_uid_text else to_id end
  where group_id = p_group_id;

  update public.people
  set linked_user_id = auth.uid()
  where id = p_placeholder_id;
end;
$$;

grant execute on function public.rpc_search_users_for_invite(text) to authenticated;
grant execute on function public.rpc_invite_user(text, uuid) to authenticated;
grant execute on function public.rpc_respond_invite(uuid, boolean) to authenticated;
grant execute on function public.rpc_cancel_invite(uuid) to authenticated;
grant execute on function public.rpc_join_by_code(text) to authenticated;
grant execute on function public.rpc_regenerate_join_code(text) to authenticated;
grant execute on function public.rpc_set_join_code_enabled(text, boolean) to authenticated;
grant execute on function public.rpc_remove_group_member(text, uuid) to authenticated;
grant execute on function public.rpc_leave_group(text) to authenticated;
grant execute on function public.rpc_claim_placeholder(text, text) to authenticated;
