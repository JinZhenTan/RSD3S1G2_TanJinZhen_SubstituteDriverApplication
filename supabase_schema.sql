-- ============================================================================
-- Ganti - Substitute Driver App : Supabase schema
-- Run this in the Supabase dashboard -> SQL Editor. Safe to run more than once.
--so
-- The app has three account roles, stored in profiles.role:
--   'user'          - passenger / car owner (the main app)
--   'driver'        - substitute driver (accepts trips, drives them)
--   'service_staff' - car service pclauartner (collects, services, returns cars)
--
-- Row Level Security is enabled on every table. User-owned tables restrict to
-- auth.uid(); bookings / car_service_requests / profiles are readable by any
-- signed-in account (a driver needs to see unassigned jobs and the passenger's
-- profile) and writable by the owner or the assigned driver.
-- ============================================================================

-- ---- migration helpers (safe on an older database, no-ops on a fresh one) --
alter table if exists public.profiles
  add column if not exists role text not null default 'user';
-- A substitute driver drives the passenger's car and has no vehicle of their
-- own, so profiles no longer carries plate_number / car_model.
alter table if exists public.profiles
  drop column if exists plate_number,
  drop column if exists car_model;
alter table if exists public.bookings
  add column if not exists driver_lat double precision,
  add column if not exists driver_lng double precision;
alter table if exists public.bookings
  drop constraint if exists bookings_driver_id_fkey;
alter table if exists public.car_service_requests
  drop constraint if exists car_service_requests_driver_id_fkey;
alter table if exists public.car_service_requests
  add column if not exists final_labour numeric,
  add column if not exists final_parts numeric,
  add column if not exists final_inspection numeric,
  add column if not exists final_transport numeric;
alter table if exists public.car_service_requests
  add column if not exists pickup_lat double precision,
  add column if not exists pickup_lng double precision;
drop table if exists public.drivers cascade;
-- Module 4 (driver role) - Earnings screen: a driver's fixed monthly base pay
-- and the platform's cut of their trip fares. Per-driver so an admin could
-- later set different rates per account; defaults match what the app used
-- before this was configurable.
alter table if exists public.profiles
  add column if not exists basic_salary numeric not null default 800,
  add column if not exists earnings_deduction_rate numeric not null default 0.10;

-- ---- drop any policies from earlier versions of this file ------------------
do $$
declare r record;
begin
  for r in
    select policyname, tablename from pg_policies
    where schemaname = 'public'
      and tablename in ('profiles','vehicles','bookings','car_service_requests',
        'activity_messages','payment_methods','receipts','weather_alerts',
        'notification_settings')
  loop
    execute format('drop policy if exists %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

-- ---- profiles --------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  name text not null default 'Guest',
  role text not null default 'user',
  phone text,
  avatar_url text,
  rating numeric not null default 5.0,
  basic_salary numeric not null default 800,
  earnings_deduction_rate numeric not null default 0.10,
  created_at timestamptz not null default now()
);
alter table public.profiles enable row level security;
create policy "profiles read any" on public.profiles for select
  using (auth.uid() is not null);
create policy "profiles insert own" on public.profiles for insert
  with check (auth.uid() = id);
create policy "profiles update own" on public.profiles for update
  using (auth.uid() = id);
-- One-time backfill: a driver/service_staff row created by a manual insert
-- (per CLAUDE.md, worker accounts are inserted directly rather than through
-- the app's sign-up flow) may have explicitly set basic_salary /
-- earnings_deduction_rate to 0 rather than leaving them to the column
-- default - fix those up so Earnings shows a real number instead of RM 0.
update public.profiles set basic_salary = 800
  where role in ('driver', 'service_staff') and basic_salary = 0;
update public.profiles set earnings_deduction_rate = 0.10
  where role in ('driver', 'service_staff') and earnings_deduction_rate = 0;

-- ---- vehicles ------------------------------------------------------------------
create table if not exists public.vehicles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  plate_number text not null,
  model text not null,
  colour text not null,
  transmission text not null default 'Automatic',
  is_default boolean not null default false,
  created_at timestamptz not null default now()
);
-- A user can now register more than one vehicle - added after the table
-- shipped, so keep these idempotent.
alter table public.vehicles
  add column if not exists is_default boolean not null default false;
alter table public.vehicles
  add column if not exists created_at timestamptz not null default now();
alter table public.vehicles enable row level security;
-- The assigned substitute driver needs to see which car they are driving, so
-- any signed-in account can read a vehicle row; only the owner can write.
create policy "vehicles read any" on public.vehicles for select
  using (auth.uid() is not null);
