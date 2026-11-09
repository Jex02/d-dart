-- ============================================================
-- D-DART SUPABASE DATABASE SCHEMA
-- Run this in your Supabase Dashboard -> SQL Editor -> Run
-- ============================================================

-- 1. Create Profiles Table (linked to Supabase Auth)
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  email text,
  phone_number text,
  student_id text,
  role text default 'customer' check (role in ('customer', 'runner', 'admin')),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now())
);

-- 2. Create Delivery Requests / Pabili Table
create table if not exists public.delivery_requests (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid references public.profiles(id) on delete set null,
  runner_id uuid references public.profiles(id) on delete set null,
  pickup_location text not null,
  dropoff_location text not null,
  description text not null,
  estimated_price numeric(10,2) not null default 0.00,
  delivery_fee numeric(10,2) not null default 20.00,
  status text not null default 'pending' check (status in ('pending', 'claimed', 'purchasing', 'en_route', 'arrived', 'completed', 'cancelled')),
  verification_code text not null,
  special_instructions text default '',
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now())
);

-- 3. Create Runner Schedules Table (for COR Duty Lock)
create table if not exists public.runner_schedules (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade,
  day text not null,
  start_time text not null,
  end_time text not null,
  subject text not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 4. Enable Row Level Security (RLS)
alter table public.profiles enable row level security;
alter table public.delivery_requests enable row level security;
alter table public.runner_schedules enable row level security;

-- 5. RLS Policies for Profiles
drop policy if exists "Allow authenticated read profiles" on public.profiles;
create policy "Allow authenticated read profiles"
  on public.profiles for select
  to authenticated
  using (true);

drop policy if exists "Allow users to update their own profile" on public.profiles;
create policy "Allow users to update their own profile"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id);

drop policy if exists "Allow users to insert their own profile" on public.profiles;
create policy "Allow users to insert their own profile"
  on public.profiles for insert
  to authenticated
  with check (auth.uid() = id);

-- 6. RLS Policies for Delivery Requests
drop policy if exists "Allow read delivery requests" on public.delivery_requests;
create policy "Allow read delivery requests"
  on public.delivery_requests for select
  to authenticated
  using (true);

drop policy if exists "Allow insert delivery requests" on public.delivery_requests;
create policy "Allow insert delivery requests"
  on public.delivery_requests for insert
  to authenticated
  with check (true);

drop policy if exists "Allow update delivery requests" on public.delivery_requests;
create policy "Allow update delivery requests"
  on public.delivery_requests for update
  to authenticated
  using (true);

-- 7. RLS Policies for Runner Schedules
drop policy if exists "Allow read runner schedules" on public.runner_schedules;
create policy "Allow read runner schedules"
  on public.runner_schedules for select
  to authenticated
  using (true);

drop policy if exists "Allow users manage their schedules" on public.runner_schedules;
create policy "Allow users manage their schedules"
  on public.runner_schedules for all
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- 8. Auto-create profile trigger on auth signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, full_name, email, phone_number, student_id, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    new.email,
    coalesce(new.raw_user_meta_data->>'phone_number', ''),
    coalesce(new.raw_user_meta_data->>'student_id', ''),
    coalesce(new.raw_user_meta_data->>'role', 'customer')
  )
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 9. Backfill any existing auth users into public.profiles
insert into public.profiles (id, full_name, email, phone_number, student_id, role)
select 
  id,
  coalesce(raw_user_meta_data->>'full_name', ''),
  email,
  coalesce(raw_user_meta_data->>'phone_number', ''),
  coalesce(raw_user_meta_data->>'student_id', ''),
  coalesce(raw_user_meta_data->>'role', 'customer')
from auth.users
on conflict (id) do nothing;

-- 10. Enable Realtime on delivery_requests table
alter publication supabase_realtime add table public.delivery_requests;
