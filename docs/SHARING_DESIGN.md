# Settliv Multi-User Sharing Design

## 1. Schema & Tables
- `profiles`: add `allow_username_invites boolean not null default true`.
- `groups`: add `owner_id uuid references auth.users(id)`, `join_code text unique` (nullable), `join_code_enabled boolean not null default true`.
- `group_members`: `(group_id text references groups(id) on delete cascade, user_id uuid references auth.users(id) on delete cascade, role text not null check (role in ('owner','admin','member')), joined_at timestamptz not null default now(), primary key (group_id, user_id))`.
- `group_invites`: `(id uuid primary key default gen_random_uuid(), group_id text not null, inviter_id uuid not null, invitee_id uuid not null, status text not null check (status in ('pending','accepted','declined','cancelled','expired')), created_at timestamptz not null default now(), expires_at timestamptz not null default (now() + interval '14 days'), responded_at timestamptz)`.
- `group_join_attempts`: `(user_id uuid primary key, window_start timestamptz not null, fail_count int not null default 0)` for join-code throttling.
- `people`: add `linked_user_id uuid` (nullable) to distinguish auth users from manual placeholders.

## 2. Shared vs Personal Data
- **Shared (group-scoped)**: non-personal `groups`, `group_members`, `expenses`, `settlements`, `recurring`, and member `people` rows.
- **Personal (owner-only)**: `group_personal` and its expenses, `ious`, `goals`, `user_settings`, and local budgets.

## 3. RLS Strategy (No Recursion)
- `security definer` helpers (`set search_path = public`):
  - `is_group_member(gid text)`: exists in `group_members` for `(gid, auth.uid())`.
  - `is_group_admin(gid text)`: exists in `group_members` for `(gid, auth.uid())` with `role in ('owner','admin')`.
- `groups`: `select` via `is_group_member(id)`; `insert` with `owner_id = auth.uid()`; `update`/`delete` via `is_group_admin(id)`.
- `group_members`: `select` via `is_group_member(group_id)`; writes via RPCs or `is_group_admin(group_id)`.
- `expenses`, `settlements`, `recurring`: `select`/`insert`/`update` via `is_group_member(group_id)` for shared groups, or `user_id = auth.uid()` for `group_personal`.
- `ious`, `goals`, `user_settings`: strictly `user_id = auth.uid()`.
- `group_invites`: `select` for `invitee_id = auth.uid()`, `inviter_id = auth.uid()`, or `is_group_admin(group_id)`.

## 4. Existing Groups Migration
- Backfill `groups.owner_id = user_id` where null.
- Insert `(id, user_id, 'owner')` into `group_members` (`on conflict do nothing`) for all non-personal groups.
- Generate unique 8-char `join_code` for existing shared groups; existing balances and rows stay intact.

## 5. Core Flows & Roles
- **Join code**: 8 chars from `23456789ABCDEFGHJKMNPQRSTUVWXYZ` (no `0/O/1/I/L`), unique per group. `owner`/`admin` can disable or regenerate via RPC. `rpc_join_by_code(code)` enforces max 10 failed attempts/hour/user in `group_join_attempts`, adds `member` row, and returns unclaimed placeholders.
- **Username search**: `rpc_search_users_for_invite(q)` (`security definer`) requires `length(trim(q)) >= 3`, exact/prefix match on `username` where `allow_username_invites = true`, `limit 5`, returning only `(id, display_name, username, avatar_kind, avatar_ref)`—never email or phone.
- **Invites**: `rpc_invite_user` creates a `pending` 14-day invite. Invitee calls `rpc_respond_invite(id, accept)` (`accepted`/`declined`, or marks `expired` if past `expires_at`). Inviter/admin can cancel `pending` invites.
- **Roles & Leave**: Any member can add/edit expenses (`revisions` preserved). Only `owner`/`admin` can remove members or manage the join code. A member can leave (`rpc_leave_group`) only when their net balance in the group is `0` (must settle up first); `owner` must transfer ownership or be the last member.
- **Claiming placeholders**: On join/accept, if the group has unlinked manual `people`, show `"I'm already listed as..."`; `rpc_claim_placeholder(gid, placeholder_id)` atomically remaps `member_ids`, `expenses` (`paid_by`/`payers`/`shares`), `settlements`, and `recurring` to `auth.uid()`. Otherwise add `auth.uid()` as a new member.
- **Balances**: Existing `BalanceEngine` runs unchanged on shared `expenses` + `settlements`, guaranteeing identical integer-paise balances for all members.

## 6. Failure Modes & Refresh Strategy
- **Failure modes**: invalid/disabled/throttled join code, expired/cancelled invite, non-zero balance when leaving, and unapplied migration (handled with clear inline errors, no crash).
- **Refresh**: Extend existing `SupabaseLedgerRepository` Postgres Realtime (`_subscribeRealtime`) to shared `groups`, `group_members`, `group_invites`, `expenses`, and `settlements`, plus pull-to-refresh and app-resume refresh. In-app Invites inbox + badge (no push notifications).