create policy "vehicles write own" on public.vehicles for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---- bookings (Module 1) --------------------------------------------------
create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  driver_id uuid,
  pickup_lat double precision not null,
  pickup_lng double precision not null,
  pickup_address text not null,
  dest_lat double precision not null,
  dest_lng double precision not null,
  dest_address text not null,
  service_tier text not null default 'standard',
  fare_estimate numeric not null default 0,
  fare_final numeric,
  payment_method text not null default 'Cash',
  payment_status text not null default 'pending',
  status text not null default 'searching',
  driver_lat double precision,          -- live driver position (pushed by driver app)
  driver_lng double precision,
  driver_start_lat double precision,    -- where the driver was when they accepted
  driver_start_lng double precision,    -- used to draw the "driver -> pickup" route
  completed_by text,                    -- 'passenger' | 'driver' (force-completed)
  completion_note text,                 -- required reason when completed_by = 'driver'
  cancellation_reason text,             -- required once a driver was matched (enRoute+)
  vehicle_id uuid references public.vehicles (id), -- which of the passenger's cars
  created_at timestamptz not null default now()
);
-- Added after the table shipped, so keep these idempotent.
alter table public.bookings
  add column if not exists driver_start_lat double precision;
alter table public.bookings
  add column if not exists driver_start_lng double precision;
alter table public.bookings
  add column if not exists completed_by text;
alter table public.bookings
  add column if not exists completion_note text;
alter table public.bookings
  add column if not exists cancellation_reason text;
alter table public.bookings
  add column if not exists vehicle_id uuid references public.vehicles (id);
alter table public.bookings enable row level security;
create policy "bookings read any" on public.bookings for select
  using (auth.uid() is not null);
create policy "bookings insert own" on public.bookings for insert
  with check (auth.uid() = user_id);
create policy "bookings update owner or driver" on public.bookings for update
  using (auth.uid() = user_id or auth.uid() = driver_id or driver_id is null);

-- ---- service_centres (Module 3, seeded - app reads only) ---------------
create table if not exists public.service_centres (
  id text primary key,
  name text not null,
  address text not null,
  lat double precision not null,
  lng double precision not null,
  phone text not null,
  opening_hours text not null default 'Mon–Sat 9:00am–6:00pm'
);
alter table public.service_centres enable row level security;
drop policy if exists "service_centres read" on public.service_centres;
create policy "service_centres read" on public.service_centres
  for select using (auth.uid() is not null);
-- Only one physical service centre - back to TAR UMT Penang Branch (moved
-- to KOMTAR briefly, then reverted). The other seed rows (sc_komtar,
-- sc_gurney etc.) are left in place rather than deleted, since existing
-- car_service_requests rows may still reference them (service_centre_id is
-- a foreign key) and a job that already finished at one of those locations
-- should keep showing that history accurately - the app just never assigns
-- any of them to new jobs any more. Coordinates + address verified via
-- OpenStreetMap/Nominatim (tagged there as amenity=university for this
-- exact campus); phone number verified via the branch's public contact
-- listing.
insert into public.service_centres (id, name, address, lat, lng, phone, opening_hours) values
  ('sc_tarumt','TAR UMT Penang Branch','77, Lorong Lembah Permai 3, Permai Village, 11200 Tanjung Bungah, Penang',5.4522638,100.2850500,'+604-899 5230','Mon–Fri 9:00am–6:00pm')
on conflict (id) do update set
  name = excluded.name,
  address = excluded.address,
  lat = excluded.lat,
  lng = excluded.lng,
  phone = excluded.phone,
  opening_hours = excluded.opening_hours;

-- ---- car_service_requests (Module 3) ------------------------------------
create table if not exists public.car_service_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  vehicle_id uuid references public.vehicles (id),
  driver_id uuid,
  pickup_datetime timestamptz not null,
  pickup_address text not null,
  pickup_lat double precision,
  pickup_lng double precision,
  service_type text not null default 'general', -- first selected type; kept for old rows
  service_types text[] not null default array['general'], -- full multi-select
  cost_estimate_min integer not null default 0,
  cost_estimate_max integer not null default 0,
  final_cost numeric,               -- = sum of included + approved service_tasks
  final_labour numeric,             -- legacy lump-sum split (kept for old rows)
  final_parts numeric,
  final_inspection numeric,
  final_transport numeric,
  service_centre_id text references public.service_centres (id),
  staff_lat double precision,       -- live position of the service staff
  staff_lng double precision,
  assigned_at timestamptz,          -- status timeline
  picked_up_at timestamptz,
  at_centre_at timestamptz,
  returning_at timestamptz,         -- car left the centre, on its way back
  returned_at timestamptz,
  odometer_in integer,              -- reading at pick-up / at return
  odometer_out integer,
  ready_by timestamptz,             -- staff's completion estimate
  status text not null default 'requested',
  payment_status text not null default 'pending',
  notes text,
  cancellation_reason text,          -- required once cancelled (requested/assigned only)
  created_at timestamptz not null default now()
);
-- Added after the table shipped, so keep these idempotent.
alter table public.car_service_requests
  add column if not exists cancellation_reason text;
