-- ============================================================
-- D-DART SUPABASE DATABASE SCHEMA (Hardened & Idempotent)
-- Run this in your Supabase Dashboard -> SQL Editor -> Run
-- Safe and idempotent: can be re-run on an existing database.
-- ============================================================

-- Private schema for internal SECURITY DEFINER helpers (never exposed via Data API)
create schema if not exists private;
grant usage on schema private to authenticated;

-- 1. Profiles Table (linked to Supabase Auth)
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  email text,
  phone_number text,
  student_id text,
  role text default 'customer',
  account_type text not null default 'student',
  verification_status text not null default 'pending',
  cor_verified boolean not null default false,
  id_document_path text,
  cor_document_path text,
  rejection_reason text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now())
);

alter table public.profiles add column if not exists account_type text not null default 'student';
alter table public.profiles add column if not exists verification_status text not null default 'pending';
alter table public.profiles add column if not exists cor_verified boolean not null default false;
alter table public.profiles add column if not exists id_document_path text;
alter table public.profiles add column if not exists cor_document_path text;
alter table public.profiles add column if not exists rejection_reason text;

alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles add constraint profiles_role_check
  check (role in ('customer', 'runner', 'admin'));

alter table public.profiles drop constraint if exists profiles_account_type_check;
alter table public.profiles add constraint profiles_account_type_check
  check (account_type in ('student', 'faculty_staff', 'admin'));

alter table public.profiles drop constraint if exists profiles_verification_status_check;
alter table public.profiles add constraint profiles_verification_status_check
  check (verification_status in ('pending', 'verified', 'rejected'));

-- Helper function in private schema to check admin privileges without RLS recursion
create or replace function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and (account_type = 'admin' or role = 'admin')
  );
$$;

revoke all on function private.is_admin() from public, anon;
grant execute on function private.is_admin() to authenticated;

-- 2. Campus Pickup & Drop-off Locations Directory
create table if not exists public.locations (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  category text not null check (category in ('pickup', 'dropoff')),
  building_code text default '',
  is_active boolean not null default true,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

insert into public.locations (name, category, building_code) values
  ('Main Canteen', 'pickup', 'MC'),
  ('College Canteen', 'pickup', 'CC'),
  ('Elementary Canteen', 'pickup', 'EC'),
  ('Campus Kiosks', 'pickup', 'CK'),
  ('ALLIED Building', 'dropoff', 'ALLIED'),
  ('GLE Building', 'dropoff', 'GLE'),
  ('Main Building', 'dropoff', 'MAIN'),
  ('University Library', 'dropoff', 'LRAC'),
  ('Department Offices', 'dropoff', 'DEPT')
on conflict (name) do nothing;

-- 3. System Configuration Table (Admin-Managed Parameters)
create table if not exists public.system_configurations (
  id uuid primary key default gen_random_uuid(),
  config_key text not null unique,
  config_value text not null,
  description text default '',
  updated_by uuid references public.profiles(id) on delete set null,
  updated_at timestamp with time zone default timezone('utc'::text, now())
);

insert into public.system_configurations (config_key, config_value, description) values
  ('pre_class_buffer_minutes', '15', 'Minutes before a scheduled class when runner mode locks'),
  ('daily_delivery_limit', '5', 'Maximum completed deliveries allowed per runner per day'),
  ('request_expiration_minutes', '30', 'Minutes before an unclaimed pending request expires'),
  ('standard_delivery_fee', '20.00', 'Standard campus delivery fee in PHP')
on conflict (config_key) do nothing;

-- 4. Delivery Requests / Pabili Table
create table if not exists public.delivery_requests (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid references public.profiles(id) on delete set null,
  runner_id uuid references public.profiles(id) on delete set null,
  pickup_location text not null,
  dropoff_location text not null,
  description text not null,
  estimated_price numeric(10,2) not null default 0.00,
  delivery_fee numeric(10,2) not null default 20.00,
  status text not null default 'pending',
  verification_code text not null,
  special_instructions text default '',
  expires_at timestamp with time zone default (timezone('utc'::text, now()) + interval '30 minutes'),
  claimed_at timestamp with time zone,
  cancelled_at timestamp with time zone,
  completed_at timestamp with time zone,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now())
);

