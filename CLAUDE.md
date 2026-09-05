# Substitute Driver Application — Flutter Build Brief

This file is project context for Claude Code. Read this fully before writing any code.
Reference files in this repo: `substitute-driver-app-v2.html` (clickable prototype —
use it as the source of truth for screens, copy, and flow) and the presentation slide
PDF (module ownership and SDG 9 framing).

## 1. What this app is

BMIT2073 Mobile Application Development assignment (TAR UMT). A Flutter app that
digitises Malaysia's informal substitute-driver (代驾) industry, in support of
**SDG 9: Industry, Innovation, and Infrastructure**.

Two distinct core services — do not conflate them:
- **Find a Driver**: a substitute driver comes to the user's location and drives the
  **user's own car** to the destination. The user rides along. This is NOT ride-hailing —
  no separate vehicle is hired.
- **Car Service**: the user schedules a pick-up; a company driver collects the user's
  car (without the owner present), takes it for servicing/maintenance, and returns it.
  Payment happens *after* the car is returned, once the final cost is known.

Real-time weather data from **data.gov.my**'s API powers safety alerts (flood, heavy
rain, road closures) shown to both drivers and passengers, before and during trips.

## 2. Tech stack (final — do not substitute without asking)

- **Flutter (Dart)**, minimum SDK per current stable Flutter release
- **State management: Provider**
- **Backend/DB: Supabase**
  - Supabase Auth (email/password) for login/signup
  - Postgres tables via Supabase client for bookings, car service requests, activity,
    payments, profiles, vehicles
  - Supabase Realtime for live trip status and in-app chat
  - Supabase Storage if profile photos / receipts need file storage
- **Maps: OpenStreetMap tiles via `flutter_map` package** (not Google Maps)
- **Routing: OSRM public demo server** (`https://router.project-osrm.org`) for
  turn-by-turn route lines and ETA between two coordinates. This is a free public demo
  server — not for production use, but fine for a student assignment. Handle failures
  gracefully (it can be slow/rate-limited).
- **Weather: data.gov.my Weather API** — fetch via `http` package, cache responses,
  handle loading/error states.
- **Geocoding**: use OSM's Nominatim API for address search (free, but respect usage
  policy — add a short delay/debounce on search input, do not spam requests).

## 3. Environment setup

Create a `.env` file at project root (add to `.gitignore` — never commit this):

```
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key
DATA_GOV_MY_API_KEY=your_data_gov_my_key
```

Use `flutter_dotenv` (or equivalent) to load these at startup. Never hardcode keys in
source files.

## 4. The 4 modules (map to the prototype's screens)

Use these as top-level feature folders under `lib/features/`. Screen names below
match IDs/names in `substitute-driver-app-v2.html` — open that file to see exact
copy, layout, and field names for each screen.

### Module 1 — Substitute Driver Booking
Screens: Home (quick actions + weather banner), Find a Driver (service tier chips,
location/destination fields, map with driver-to-user + trip routes, fare breakdown),
Confirm & Pay, Payment Successful, Searching (driver match, auto-advance + Cancel),
Trip Tracking (live map, ETA, driver card with verified badge, quick commands to
driver, share trip status toggle), Activity Chat (in-trip messaging).

Key logic to implement:
- Fare calculation: flagfall (first 10km) + per-km rate beyond that + wet-weather
  surcharge when an active weather alert overlaps the route