alter table public.car_service_requests
  add column if not exists service_types text[] not null default array['general'];
alter table public.car_service_requests
  add column if not exists service_centre_id text references public.service_centres (id),
  add column if not exists staff_lat double precision,
  add column if not exists staff_lng double precision,
  add column if not exists assigned_at timestamptz,
  add column if not exists picked_up_at timestamptz,
  add column if not exists at_centre_at timestamptz,
  add column if not exists returning_at timestamptz,
  add column if not exists returned_at timestamptz,
  add column if not exists odometer_in integer,
  add column if not exists odometer_out integer,
  add column if not exists ready_by timestamptz;
alter table public.car_service_requests enable row level security;
create policy "car_service read any" on public.car_service_requests for select
  using (auth.uid() is not null);
create policy "car_service insert own" on public.car_service_requests for insert
  with check (auth.uid() = user_id);
create policy "car_service update owner or staff" on public.car_service_requests
  for update
  using (auth.uid() = user_id or auth.uid() = driver_id or driver_id is null);
-- One-time backfill: every existing request that already has a centre
-- assigned (from testing against an earlier seed - Komtar, Gurney, PJ etc.)
-- is moved onto TAR UMT Penang Branch, the one true centre, so nothing in
-- the app is still showing a stale location. Safe to re-run.
update public.car_service_requests
  set service_centre_id = 'sc_tarumt'
  where service_centre_id is not null;

-- ---- service_tasks (the tick-off-by-part checklist) ------------------
-- One line item per row. Pre-seeded from the service type (is_extra = false,
-- approval = 'included'). Anything the staff adds after inspecting the car is
-- is_extra = true, approval = 'pending' until the owner approves / declines it.
-- final_cost = sum(price) where approval in ('included','approved').
create table if not exists public.service_tasks (
  id uuid primary key default gen_random_uuid(),
  service_request_id uuid not null references public.car_service_requests (id) on delete cascade,
  title text not null,
  detail text,
  price numeric not null default 0,
  is_done boolean not null default false,
  done_at timestamptz,
  is_extra boolean not null default false,
  approval text not null default 'included',   -- included | pending | approved | declined
  created_at timestamptz not null default now()
);
alter table public.service_tasks enable row level security;
drop policy if exists "service_tasks owner or staff" on public.service_tasks;
create policy "service_tasks owner or staff" on public.service_tasks for all
  using (exists (select 1 from public.car_service_requests r
    where r.id = service_request_id
      and (r.user_id = auth.uid() or r.driver_id = auth.uid())))
  with check (exists (select 1 from public.car_service_requests r
    where r.id = service_request_id
      and (r.user_id = auth.uid() or r.driver_id = auth.uid())));

-- ---- service_photos (pick-up / return / work documentation) ----------
create table if not exists public.service_photos (
  id uuid primary key default gen_random_uuid(),
  service_request_id uuid not null references public.car_service_requests (id) on delete cascade,
  phase text not null,                          -- pickup | return | work
  image_url text not null,
  caption text,
  created_at timestamptz not null default now()
);
alter table public.service_photos enable row level security;
drop policy if exists "service_photos owner or staff" on public.service_photos;
create policy "service_photos owner or staff" on public.service_photos for all
  using (exists (select 1 from public.car_service_requests r
    where r.id = service_request_id
      and (r.user_id = auth.uid() or r.driver_id = auth.uid())))
  with check (exists (select 1 from public.car_service_requests r
    where r.id = service_request_id
      and (r.user_id = auth.uid() or r.driver_id = auth.uid())));

-- ---- storage bucket for service photos ------------------------------
insert into storage.buckets (id, name, public)
  values ('service-photos','service-photos', true) on conflict (id) do nothing;
drop policy if exists "service-photos upload" on storage.objects;
create policy "service-photos upload" on storage.objects for insert to authenticated
  with check (bucket_id = 'service-photos');
drop policy if exists "service-photos read" on storage.objects;
create policy "service-photos read" on storage.objects for select
  using (bucket_id = 'service-photos');

-- ---- activity_messages (chat, Supabase Realtime) -----------------------
create table if not exists public.activity_messages (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid references public.bookings (id) on delete cascade,
  service_request_id uuid references public.car_service_requests (id) on delete cascade,
  sender_id text not null,
  sender_type text not null default 'user',
  type text not null default 'text',   -- 'text' | 'image'
  message text not null default '',
  image_url text,                       -- public URL in the 'chat-images' bucket
  created_at timestamptz not null default now()
);
-- Picture messages: added after the table shipped, so keep these idempotent.
alter table public.activity_messages
  add column if not exists type text not null default 'text';
