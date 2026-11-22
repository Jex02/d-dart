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
alter table public.profiles add column if not exists assigned_canteen text;

alter table public.profiles drop constraint if exists profiles_assigned_canteen_check;
alter table public.profiles add constraint profiles_assigned_canteen_check
  check (
    assigned_canteen is null
    or assigned_canteen in ('Main Canteen', 'Highschool Canteen', 'Mini Canteen')
  );

create index if not exists idx_profiles_assigned_canteen
  on public.profiles (assigned_canteen)
  where assigned_canteen is not null;

alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles add constraint profiles_role_check
  check (role in ('customer', 'runner', 'admin'));

alter table public.profiles drop constraint if exists profiles_account_type_check;
alter table public.profiles add constraint profiles_account_type_check
  check (account_type in ('student', 'faculty_staff', 'admin'));

alter table public.profiles drop constraint if exists profiles_verification_status_check;
alter table public.profiles add constraint profiles_verification_status_check
  check (verification_status in ('pending', 'verified', 'rejected'));

-- Enforce unique non-empty Student / Employee IDs (case-insensitive, trimmed)
create unique index if not exists idx_profiles_unique_student_id
  on public.profiles (upper(trim(student_id)))
  where nullif(trim(student_id), '') is not null;

-- Helper functions in private schema to check admin/canteen-admin privileges without RLS recursion
-- Super Admin = admin with assigned_canteen IS NULL
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
      and assigned_canteen is null
  );
$$;

create or replace function private.assigned_canteen()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select assigned_canteen
  from public.profiles
  where id = (select auth.uid())
    and (account_type = 'admin' or role = 'admin')
    and assigned_canteen is not null
  limit 1;
$$;

revoke all on function private.is_admin() from public, anon;
grant execute on function private.is_admin() to authenticated;

revoke all on function private.assigned_canteen() from public, anon;
grant execute on function private.assigned_canteen() to authenticated;