- Real-time driver location (mock this with a simulated moving point for the
  assignment, since there's no real driver fleet — document this assumption)
- OSRM route fetch between pickup and destination coordinates

### Module 2 — Weather & Safety Alerts
Screens: Notification tab (segmented All/Safety alerts/Updates), alert cards
(flood/rain/road closure), Safe route suggestion card, weather banner (shown on
Home AND on Trip Tracking map — this cross-module reuse is intentional, build it
as one shared widget).

Key logic to implement:
- Poll/fetch data.gov.my weather API on an interval or on-demand
- Simple severity classification (e.g. rainfall threshold → alert level)
- Safe-route suggestion: compare OSRM's default route against an alternate route
  that avoids a flagged coordinate/area (can be simplified — document any
  simplification made vs a "real" routing-around-hazards algorithm)

### Module 3 — Vehicle Services
Screens: Car Service booking form (date/time picker, location picker with
GPS/map-pin/manual-entry sub-flows, service type picker, cost estimate), Status
Tracker (5-step: Requested → Assigned → Picked up → At centre → Returned), Review &
Pay (post-service, itemised final cost), Vehicle Details (profile sub-page).

Key logic to implement:
- Status tracker driven by a `status` enum column in Supabase, updated server-side
  or via a simple admin/testing toggle since there's no real company-driver backend
- Estimated vs final cost distinction (estimate shown at booking, final shown after
  "Returned" status)

### Module 4 — User Account Management
Screens: Profile home, Payment Methods, Activity & Receipts (spend summary + export),
My Vehicle Details, Notification Settings, Language, Safety Alert Preferences,
Help & Support.

Key logic to implement:
- Supabase Auth session → profile row
- Activity & Receipts: query past bookings/car-service records, sum monthly spend,
  and implement a real CSV or PDF export (not just a placeholder button — this was a
  specifically requested feature)
- Settings toggles persisted to Supabase (or local storage if you decide these are
  device-level, not account-level — pick one and be consistent)

## 5. Suggested Supabase schema (adjust as needed, but keep it normalized)

```sql
profiles (id uuid pk references auth.users, name, role, phone, avatar_url, rating, created_at)
vehicles (id uuid pk, user_id fk, plate_number, model, colour, transmission)  -- the passenger's own car
-- A substitute driver drives the passenger's car and owns no vehicle: driver
-- accounts are just profiles rows with role='driver' (name / rating / verified),
-- no plate or vehicle info anywhere.
bookings (id uuid pk, user_id fk, driver_id fk, pickup_lat, pickup_lng, pickup_address,
          dest_lat, dest_lng, dest_address, service_tier, fare_estimate, fare_final,
          payment_method, payment_status, status, created_at)
car_service_requests (id uuid pk, user_id fk, vehicle_id fk, driver_id fk,
          pickup_datetime, pickup_address, service_type, cost_estimate_min,
          cost_estimate_max, final_cost, status, payment_status, notes, created_at)
activity_messages (id uuid pk, booking_id fk nullable, service_request_id fk nullable,
          sender_id, sender_type, message, created_at)
payment_methods (id uuid pk, user_id fk, type, label, is_default)
receipts (id uuid pk, user_id fk, booking_id fk nullable, service_request_id fk nullable,
          amount, description, created_at)
weather_alerts (id uuid pk, type, severity, title, description, area, source, created_at)
notification_settings (user_id fk pk, trip_updates bool, safety_alerts bool,
          car_service_updates bool, chat_messages bool, promotions bool)
```

Enable Row Level Security on every table. Users should only read/write their own
rows (`auth.uid() = user_id`); driver/admin-facing writes can be relaxed for the
assignment but note this as a simplification if asked in the viva.

## 6. Suggested folder structure

```
lib/
  core/
    theme/          # colors, text styles — port from the HTML prototype's CSS variables
    services/        # supabase_service.dart, weather_service.dart, routing_service.dart
    widgets/          # shared widgets (weather_banner.dart used in 2 places, map_view.dart)
  features/
    booking/          # Module 1
    weather_safety/    # Module 2
    vehicle_services/  # Module 3
    account/           # Module 4
  models/
  main.dart
```

## 7. Design reference

Port the color palette and typography from the prototype's CSS (`:root` variables in
`substitute-driver-app-v2.html`) — deep navy `#0B1730`, blue `#2563EB`, light blue
tints, Sora for headings / Inter for body text. Keep the rounded-card, floating
bottom-nav visual style.

## 8. Build order (recommended)

1. Project scaffold + Supabase connection + `.env` loading + auth (login/signup)
2. Bottom nav shell (Home / Activity / Notification / Profile) with routing
3. Module 1: Home screen → Find a Driver → Confirm & Pay → Trip Tracking (get one
   full flow working end-to-end before moving on)
4. Module 3: Car Service booking → Status Tracker → Review & Pay
5. Module 2: weather fetch + alert display + wire into Home banner and Trip Tracking
6. Module 4: Profile + all sub-pages + receipts export
7. Polish: verified badges, quick commands, share trip toggle, error/loading states
   throughout

## 9. Reminders for assignment compliance

- Comment code normally during development — **all comments must be stripped before
  final submission** per the assignment's marking policy. Don't strip them yet.
- I need to understand and be able to explain every piece of generated code in the
  viva — so after generating a feature, give me a short plain-English explanation of
  the key logic (especially the fare calculation algorithm, the OSRM routing calls,
  and any state management patterns used).
- Flag anything I should double-check or might struggle to explain live.