alter table public.activity_messages
  add column if not exists image_url text;
alter table public.activity_messages alter column message set default '';
alter table public.activity_messages enable row level security;
create policy "messages read any" on public.activity_messages for select
  using (auth.uid() is not null);
create policy "messages insert any" on public.activity_messages for insert
  with check (auth.uid() is not null);

-- ---- activity_reads (unread-message dot) --------------------------------
-- One row per (account, thread): when that account last opened the chat.
-- A thread has unread messages when the newest message from the OTHER side
-- is newer than this - see ChatReadService / UnreadDot.
create table if not exists public.activity_reads (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  booking_id uuid references public.bookings (id) on delete cascade,
  service_request_id uuid references public.car_service_requests (id) on delete cascade,
  last_read_at timestamptz not null default now(),
  unique (user_id, booking_id),
  unique (user_id, service_request_id)
);
alter table public.activity_reads enable row level security;
drop policy if exists "activity_reads own" on public.activity_reads;
create policy "activity_reads own" on public.activity_reads for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---- Storage bucket for chat pictures ---------------------------------------
-- Create a PUBLIC bucket named 'chat-images' (Dashboard > Storage > New bucket,
-- or the statement below), then allow authenticated users to upload / read.
insert into storage.buckets (id, name, public)
  values ('chat-images', 'chat-images', true)
  on conflict (id) do nothing;
drop policy if exists "chat-images upload" on storage.objects;
create policy "chat-images upload" on storage.objects for insert to authenticated
  with check (bucket_id = 'chat-images');
drop policy if exists "chat-images read" on storage.objects;
create policy "chat-images read" on storage.objects for select
  using (bucket_id = 'chat-images');

-- ---- payment_methods (Module 4) ----------------------------------------------
create table if not exists public.payment_methods (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  type text not null,
  label text not null,
  is_default boolean not null default false,
  last4 text,             -- type = 'card' only; full number/CVV never stored
  expiry text,            -- MM/YY, type = 'card' only
  cardholder_name text    -- type = 'card' only
  -- One saved method per type is enforced in AccountProvider.addPaymentMethod,
  -- not with a DB unique constraint - so re-running this script is safe even
  -- if duplicate-type rows already exist from before this change.
);
-- Added after the table shipped, so keep these idempotent.
alter table public.payment_methods add column if not exists last4 text;
alter table public.payment_methods add column if not exists expiry text;
alter table public.payment_methods add column if not exists cardholder_name text;
alter table public.payment_methods enable row level security;
create policy "payment_methods own" on public.payment_methods for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---- receipts (Module 4) -----------------------------------------------
create table if not exists public.receipts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  booking_id uuid references public.bookings (id) on delete set null,
  service_request_id uuid references public.car_service_requests (id) on delete set null,
  amount numeric not null default 0,
  description text not null default '',
  created_at timestamptz not null default now()
);
alter table public.receipts enable row level security;
create policy "receipts own" on public.receipts for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---- weather_alerts (Module 2 - optional seed store) ------------------
create table if not exists public.weather_alerts (
  id uuid primary key default gen_random_uuid(),
  type text not null,
  severity text not null,
  title text not null,
  description text not null,
  area text not null,
  source text not null default 'data.gov.my',
  lat double precision,
  lng double precision,
  created_at timestamptz not null default now()
);
alter table public.weather_alerts enable row level security;
create policy "weather readable" on public.weather_alerts for select using (true);

-- ---- notification_settings (Module 4) --------------------------------
create table if not exists public.notification_settings (
  user_id uuid primary key references auth.users (id) on delete cascade,
  trip_updates boolean not null default true,
  safety_alerts boolean not null default true,
  car_service_updates boolean not null default true,
  chat_messages boolean not null default true,
  promotions boolean not null default false
);
alter table public.notification_settings enable row level security;
create policy "notif_settings own" on public.notification_settings for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---- Realtime: publish the tables the app subscribes to -------------------
do $$
begin
  begin execute 'alter publication supabase_realtime add table public.bookings'; exception when others then null; end;
  begin execute 'alter publication supabase_realtime add table public.car_service_requests'; exception when others then null; end;
  begin execute 'alter publication supabase_realtime add table public.activity_messages'; exception when others then null; end;
  begin execute 'alter publication supabase_realtime add table public.service_tasks'; exception when others then null; end;
  begin execute 'alter publication supabase_realtime add table public.service_photos'; exception when others then null; end;
end $$;

-- ---- auto-create a profile row on sign-up ----------------------------------
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, name, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', 'Guest'),
    coalesce(new.raw_user_meta_data->>'role', 'user')
  )
  on conflict (id) do nothing;

  insert into public.notification_settings (user_id) values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