-- 2. Campus Pickup & Drop-off Locations Directory
create table if not exists public.locations (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  category text not null check (category in ('pickup', 'dropoff')),
  building_code text default '',
  is_active boolean not null default true,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

insert into public.locations (name, category, building_code, is_active) values
  ('Main Canteen', 'pickup', 'MC', true),
  ('Highschool Canteen', 'pickup', 'HSC', true),
  ('Mini Canteen', 'pickup', 'MINI', true),
  ('Backgate Annex', 'dropoff', 'BGA', true),
  ('GLE', 'dropoff', 'GLE', true),
  ('G-LECROOM', 'dropoff', 'G-LECROOM', true),
  ('NGE', 'dropoff', 'NGE', true),
  ('Allied', 'dropoff', 'ALLIED', true),
  ('SAL', 'dropoff', 'SAL', true),
  ('ACAD', 'dropoff', 'ACAD', true),
  ('RTL', 'dropoff', 'RTL', true),
  ('Physics Lab', 'dropoff', 'G-PHYSLAB', true),
  ('Gymnasium', 'dropoff', 'GYM', true),
  ('Covered Courts', 'dropoff', 'COURTS', true)
on conflict (name) do update set
  category = excluded.category,
  building_code = excluded.building_code,
  is_active = excluded.is_active;

-- Ensure non-permitted or legacy locations are inactive per official campus rules
update public.locations
set is_active = false
where name in ('University Library', 'College Library', 'Engineering Building', 'High School Canteen', 'College Canteen', 'Elementary Canteen', 'Campus Kiosks');

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
  ('standard_delivery_fee', '20.00', 'Standard campus delivery fee in PHP'),
  ('delivery_fee_short', '20.00', 'Delivery fee for distances up to 100 meters'),
  ('delivery_fee_medium', '25.00', 'Delivery fee for distances over 100 up to 200 meters'),
  ('delivery_fee_long', '30.00', 'Delivery fee for distances over 200 meters'),
  ('delivery_distance_short_max', '100', 'Maximum distance in meters for the short delivery tier'),
  ('delivery_distance_medium_max', '200', 'Maximum distance in meters for the medium delivery tier')
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

-- Enforce that a customer can never claim their own order at the table constraint level (Task 3)
alter table public.delivery_requests drop constraint if exists delivery_requests_runner_not_customer;
alter table public.delivery_requests add constraint delivery_requests_runner_not_customer
  check (runner_id is null or customer_id is null or customer_id is distinct from runner_id);

alter table public.delivery_requests replica identity full;

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
  reporter_role text check (reporter_role in ('customer', 'runner', 'admin')),
  reported_user_id uuid references public.profiles(id) on delete set null,
  category text not null check (category in ('wrong_item', 'late_delivery', 'payment_issue', 'runner_behavior', 'customer_behavior', 'unresponsive_user', 'wrong_location', 'canteen_issue', 'app_issue', 'other')),
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
  v_customer_id uuid;
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
  v_is_demo_runner boolean := false;
begin
  if v_uid is null then
    raise exception 'Authentication required to claim a delivery request.';
  end if;

  select customer_id
    into v_customer_id
    from public.delivery_requests
   where id = p_order_id;

  if v_customer_id is not null and v_customer_id = v_uid then
    raise exception 'You cannot claim your own delivery order.';
  end if;

  select account_type, verification_status, cor_verified
    into v_account_type, v_verification_status, v_cor_verified
    from public.profiles
    where id = v_uid;

  v_is_demo_runner := (v_uid = 'd8d46232-4eaa-4c44-8508-46207f0ea9d5'::uuid);

  if not v_is_demo_runner then
    if v_account_type is distinct from 'student'
       or v_verification_status is distinct from 'verified'
       or v_cor_verified is not true then
      raise exception 'Only verified student runners with a confirmed COR schedule can claim requests.';
    end if;
  else
    if v_verification_status is distinct from 'verified' then
      raise exception 'Demonstration runner account must have verified profile status.';
    end if;
  end if;

  select coalesce(nullif(config_value, '')::integer, 5)
    into v_daily_limit
    from public.system_configurations
    where config_key = 'daily_delivery_limit';
  v_daily_limit := coalesce(v_daily_limit, 5);

  if not v_is_demo_runner then
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
  else
    v_manila_now := timezone('Asia/Manila', now());
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
     and (customer_id is null or customer_id <> v_uid)
   returning *;
end;
$$;

revoke all on function public.claim_delivery_request(uuid) from public, anon;
grant execute on function public.claim_delivery_request(uuid) to authenticated;

-- Release mistakenly claimed order by runner (Task 5)
create or replace function public.release_claimed_order(p_order_id uuid)
returns setof public.delivery_requests
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null then
    raise exception 'Authentication required to release an order.';
  end if;

  return query
  update public.delivery_requests
     set status = 'pending',
         runner_id = null,
         claimed_at = null,
         updated_at = timezone('utc'::text, now())
   where id = p_order_id
     and runner_id = v_uid
     and status = 'claimed'
   returning *;
end;
$$;

revoke all on function public.release_claimed_order(uuid) from public, anon;
grant execute on function public.release_claimed_order(uuid) to authenticated;

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
    trim(coalesce(new.raw_user_meta_data->>'student_id', '')),
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

-- Lightweight boolean RPC so the signup screen can check ID uniqueness before OCR/auth signup
create or replace function public.is_student_id_available(p_student_id text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when nullif(trim(coalesce(p_student_id, '')), '') is null then false
    else not exists (
      select 1
      from public.profiles
      where upper(trim(student_id)) = upper(trim(p_student_id))
        and nullif(trim(student_id), '') is not null
    )
  end;
$$;

revoke all on function public.is_student_id_available(text) from public;
grant execute on function public.is_student_id_available(text) to anon, authenticated;

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

drop policy if exists "Order participants read counterpart ID photo" on storage.objects;
create policy "Order participants read counterpart ID photo"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'verification-documents'
    and lower(storage.filename(name)) like 'id_document.%'
    and exists (
      select 1
      from public.delivery_requests dr
      where dr.status in ('claimed', 'purchasing', 'en_route', 'arrived', 'completed')
        and (
          (dr.customer_id = (select auth.uid()) and dr.runner_id::text = (storage.foldername(name))[1])
          or (dr.runner_id = (select auth.uid()) and dr.customer_id::text = (storage.foldername(name))[1])
        )
    )
  );

create or replace function public.get_order_counterpart_profile(p_order_id uuid)
returns table (
  user_id uuid,
  full_name text,
  student_id text,
  account_type text,
  id_document_path text,
  counterpart_role text
)
language sql
stable
security definer
set search_path = ''
as $$
  with req as (
    select dr.customer_id, dr.runner_id, dr.status
    from public.delivery_requests dr
    where dr.id = p_order_id
      and dr.status in ('claimed', 'purchasing', 'en_route', 'arrived', 'completed')
      and (
        dr.customer_id = (select auth.uid())
        or dr.runner_id = (select auth.uid())
      )
    limit 1
  )
  select
    p.id as user_id,
    p.full_name,
    p.student_id,
    p.account_type,
    p.id_document_path,
    case
      when req.customer_id = (select auth.uid()) and req.runner_id is not null then 'runner'
      else 'customer'
    end as counterpart_role
  from req
  join public.profiles p
    on p.id = case
      when req.customer_id = (select auth.uid()) and req.runner_id is not null then req.runner_id
      else req.customer_id
    end;
$$;

revoke all on function public.get_order_counterpart_profile(uuid) from public, anon;
grant execute on function public.get_order_counterpart_profile(uuid) to authenticated;

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


-- ============================================================
-- 23. Canteen Menu Items Table & Seed Data
-- ============================================================
create table if not exists public.canteen_menu_items (
  id text primary key,
  name text not null,
  canteen text not null default 'Main Canteen',
  category text not null,
  price numeric(10,2) not null,
  unit_description text default '',
  image_url text,
  is_available boolean not null default true,
  available_canteens text[] default '{}',
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create index if not exists idx_canteen_menu_items_category on public.canteen_menu_items (category);
create index if not exists idx_canteen_menu_items_canteen on public.canteen_menu_items (canteen);

alter table public.canteen_menu_items enable row level security;

drop policy if exists "Allow read active menu items" on public.canteen_menu_items;
create policy "Allow read active menu items"
  on public.canteen_menu_items for select
  using (is_available = true);

drop policy if exists "Allow admins manage menu items" on public.canteen_menu_items;
create policy "Allow admins manage menu items"
  on public.canteen_menu_items for all
  using (private.is_admin());

grant select on public.canteen_menu_items to anon, authenticated;
grant all on public.canteen_menu_items to authenticated;

insert into public.canteen_menu_items (id, name, canteen, category, price, unit_description, image_url, available_canteens) values
  ('food-siomai', 'Pork Siomai with rice', 'Main Canteen', 'Food and snacks', 30.00, '3 for 30 Pesos with chili garlic & calamansi', 'https://images.unsplash.com/photo-1541696432-82c6da8ce7bf?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'Mini Canteen']),
  ('food-burger', 'Burger', 'Main Canteen', 'Food and snacks', 35.00, 'Classic burger with dressing', 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'Mini Canteen']),
  ('food-cheeseburger', 'Cheesy Bacon Burger', 'Main Canteen', 'Food and snacks', 45.00, 'Burger with cheddar cheese slice & crispy bacon', 'https://images.unsplash.com/photo-1550547660-d9450f859349?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'Mini Canteen']),
  ('food-egg-rice', 'Egg w/ rice', 'Main Canteen', 'Food and snacks', 25.00, 'Sunny side up with garlic fried rice', 'https://images.unsplash.com/photo-1525351484163-7529414344d8?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'Highschool Canteen']),
  ('food-pancit', 'Pancit Canton', 'Main Canteen', 'Food and snacks', 25.00, 'With boiled egg & calamansi', 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'Mini Canteen', 'Highschool Canteen']),
  ('food-tocilog', 'Tocilog', 'Main Canteen', 'Food and snacks', 55.00, 'Sweet pork tocino, egg & sinangag', 'https://images.unsplash.com/photo-1543339308-43e59d6b73a6?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'Mini Canteen']),
  ('food-tapsilog', 'Tapsilog Special', 'Mini Canteen', 'Food and snacks', 65.00, 'Tender beef tapa with fried egg & garlic rice', 'https://images.unsplash.com/photo-1543339308-43e59d6b73a6?auto=format&fit=crop&w=400&q=80', array['Mini Canteen', 'Main Canteen']),
  ('food-bangsilog', 'Bangsilog', 'Main Canteen', 'Food and snacks', 60.00, 'Pan-fried daing na bangus with egg & rice', 'https://images.unsplash.com/photo-1543339308-43e59d6b73a6?auto=format&fit=crop&w=400&q=80', array['Main Canteen']),
  ('food-sisig', 'Pork Sisig w/ Rice', 'Mini Canteen', 'Food and snacks', 60.00, 'Sizzling savory pork sisig with egg & calamansi', 'https://images.unsplash.com/photo-1626777552726-4a6b54c97e46?auto=format&fit=crop&w=400&q=80', array['Mini Canteen', 'Main Canteen']),
  ('food-hotdog', 'Hotdog', 'Main Canteen', 'Food and snacks', 20.00, 'Classic grilled red hotdog with dressing', 'https://images.unsplash.com/photo-1619740455993-9e612b1af08a?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'Mini Canteen', 'Highschool Canteen']),
  ('food-footlong', 'Footlong', 'Main Canteen', 'Food and snacks', 40.00, 'Footlong hotdog sandwich with cheese & ketchup', 'https://images.unsplash.com/photo-1627059173079-58ec789fc57d?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'Mini Canteen']),
  ('food-corndog', 'Mozzarella Corndog', 'Mini Canteen', 'Food and snacks', 45.00, 'Half mozzarella half sausage with honey mustard', 'https://images.unsplash.com/photo-1627059173079-58ec789fc57d?auto=format&fit=crop&w=400&q=80', array['Mini Canteen', 'Main Canteen']),
  ('food-nuggets', 'Chicken Nuggets w/ Rice', 'Highschool Canteen', 'Food and snacks', 45.00, '4 pcs crispy nuggets with BBQ sauce & rice', 'https://images.unsplash.com/photo-1562967914-608f82629710?auto=format&fit=crop&w=400&q=80', array['Highschool Canteen', 'Main Canteen']),
  ('food-fries', 'Cheese French Fries', 'Mini Canteen', 'Food and snacks', 30.00, 'Crispy crinkle-cut fries coated in cheese powder', 'https://images.unsplash.com/photo-1576107232684-1279f3908594?auto=format&fit=crop&w=400&q=80', array['Mini Canteen', 'Highschool Canteen']),
  ('food-lumpia', 'Shanghai Rolls w/ Rice', 'Main Canteen', 'Food and snacks', 35.00, '4 pcs crispy pork lumpia with sweet chili sauce', 'https://images.unsplash.com/photo-1541696432-82c6da8ce7bf?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'Mini Canteen']),
  ('food-shawarma', 'Beef Shawarma Rice', 'Main Canteen', 'Food and snacks', 55.00, 'Spiced beef shawarma with garlic cucumber sauce', 'https://images.unsplash.com/photo-1529006557810-274b9b2fc783?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'Mini Canteen']),
  ('food-kwek', 'Kwek-Kwek & Fishballs', 'Mini Canteen', 'Food and snacks', 20.00, '4 pcs quail eggs & 5 fishballs with sweet brown sauce', 'https://images.unsplash.com/photo-1563245372-f21724e3856d?auto=format&fit=crop&w=400&q=80', array['Mini Canteen', 'Main Canteen']),
  ('food-porkchop', 'Breaded Porkchop w/ Rice', 'Mini Canteen', 'Food and snacks', 60.00, 'Golden deep-fried porkchop with mushroom gravy', 'https://images.unsplash.com/photo-1543339308-43e59d6b73a6?auto=format&fit=crop&w=400&q=80', array['Mini Canteen', 'Main Canteen']),
  ('bev-dew', 'Mountain dew (Plastic bottle)', 'Main Canteen', 'Beverages', 25.00, '25 Pesos/bottle 500ml', 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'Mini Canteen', 'Highschool Canteen']),
  ('bev-coke', 'Coca-Cola Mismo', 'Main Canteen', 'Beverages', 20.00, '300ml chilled bottle', 'https://images.unsplash.com/photo-1554866585-cd94860890b7?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'Mini Canteen', 'Highschool Canteen']),
  ('bev-sprite', 'Sprite Mismo', 'Main Canteen', 'Beverages', 20.00, '300ml chilled lemon-lime soda', 'https://images.unsplash.com/photo-1625772299848-391b6a87d7b3?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'Mini Canteen']),
  ('bev-royal', 'Royal Tru-Orange Mismo', 'Highschool Canteen', 'Beverages', 20.00, '300ml chilled orange soda', 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?auto=format&fit=crop&w=400&q=80', array['Highschool Canteen', 'Main Canteen']),
  ('bev-c2', 'C2 Green Tea Apple', 'Main Canteen', 'Beverages', 20.00, '500ml chilled bottle', 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'Mini Canteen', 'Highschool Canteen']),
  ('bev-c2-lemon', 'C2 Green Tea Lemon', 'Main Canteen', 'Beverages', 20.00, '500ml chilled bottle', 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'Mini Canteen']),
  ('bev-water', 'Mineral Water 500ml', 'Main Canteen', 'Beverages', 15.00, '500ml purified cold bottle', 'https://images.unsplash.com/photo-1559839914-1b39868735df?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'Mini Canteen', 'Highschool Canteen']),
  ('bev-water-1l', 'Nature Spring 1 Liter', 'Main Canteen', 'Beverages', 25.00, '1 Liter cold purified water', 'https://images.unsplash.com/photo-1559839914-1b39868735df?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'Mini Canteen']),
  ('bev-calamansi', 'Fresh Calamansi Juice', 'Main Canteen', 'Beverages', 20.00, '16oz freshly squeezed cold cup with honey', 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'Mini Canteen']),
  ('bev-iced-tea', 'House Iced Tea', 'Main Canteen', 'Beverages', 15.00, '16oz sweet refreshing iced tea with ice', 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'Mini Canteen', 'Highschool Canteen']),
  ('bev-coffee', 'Iced Coffee Latte', 'Mini Canteen', 'Beverages', 35.00, '16oz cold brewed coffee with milk & syrup', 'https://images.unsplash.com/photo-1517701550927-30cf4ba1dba5?auto=format&fit=crop&w=400&q=80', array['Mini Canteen', 'Main Canteen']),
  ('bev-milo', 'Iced Milo Dinosaur', 'Mini Canteen', 'Beverages', 30.00, 'Cold chocolate milk with extra Milo powder', 'https://images.unsplash.com/photo-1541658016709-82535e94bc69?auto=format&fit=crop&w=400&q=80', array['Mini Canteen', 'Highschool Canteen']),
  ('bev-gulaman', 'Sago''t Gulaman Cooler', 'Mini Canteen', 'Beverages', 15.00, 'Sweet brown sugar cooler with sago pearls & jelly', 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?auto=format&fit=crop&w=400&q=80', array['Mini Canteen', 'Main Canteen']),
  ('bev-juice', 'Orange Juice Box', 'Highschool Canteen', 'Beverages', 18.00, '250ml tetra pack with straw', 'https://images.unsplash.com/photo-1613478223719-2ab802602423?auto=format&fit=crop&w=400&q=80', array['Highschool Canteen', 'Main Canteen']),
  ('bev-chuckie', 'Nestle Chuckie Box', 'Highschool Canteen', 'Beverages', 25.00, '250ml chilled chocolate box', 'https://images.unsplash.com/photo-1541658016709-82535e94bc69?auto=format&fit=crop&w=400&q=80', array['Highschool Canteen', 'Mini Canteen']),
  ('des-banana', 'Banana', 'Main Canteen', 'Desserts', 15.00, '15 pesos/fruit fresh sweet banana', 'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'Mini Canteen', 'Highschool Canteen']),
  ('des-turon', 'Turon (2 pcs)', 'Main Canteen', 'Desserts', 20.00, 'Crispy caramelized banana roll with jackfruit', 'https://images.unsplash.com/photo-1587314168485-3236d6710814?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'Mini Canteen']),
  ('des-halohalo', 'Special Halo-Halo', 'Main Canteen', 'Desserts', 45.00, 'Shaved ice with ube, leche flan & milk', 'https://images.unsplash.com/photo-1563805042-7684c019e1cb?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'Mini Canteen']),
  ('des-waffle', 'Belgian Chocolate Waffle', 'Mini Canteen', 'Desserts', 30.00, 'Crispy waffle with chocolate dip', 'https://images.unsplash.com/photo-1562376552-0d160a2f238d?auto=format&fit=crop&w=400&q=80', array['Mini Canteen', 'Main Canteen']),
  ('des-waffle-cheese', 'Belgian Cheese Waffle', 'Mini Canteen', 'Desserts', 30.00, 'Crispy waffle with melted cheese', 'https://images.unsplash.com/photo-1562376552-0d160a2f238d?auto=format&fit=crop&w=400&q=80', array['Mini Canteen', 'Main Canteen']),
  ('des-cookies', 'Chocolate Chip Cookies (3 pcs)', 'Highschool Canteen', 'Desserts', 20.00, 'Freshly baked chocolate cookies', 'https://images.unsplash.com/photo-1499636136210-6f4ee915583e?auto=format&fit=crop&w=400&q=80', array['Highschool Canteen', 'Main Canteen']),
  ('des-mango-float', 'Mango Float Cup', 'Main Canteen', 'Desserts', 40.00, 'Layered graham crackers, cream & fresh mango', 'https://images.unsplash.com/photo-1563805042-7684c019e1cb?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'Mini Canteen']),
  ('des-lecheflan', 'Leche Flan Slice', 'Main Canteen', 'Desserts', 30.00, 'Caramel custard flan slice', 'https://images.unsplash.com/photo-1587314168485-3236d6710814?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'Mini Canteen']),
  ('des-cornetto', 'Cornetto Ice Cream Cone', 'Main Canteen', 'Desserts', 35.00, 'Drumstick cone with chocolate tip', 'https://images.unsplash.com/photo-1563805042-7684c019e1cb?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'Mini Canteen', 'Highschool Canteen']),
  ('des-donut', 'Choco Glazed Donut', 'Mini Canteen', 'Desserts', 25.00, 'Soft ring donut with thick chocolate glaze', 'https://images.unsplash.com/photo-1527515862127-a4fc05baf7a5?auto=format&fit=crop&w=400&q=80', array['Mini Canteen', 'Highschool Canteen']),
  ('des-pichi', 'Pichi-Pichi with Cheese', 'Mini Canteen', 'Desserts', 25.00, '4 pcs chewy cassava cake with cheese', 'https://images.unsplash.com/photo-1587314168485-3236d6710814?auto=format&fit=crop&w=400&q=80', array['Mini Canteen', 'Main Canteen'])
on conflict (id) do update set
  name = excluded.name,
  canteen = excluded.canteen,
  category = excluded.category,
  price = excluded.price,
  unit_description = excluded.unit_description,
  image_url = excluded.image_url,
  available_canteens = excluded.available_canteens,
  is_available = excluded.is_available;

-- ============================================================
-- 24. Order Direct Messaging Table & Realtime Setup
-- Allows live chat between customer and assigned runner
-- ============================================================
create table if not exists public.order_messages (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.delivery_requests(id) on delete cascade,
  sender_id uuid references auth.users(id) on delete set null,
  sender_role text not null check (sender_role in ('customer', 'runner', 'system')),
  sender_name text not null default '',
  message text not null check (length(trim(message)) > 0),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create index if not exists idx_order_messages_order_created
  on public.order_messages (order_id, created_at asc);

create index if not exists idx_order_messages_sender_id
  on public.order_messages (sender_id);

alter table public.order_messages enable row level security;

-- SELECT policy: participants (customer or assigned runner) of the order or admin can read messages
drop policy if exists "Allow participants read order messages" on public.order_messages;
create policy "Allow participants read order messages"
  on public.order_messages for select
  to authenticated
  using (
    exists (
      select 1
      from public.delivery_requests dr
      where dr.id = order_messages.order_id
        and (
          dr.customer_id = (select auth.uid())
          or dr.runner_id = (select auth.uid())
        )
    )
    or (select private.is_admin())
  );

-- INSERT policy: authenticated user can send message if they are customer or assigned runner
drop policy if exists "Allow participants insert order messages" on public.order_messages;
create policy "Allow participants insert order messages"
  on public.order_messages for insert
  to authenticated
  with check (
    sender_id = (select auth.uid())
    and exists (
      select 1
      from public.delivery_requests dr
      where dr.id = order_messages.order_id
        and (
          (dr.customer_id = (select auth.uid()) and sender_role = 'customer')
          or (dr.runner_id = (select auth.uid()) and sender_role = 'runner')
        )
        and dr.status in ('claimed', 'purchasing', 'en_route', 'arrived', 'completed')
    )
  );

grant select, insert on public.order_messages to authenticated;

-- Enable Supabase Realtime for order_messages safely
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'order_messages'
  ) then
    alter publication supabase_realtime add table public.order_messages;
  end if;
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'problem_reports'
  ) then
    alter publication supabase_realtime add table public.problem_reports;
  end if;
end $$;

-- 25. Secure Admin Problem Reports RPC with Enriched Context
create or replace function public.fetch_admin_problem_reports()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_is_super_admin boolean;
  v_result jsonb;
begin
  select exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and (account_type = 'admin' or role = 'admin')
      and assigned_canteen is null
  ) into v_is_super_admin;

  if not v_is_super_admin then
    raise exception 'Access denied: Super Admin privilege required';
  end if;

  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_result
  from (
    select 
      pr.id,
      pr.request_id,
      pr.reporter_id,
      coalesce(pr.reporter_role, rep.role, 'customer') as reporter_role,
      pr.reported_user_id,
      pr.category,
      pr.description,
      pr.status,
      coalesce(pr.admin_notes, '') as admin_notes,
      pr.reviewed_by,
      pr.created_at,
      pr.updated_at,
      rep.full_name as reporter_name,
      rep.email as reporter_email,
      rep.phone_number as reporter_phone,
      rep.student_id as reporter_student_id,
      target.full_name as reported_user_name,
      target.email as reported_user_email,
      target.role as reported_user_role,
      dr.pickup_location,
      dr.dropoff_location,
      dr.description as order_description,
      dr.status as order_status,
      dr.estimated_price as order_estimated_price,
      dr.delivery_fee as order_delivery_fee,
      admin_prof.full_name as reviewer_name
    from public.problem_reports pr
    left join public.profiles rep on pr.reporter_id = rep.id
    left join public.profiles target on pr.reported_user_id = target.id
    left join public.delivery_requests dr on pr.request_id = dr.id
    left join public.profiles admin_prof on pr.reviewed_by = admin_prof.id
    order by pr.created_at desc
  ) r;

  return v_result;
end;
$$;

revoke all on function public.fetch_admin_problem_reports() from public, anon;
grant execute on function public.fetch_admin_problem_reports() to authenticated;

-- ============================================================
-- 26. Persistent Customer Carts (Task 2)
-- ============================================================
create table if not exists public.customer_carts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  items jsonb not null default '[]'::jsonb,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.customer_carts enable row level security;

drop policy if exists "Allow users manage own cart" on public.customer_carts;
create policy "Allow users manage own cart"
  on public.customer_carts for all
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

grant all on public.customer_carts to authenticated;

-- ============================================================
-- 27. Runner Reviews & Rating System (Tasks 8-10)
-- ============================================================
create table if not exists public.runner_reviews (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.delivery_requests(id) on delete cascade,
  runner_id uuid not null references public.profiles(id) on delete cascade,
  customer_id uuid not null references public.profiles(id) on delete cascade,
  rating integer not null check (rating >= 1 and rating <= 5),
  review_text text check (review_text is null or length(trim(review_text)) <= 1000),
  created_at timestamptz not null default now(),
  constraint runner_reviews_no_self_review check (customer_id <> runner_id)
);

create index if not exists idx_runner_reviews_runner_id on public.runner_reviews(runner_id);
create index if not exists idx_runner_reviews_customer_id on public.runner_reviews(customer_id);
create index if not exists idx_runner_reviews_order_id on public.runner_reviews(order_id);

alter table public.runner_reviews enable row level security;

create policy "Allow authenticated users to read runner reviews"
  on public.runner_reviews for select
  to authenticated
  using (true);

create policy "Allow order customer to insert review for completed order"
  on public.runner_reviews for insert
  to authenticated
  with check (
    auth.uid() = customer_id
    and customer_id <> runner_id
    and exists (
      select 1 from public.delivery_requests dr
      where dr.id = order_id
        and dr.customer_id = auth.uid()
        and dr.runner_id = runner_id
        and dr.status = 'completed'
    )
  );

create or replace function public.submit_runner_review(
  p_order_id uuid,
  p_rating int,
  p_review_text text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_uid uuid;
  v_order record;
  v_review_id uuid;
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'Unauthorized: Please log in to submit a review';
  end if;

  if p_rating < 1 or p_rating > 5 then
    raise exception 'Rating must be between 1 and 5 stars';
  end if;

  select * into v_order from public.delivery_requests where id = p_order_id;
  if not found then
    raise exception 'Delivery order not found';
  end if;

  if v_order.customer_id <> v_uid then
    raise exception 'Only the customer who placed this order can rate the runner';
  end if;

  if v_order.status <> 'completed' then
    raise exception 'Reviews can only be submitted for completed orders';
  end if;

  if v_order.runner_id is null then
    raise exception 'No runner is assigned to this order';
  end if;

  if v_order.runner_id = v_uid then
    raise exception 'You cannot review your own account';
  end if;

  if exists (select 1 from public.runner_reviews where order_id = p_order_id) then
    raise exception 'A review has already been submitted for this order';
  end if;

  insert into public.runner_reviews (
    order_id,
    runner_id,
    customer_id,
    rating,
    review_text,
    created_at
  ) values (
    p_order_id,
    v_order.runner_id,
    v_uid,
    p_rating,
    nullif(trim(p_review_text), ''),
    now()
  )
  returning id into v_review_id;

  return jsonb_build_object(
    'success', true,
    'review_id', v_review_id,
    'rating', p_rating,
    'message', 'Review submitted successfully'
  );
end;
$$;

create or replace view public.runner_performance_stats as
select 
  p.id as runner_id,
  p.full_name,
  p.email,
  p.student_id,
  p.id_document_path,
  p.role,
  p.account_type,
  p.verification_status,
  coalesce(del.completed_count, 0) as completed_deliveries,
  coalesce(rev.review_count, 0) as total_reviews,
  rev.avg_rating
from public.profiles p
left join (
  select runner_id, count(*)::int as completed_count
  from public.delivery_requests
  where status = 'completed' and runner_id is not null
  group by runner_id
) del on del.runner_id = p.id
left join (
  select 
    runner_id, 
    count(*)::int as review_count, 
    round(avg(rating)::numeric, 1)::float as avg_rating
  from public.runner_reviews
  group by runner_id
) rev on rev.runner_id = p.id
where p.role = 'runner' or p.account_type = 'student' or coalesce(del.completed_count, 0) > 0;

grant select on public.runner_performance_stats to authenticated;
grant execute on function public.submit_runner_review to authenticated;