alter table public.delivery_requests
  add column if not exists expires_at timestamp with time zone default (timezone('utc'::text, now()) + interval '30 minutes');
alter table public.delivery_requests add column if not exists claimed_at timestamp with time zone;
alter table public.delivery_requests add column if not exists cancelled_at timestamp with time zone;
alter table public.delivery_requests add column if not exists completed_at timestamp with time zone;

alter table public.delivery_requests drop constraint if exists delivery_requests_status_check;
alter table public.delivery_requests add constraint delivery_requests_status_check
  check (status in ('pending', 'claimed', 'purchasing', 'en_route', 'arrived', 'completed', 'cancelled', 'expired'));

-- 5. Delivery Status Logs (Audit Trail per SDD 4.3)
create table if not exists public.delivery_status_logs (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.delivery_requests(id) on delete cascade,
  status text not null,
  changed_by uuid references public.profiles(id) on delete set null,
  remarks text default '',
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 6. Delivery Records Archive Table (Finalized Requests)
create table if not exists public.delivery_records (
  id uuid primary key default gen_random_uuid(),
  request_id uuid unique not null references public.delivery_requests(id) on delete cascade,
  customer_id uuid references public.profiles(id) on delete set null,
  runner_id uuid references public.profiles(id) on delete set null,
  final_status text not null check (final_status in ('completed', 'cancelled', 'expired')),
  estimated_price numeric(10,2) not null default 0.00,
  delivery_fee numeric(10,2) not null default 20.00,
  recorded_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 7. Problem Reports Table (Admin Problem / Dispute Review)
create table if not exists public.problem_reports (
  id uuid primary key default gen_random_uuid(),
  request_id uuid references public.delivery_requests(id) on delete set null,
  reporter_id uuid references public.profiles(id) on delete set null,
  category text not null check (category in ('wrong_item', 'late_delivery', 'payment_issue', 'runner_behavior', 'app_issue', 'other')),
  description text not null,
  status text not null default 'open' check (status in ('open', 'reviewing', 'resolved', 'dismissed')),
  admin_notes text default '',
  reviewed_by uuid references public.profiles(id) on delete set null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now())
);

-- 8. Runner Schedules Table (for COR Duty Lock)
create table if not exists public.runner_schedules (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade,
  day text not null,
  start_time text not null,
  end_time text not null,
  subject text not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Covering Foreign-Key & Query Indexes
create index if not exists idx_system_configurations_updated_by on public.system_configurations (updated_by);
create index if not exists idx_delivery_requests_customer_id on public.delivery_requests (customer_id);
create index if not exists idx_delivery_requests_runner_id on public.delivery_requests (runner_id);
create index if not exists idx_delivery_requests_status_created on public.delivery_requests (status, created_at desc);
create index if not exists idx_delivery_requests_runner_completed on public.delivery_requests (runner_id, status, completed_at);
create index if not exists idx_delivery_status_logs_request_id on public.delivery_status_logs (request_id);
create index if not exists idx_delivery_status_logs_changed_by on public.delivery_status_logs (changed_by);
create index if not exists idx_delivery_records_customer_id on public.delivery_records (customer_id);
create index if not exists idx_delivery_records_runner_id on public.delivery_records (runner_id);
create index if not exists idx_problem_reports_request_id on public.problem_reports (request_id);
create index if not exists idx_problem_reports_reporter_id on public.problem_reports (reporter_id);
create index if not exists idx_problem_reports_reviewed_by on public.problem_reports (reviewed_by);
create index if not exists idx_runner_schedules_user_id on public.runner_schedules (user_id);

-- 9. Enable Row Level Security (RLS)
alter table public.profiles enable row level security;
alter table public.locations enable row level security;
alter table public.system_configurations enable row level security;
alter table public.delivery_requests enable row level security;
alter table public.delivery_status_logs enable row level security;
alter table public.delivery_records enable row level security;
alter table public.problem_reports enable row level security;
alter table public.runner_schedules enable row level security;

-- Drop legacy policies before recreating & removing legacy public.is_admin()
drop policy if exists "Allow authenticated read profiles" on public.profiles;
drop policy if exists "Allow users to update their own profile" on public.profiles;
drop policy if exists "Allow users to insert their own profile" on public.profiles;

drop policy if exists "Allow read active locations" on public.locations;
drop policy if exists "Allow admins manage locations" on public.locations;
drop policy if exists "Allow admins insert locations" on public.locations;
drop policy if exists "Allow admins update locations" on public.locations;
drop policy if exists "Allow admins delete locations" on public.locations;

drop policy if exists "Allow authenticated read configs" on public.system_configurations;
drop policy if exists "Allow admins update configs" on public.system_configurations;
drop policy if exists "Allow admins insert configs" on public.system_configurations;
drop policy if exists "Allow admins modify configs" on public.system_configurations;
drop policy if exists "Allow admins delete configs" on public.system_configurations;

drop policy if exists "Allow read delivery requests" on public.delivery_requests;
drop policy if exists "Allow insert delivery requests" on public.delivery_requests;
drop policy if exists "Allow update delivery requests" on public.delivery_requests;

drop policy if exists "Allow read delivery status logs" on public.delivery_status_logs;
drop policy if exists "Allow participants read delivery records" on public.delivery_records;

drop policy if exists "Allow create problem reports" on public.problem_reports;
drop policy if exists "Allow read own or admin problem reports" on public.problem_reports;
drop policy if exists "Allow admins update problem reports" on public.problem_reports;

drop policy if exists "Allow read runner schedules" on public.runner_schedules;
drop policy if exists "Allow users manage their schedules" on public.runner_schedules;
drop policy if exists "Allow users insert own schedules" on public.runner_schedules;
drop policy if exists "Allow users update own schedules" on public.runner_schedules;
drop policy if exists "Allow users delete own schedules" on public.runner_schedules;

drop policy if exists "Users upload own verification docs" on storage.objects;
drop policy if exists "Users read own verification docs" on storage.objects;
drop policy if exists "Users update own verification docs" on storage.objects;

drop function if exists public.is_admin();

-- 10. RLS Policies & Privilege Guard for Profiles
create policy "Allow authenticated read profiles"
  on public.profiles for select
  to authenticated
  using ((select auth.uid()) = id or (select private.is_admin()));

create policy "Allow users to insert their own profile"
  on public.profiles for insert
  to authenticated
  with check (
    (select auth.uid()) = id
    and account_type in ('student', 'faculty_staff')
    and role in ('customer', 'runner')
    and verification_status = 'pending'
  );

create policy "Allow users to update their own profile"
  on public.profiles for update
  to authenticated
  using ((select auth.uid()) = id or (select private.is_admin()))
  with check ((select auth.uid()) = id or (select private.is_admin()));

create or replace function public.protect_profile_privileged_fields()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user = 'authenticated' and not (select private.is_admin()) then
    if new.account_type is distinct from old.account_type
       or new.verification_status is distinct from old.verification_status
       or new.rejection_reason is distinct from old.rejection_reason
       or new.role = 'admin' then
      raise exception 'Only administrators can modify account_type, verification_status, rejection_reason, or admin role.';
    end if;

    if new.role = 'runner'
       and (old.account_type <> 'student'
            or old.verification_status <> 'verified'
            or old.cor_verified <> true) then
      raise exception 'Only verified student accounts with a confirmed COR schedule may switch to runner role.';
    end if;
  end if;
  return new;
end;
$$;

revoke all on function public.protect_profile_privileged_fields() from public, anon, authenticated;

drop trigger if exists on_profile_protect_privileged_fields on public.profiles;
create trigger on_profile_protect_privileged_fields
  before update on public.profiles
  for each row execute function public.protect_profile_privileged_fields();

-- 11. RLS Policies for Locations (no overlapping FOR SELECT policies)
create policy "Allow read active locations"
  on public.locations for select
  to authenticated
  using (is_active = true or (select private.is_admin()));

create policy "Allow admins insert locations"
  on public.locations for insert
  to authenticated
  with check ((select private.is_admin()));

create policy "Allow admins update locations"
  on public.locations for update
  to authenticated
  using ((select private.is_admin()))
  with check ((select private.is_admin()));

create policy "Allow admins delete locations"
  on public.locations for delete
  to authenticated
  using ((select private.is_admin()));

-- 12. RLS Policies for System Configurations (no overlapping FOR SELECT policies)
create policy "Allow authenticated read configs"
  on public.system_configurations for select
  to authenticated
  using (true);

create policy "Allow admins insert configs"
  on public.system_configurations for insert
  to authenticated
  with check ((select private.is_admin()));

create policy "Allow admins modify configs"
  on public.system_configurations for update
  to authenticated
  using ((select private.is_admin()))
  with check ((select private.is_admin()));

create policy "Allow admins delete configs"
  on public.system_configurations for delete
  to authenticated
  using ((select private.is_admin()));

-- 13. RLS Policies for Delivery Requests
create policy "Allow read delivery requests"
  on public.delivery_requests for select
  to authenticated
  using (
    status = 'pending'
    or (select auth.uid()) = customer_id
    or (select auth.uid()) = runner_id
    or (select private.is_admin())
  );

create policy "Allow insert delivery requests"
  on public.delivery_requests for insert
  to authenticated
  with check (
    customer_id = (select auth.uid())
    and status = 'pending'
  );

-- Direct updates only advance assigned delivery progress; claim/cancel/expire/complete use RPCs
create policy "Allow update delivery requests"
  on public.delivery_requests for update
  to authenticated
  using (
    ((select auth.uid()) = runner_id and status in ('claimed', 'purchasing', 'en_route'))
    or (select private.is_admin())
  )
  with check (
    ((select auth.uid()) = runner_id and status in ('purchasing', 'en_route', 'arrived'))
    or (select private.is_admin())
  );

-- 14. RLS Policies for Status Logs & Delivery Records
create policy "Allow read delivery status logs"
  on public.delivery_status_logs for select
  to authenticated
  using (
    (select private.is_admin())
    or exists (
      select 1 from public.delivery_requests dr
      where dr.id = request_id
        and (dr.customer_id = (select auth.uid()) or dr.runner_id = (select auth.uid()))
    )
  );

create policy "Allow participants read delivery records"
  on public.delivery_records for select
  to authenticated
  using (
    (select auth.uid()) = customer_id
    or (select auth.uid()) = runner_id
    or (select private.is_admin())
  );

-- 15. RLS Policies for Problem Reports
create policy "Allow create problem reports"
  on public.problem_reports for insert
  to authenticated
  with check (reporter_id = (select auth.uid()));

create policy "Allow read own or admin problem reports"
  on public.problem_reports for select
  to authenticated
  using ((select auth.uid()) = reporter_id or (select private.is_admin()));

create policy "Allow admins update problem reports"
  on public.problem_reports for update
  to authenticated
  using ((select private.is_admin()))
  with check ((select private.is_admin()));

-- 16. RLS Policies for Runner Schedules (owner + admin only; no overlapping policies)
create policy "Allow read runner schedules"
  on public.runner_schedules for select
  to authenticated
  using ((select auth.uid()) = user_id or (select private.is_admin()));

create policy "Allow users insert own schedules"
  on public.runner_schedules for insert
  to authenticated
  with check ((select auth.uid()) = user_id or (select private.is_admin()));

create policy "Allow users update own schedules"
  on public.runner_schedules for update
  to authenticated
  using ((select auth.uid()) = user_id or (select private.is_admin()))
  with check ((select auth.uid()) = user_id or (select private.is_admin()));

create policy "Allow users delete own schedules"
  on public.runner_schedules for delete
  to authenticated
  using ((select auth.uid()) = user_id or (select private.is_admin()));

-- 17. Delivery Status Log & Finalized Record Triggers
create or replace function public.log_delivery_status_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (tg_op = 'INSERT') or (old.status is distinct from new.status) then
    insert into public.delivery_status_logs (request_id, status, changed_by, remarks)
    values (
      new.id,
      new.status,
      (select auth.uid()),
      case
        when tg_op = 'INSERT' then 'Request submitted'
        else 'Status changed to ' || new.status
      end
    );
  end if;

  if new.status in ('completed', 'cancelled', 'expired') then
    insert into public.delivery_records (
      request_id, customer_id, runner_id, final_status, estimated_price, delivery_fee, recorded_at
    )
    values (
      new.id, new.customer_id, new.runner_id, new.status, new.estimated_price, new.delivery_fee, now()
    )
    on conflict (request_id) do update set
      runner_id = excluded.runner_id,
      final_status = excluded.final_status,
      recorded_at = excluded.recorded_at;
  end if;

  return new;
end;
$$;

revoke all on function public.log_delivery_status_change() from public, anon, authenticated;

drop trigger if exists on_delivery_finalized on public.delivery_requests;
drop trigger if exists on_delivery_status_changed on public.delivery_requests;
create trigger on_delivery_status_changed
  after insert or update of status on public.delivery_requests
  for each row execute function public.log_delivery_status_change();

-- 18. Atomic FCFS Claim (with Duty Lock + Daily Limit), Cancel, Expiration, and Handover RPCs
create or replace function public.claim_delivery_request(p_order_id uuid)
returns setof public.delivery_requests
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_account_type text;
  v_verification_status text;
  v_cor_verified boolean;
  v_daily_limit integer := 5;
  v_buffer_minutes integer := 15;
  v_completed_today integer := 0;
  v_schedule_count integer := 0;
  v_manila_now timestamp;
  v_day_start_utc timestamp with time zone;
  v_current_day text;
  v_current_minutes integer;
  v_blocked_subject text;
begin
  if v_uid is null then
    raise exception 'Authentication required to claim a delivery request.';
  end if;

  select account_type, verification_status, cor_verified
    into v_account_type, v_verification_status, v_cor_verified
    from public.profiles
    where id = v_uid;

  if v_account_type is distinct from 'student'
     or v_verification_status is distinct from 'verified'
     or v_cor_verified is not true then
    raise exception 'Only verified student runners with a confirmed COR schedule can claim requests.';
  end if;

  select coalesce(nullif(config_value, '')::integer, 5)
    into v_daily_limit
    from public.system_configurations
    where config_key = 'daily_delivery_limit';
  v_daily_limit := coalesce(v_daily_limit, 5);

  select coalesce(nullif(config_value, '')::integer, 15)
    into v_buffer_minutes
    from public.system_configurations
    where config_key = 'pre_class_buffer_minutes';
  v_buffer_minutes := coalesce(v_buffer_minutes, 15);

  select count(*)
    into v_schedule_count
    from public.runner_schedules
    where user_id = v_uid;

  if v_schedule_count = 0 then
    raise exception 'Academic Duty Lock active: no verified COR schedule found.';
  end if;

  v_manila_now := timezone('Asia/Manila', now());
  v_current_day := lower(trim(to_char(v_manila_now, 'FMDay')));
  v_current_minutes := extract(hour from v_manila_now)::integer * 60
                     + extract(minute from v_manila_now)::integer;

  select rs.subject
    into v_blocked_subject
    from public.runner_schedules rs
    where rs.user_id = v_uid
      and lower(trim(rs.day)) = v_current_day
      and rs.start_time ~ '^\d{1,2}:\d{2}$'
      and rs.end_time ~ '^\d{1,2}:\d{2}$'
      and v_current_minutes >= (
        split_part(rs.start_time, ':', 1)::integer * 60
        + split_part(rs.start_time, ':', 2)::integer
        - v_buffer_minutes
      )
      and v_current_minutes <= (
        split_part(rs.end_time, ':', 1)::integer * 60
        + split_part(rs.end_time, ':', 2)::integer
      )
    limit 1;

  if v_blocked_subject is not null then
    raise exception 'Academic Duty Lock active for % (%-minute pre-class buffer).', v_blocked_subject, v_buffer_minutes;
  end if;

  v_day_start_utc := (date_trunc('day', v_manila_now) at time zone 'Asia/Manila');

  select count(*)
    into v_completed_today
    from public.delivery_requests
    where runner_id = v_uid
      and status = 'completed'
      and completed_at >= v_day_start_utc;

  if v_daily_limit > 0 and v_completed_today >= v_daily_limit then
    raise exception 'Daily delivery limit reached (%/% completed today).', v_completed_today, v_daily_limit;
  end if;

  return query
  update public.delivery_requests
     set status = 'claimed',
         runner_id = v_uid,
         claimed_at = timezone('utc'::text, now()),
         updated_at = timezone('utc'::text, now())
   where id = p_order_id
     and status = 'pending'
     and (expires_at is null or expires_at > timezone('utc'::text, now()))
   returning *;
end;
$$;

revoke all on function public.claim_delivery_request(uuid) from public, anon;
grant execute on function public.claim_delivery_request(uuid) to authenticated;

create or replace function public.cancel_delivery_request(p_order_id uuid)
returns setof public.delivery_requests
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null then
    raise exception 'Authentication required to cancel a request.';
  end if;

  return query
  update public.delivery_requests
     set status = 'cancelled',
         cancelled_at = timezone('utc'::text, now()),
         updated_at = timezone('utc'::text, now())
   where id = p_order_id
     and status = 'pending'
     and (customer_id is null or customer_id = v_uid)
   returning *;
end;
$$;

revoke all on function public.cancel_delivery_request(uuid) from public, anon;
grant execute on function public.cancel_delivery_request(uuid) to authenticated;

create or replace function public.verify_and_complete_delivery(p_order_id uuid, p_code text)
returns setof public.delivery_requests
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_trimmed text := trim(coalesce(p_code, ''));
begin
  if v_uid is null then
    raise exception 'Authentication required to complete a delivery.';
  end if;

  if length(v_trimmed) <> 4 then
    return;
  end if;

  return query
  update public.delivery_requests
     set status = 'completed',
         completed_at = timezone('utc'::text, now()),
         updated_at = timezone('utc'::text, now())
   where id = p_order_id
     and status = 'arrived'
     and verification_code = v_trimmed
     and (runner_id is null or runner_id = v_uid)
   returning *;
end;
$$;

revoke all on function public.verify_and_complete_delivery(uuid, text) from public, anon;
grant execute on function public.verify_and_complete_delivery(uuid, text) to authenticated;

create or replace function public.expire_stale_delivery_requests()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_count integer;
begin
  if v_uid is null then
    raise exception 'Authentication required.';
  end if;

  update public.delivery_requests
     set status = 'expired',
         updated_at = timezone('utc'::text, now())
   where status = 'pending'
     and expires_at is not null
     and expires_at <= timezone('utc'::text, now());
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.expire_stale_delivery_requests() from public, anon;
grant execute on function public.expire_stale_delivery_requests() to authenticated;

-- 19. Auto-create profile trigger on auth signup (sanitizes user_metadata to prevent privilege escalation)
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_raw_type text := new.raw_user_meta_data->>'account_type';
  v_account_type text := case
    when v_raw_type in ('student', 'faculty_staff') then v_raw_type
    else 'student'
  end;
begin
  insert into public.profiles (
    id,
    full_name,
    email,
    phone_number,
    student_id,
    role,
    account_type,
    verification_status,
    cor_verified,
    id_document_path,
    cor_document_path
  )
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    new.email,
    coalesce(new.raw_user_meta_data->>'phone_number', ''),
    coalesce(new.raw_user_meta_data->>'student_id', ''),
    'customer',
    v_account_type,
    'pending',
    case
      when v_account_type = 'student' then coalesce((new.raw_user_meta_data->>'cor_verified')::boolean, false)
      else false
    end,
    new.raw_user_meta_data->>'id_document_path',
    new.raw_user_meta_data->>'cor_document_path'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

revoke all on function public.handle_new_user() from public, anon, authenticated;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 20. Backfill any existing auth users into public.profiles safely
insert into public.profiles (id, full_name, email, phone_number, student_id, role, account_type, verification_status, cor_verified)
select
  id,
  coalesce(raw_user_meta_data->>'full_name', ''),
  email,
  coalesce(raw_user_meta_data->>'phone_number', ''),
  coalesce(raw_user_meta_data->>'student_id', ''),
  'customer',
  case
    when raw_user_meta_data->>'account_type' in ('student', 'faculty_staff')
      then raw_user_meta_data->>'account_type'
    else 'student'
  end,
  'pending',
  coalesce((raw_user_meta_data->>'cor_verified')::boolean, false)
from auth.users
on conflict (id) do nothing;

-- 21. Supabase Storage Bucket & Policies (Users own folder + Admins read all)
insert into storage.buckets (id, name, public)
values ('verification-documents', 'verification-documents', false)
on conflict (id) do nothing;

create policy "Users upload own verification docs"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'verification-documents'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "Users read own verification docs"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'verification-documents'
    and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or (select private.is_admin())
    )
  );

create policy "Users update own verification docs"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'verification-documents'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'verification-documents'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- 22. Enable Realtime on delivery_requests table safely
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'delivery_requests'
  ) then
    alter publication supabase_realtime add table public.delivery_requests;
  end if;
end $$;
