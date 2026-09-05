# Build Progress — Ganti (Substitute Driver App)

Read this alongside `CLAUDE.md` (project brief) and `mobile prototype .html`
(design source of truth).

Last updated: 2026-09-04.

---

## Continuing on another PC — read this first

The whole project folder lives in OneDrive (`OneDrive/Desktop/mobile`). Moving it
by **zip** to another PC is fine — it is **not a git repo**, everything needed is
inside the folder (the Supabase keys are constants in `lib/supabase_config.dart`,
there is no `.env`). What matters when you open it on a new PC:

### 0. Before you zip (optional — smaller archive, avoids stale-cache issues)

Delete these generated folders/files first; Flutter rebuilds them all on the new
PC with `flutter pub get` / `flutter run`:

```
build/                     .dart_tool/
.flutter-plugins-dependencies
android/.gradle/            android/app/build/
android/local.properties   (hardcoded old-PC paths — see §2)
.idea/   *.iml              (IDE files, safe to drop)
ios/     web/               (only if you will never build for those targets)
```

Everything under `lib/`, `test/`, `assets/`, `android/app/src/`, plus
`pubspec.yaml`, `pubspec.lock`, `supabase_schema.sql`, `analysis_options.yaml`,
`CLAUDE.md`, `PROGRESS.md` and the prototype/PDF reference files **must stay**.

If you zip the whole folder as-is, that also works — just do §2 + §3 after
unzipping.

### 1. Toolchain

- **Flutter 3.44.2 stable** (Dart 3.12.2). `pubspec.yaml` needs `sdk: ^3.12.2`.
  Any Flutter ≥ 3.44 stable is fine; if `flutter pub get` complains about the
  SDK constraint, run `flutter upgrade`.
- Android SDK + a device/emulator, **or** Chrome (`flutter run -d chrome`, the
  `web/` target exists) if you have no emulator.

### 2. Machine-specific files that will NOT be right after sync

- **`android/local.properties`** — contains hardcoded paths from the old PC
  (`flutter.sdk=C:\flutter`, `sdk.dir=C:\Users\user\AppData\Local\Android\sdk`).
  Delete it and let Flutter regenerate it, or edit the two paths to match the
  new machine. `flutter run` regenerates `sdk.dir` automatically.
- **`.dart_tool/`, `build/`, `.flutter-plugins-dependencies`, `.idea/`,
  `*.iml`** — generated. If the build acts strange after sync, delete
  `.dart_tool/` and `build/` and run `flutter clean && flutter pub get`.
- **`android/.gradle/`, `android/app/build/`** — generated; safe to delete.

### 3. First run on the new PC

```
cd <project>
flutter clean
flutter pub get
flutter run           # or: flutter run -d chrome
```

### 4. Secrets / backend — nothing to set up

There is **no `.env`** (this build follows Practical 11: keys are constants in
`lib/supabase_config.dart`, which is part of the folder and syncs). The Supabase
project is already live:

- URL: `https://jytfarbtchbqvaoaxufg.supabase.co`
- publishable key: in `lib/supabase_config.dart` (anon/publishable key — public
  by design, RLS protects the data)
- **Re-run `supabase_schema.sql`** (SQL Editor, paste the whole file — it is
  idempotent: `create table if not exists`, `add column if not exists`,
  `drop policy` / `create policy`). The **Module 3 overhaul tables**
  (`service_centres`, `service_tasks`, `service_photos`, the `service-photos`
  storage bucket, and the new `car_service_requests` columns) were added on
  2026-09-04 and it is **not confirmed they have been applied to the live
  project** — running the file again is safe and closes that gap.
- **data.gov.my weather** needs no key (public endpoint).
- Reminder: in Supabase → Authentication → Email, keep **"Confirm email" OFF**
  or sign-ups hit the free-tier email rate limit.

### 5. Verified green on 2026-09-04 (this machine)

- `flutter analyze` → **No issues found**
- `flutter test` → **all pass** (5 tests: fare calculator ×4, login smoke ×1)
- `flutter build apk --debug` → succeeds
- App package id: `com.ganti.ganti`

### 6. Test accounts (on the live Supabase project)

`pax@ganti.test` / `driver@ganti.test` / `staff@ganti.test`, all password
`password123`. Or sign up fresh — signup screen lets you pick the role
(passenger / substitute driver / car service partner).

### 7. State of the build

**Feature-complete against the brief.** All 4 modules built, 3 roles with
role-based routing. No known outstanding bugs. Remaining work is polish / viva
prep, not features:

> **Service-staff (Module 3) caveat — verify on the new PC.** The code is
> fully built and analyze-clean (feed, accept-with-service-centre, phase-aware
> map + Navigate, odometer in/out, pick-up/return photos to Supabase Storage,
> seeded task checklist, add-extra-work + owner approval gate, `advanceStatus`
> guards, `final_cost` = sum of billable tasks, call/chat the owner). But the
> **2026-09-04 Module 3 overhaul has not been re-tested end-to-end on a
> device** — the last live end-to-end run (2026-08-29) exercised the older,
> thinner staff flow. First job on the new PC: run `supabase_schema.sql`, then
> do one full pass — passenger books a Car Service → `staff@ganti.test`
> accepts (pick a centre) → odometer + photo at pick-up → advance → tick
> tasks / add an extra → passenger approves it → return odometer + photo →
> Returned → passenger Review & pay. Watch for: Storage upload perms on the
> `service-photos` bucket, the realtime task/photo streams, and the
> `advanceBlockedReason` gates.


- **Strip all code comments before final submission** (brief's marking policy —
  see the "Comments" section at the bottom). Do this on a copy, last.
- Re-read the "Documented simplifications" list below and be ready to defend each
  in the viva (fare algo, OSRM calls, driver simulation, RLS relaxation,
  runtime machine-translation, weather keyword-severity).
- Optional: bundle a real `flutter build apk --release` for the demo phone.

---

## Where we are

**All 4 modules are built**, plus **three account roles with role-based
routing**. `flutter analyze` is clean (0 issues), `flutter test` passes, and
`flutter build apk --debug` succeeds.

### Roles (profiles.role)

| Role | Chosen at | Shell | Screens |
|---|---|---|---|
| `user` | default on sign-up | `AppShell` (Home, Activity, Notification, Profile) | the whole passenger app (Modules 1–4) |
| `driver` | "Work as a substitute driver" on sign-up (name + email only) | `DriverShell` — **4 tabs like the passenger app** (Home, Activity, Notification, Profile), minus anything vehicle-related: **a substitute driver drives the passenger's car and owns no vehicle**, so there is **no Car Service tile** and **no "My vehicle details"** for this role. Home's "Find a Driver" quick action becomes **"Available trips"** → `DriverJobsScreen` (the accept queue): accept an unassigned request, drive it through the status steps; a location timer writes `driver_lat/lng` so the passenger sees the car move; chat with the passenger. |
| `service_staff` | "Work as a car service partner" on sign-up | `ServiceShell` (Requests + the shared full-featured Profile) | see unassigned car-service requests, accept, advance the 5 status steps, enter the itemised final cost |

All three roles share one **role-aware `ProfileScreen`** (`features/account/screens/profile_screen.dart`): the account-management menu (payment methods, receipts, notification settings, language, safety alerts, help); the hero subtitle switches on `profile.role`; **"My vehicle details" shows only for `user`** (a substitute driver has no vehicle). Sign-out clears every role's provider. The old `driver_profile_screen.dart` / `service_profile_screen.dart` were deleted. `HomeScreen` takes `HomeAction primaryAction` + `showCarService` (`models/home_action.dart`) to tailor the tiles per role.

`AuthGate` (main.dart) loads the profile after sign-in and routes to the shell
for the role. A booking is created **unassigned**; `SearchingScreen` watches
the live row and, if no real driver accepts within 25 s, runs the local
simulation so a solo demo still works (`BookingProvider.runSimulationFallback`).
Backing out of `SearchingScreen` (Android back) disposes it and cancels that
timer, so a booking can be left `searching` for a real driver to accept.

The code was then rewritten to match the BMIT2073 practical coding style:
- models use `factory X.fromJson(Map<String, dynamic> json)` + `toMap()`
- services are singletons (`factory X() => _instance;`), like Practical 9
- state classes are `class XxxProvider extends ChangeNotifier` in
  `features/*/providers/xxx_provider.dart`, like Practical 5's `CartProvider`
- `print('... $e')` for error logging (`avoid_print` disabled in
  `analysis_options.yaml`, matching the practicals)
- no records, no `switch` expressions, no exotic syntax
- enhanced enums replaced with plain enums (state) or small model classes with
  `static const` instances (`ServiceTier`, `CarServiceType`)
- the `lib/core` + `lib/features` folder tree is kept because the brief
  mandates it (the practicals are single-folder)

## Module 3 (Vehicle Services) overhaul — 2026-09-04

Turned the thin service-staff flow into a real one. **New SQL to run**
(`supabase_schema.sql` has it all): `service_centres` (seeded, 2 Penang + 2 KL),
`service_tasks`, `service_photos`, a `service-photos` storage bucket, and
`car_service_requests` gains `service_centre_id`, `staff_lat/lng`,
`assigned_at/picked_up_at/at_centre_at/returned_at`, `odometer_in/out`,
`ready_by`.

- **Phase-aware map on both sides** (same pattern as the substitute-driver
  map): `assigned` staff→house · `pickedUp` house→centre · `atCentre` parked ·
  `returned` centre→house. Staff position walked by `ServiceStaffProvider` and
  written to `staff_lat/lng`; the owner's tracker follows it. "Navigate"
  button opens Waze/Maps via `url_launcher` (new dep).
- **Tick-off-by-part checklist** (`service_tasks`): pre-seeded per service type
  (`features/vehicle_services/services/default_service_tasks.dart`). Staff ticks
  each done; `final_cost` is kept = sum of billable task prices.
- **Extra-work approval gate**: a staff-added task is `approval = 'pending'`;
  the owner's tracker shows an Approve/Decline card; staff can't reach
  `returned` while anything is pending or un-ticked.
- **Photos** (`service_photos` + `service-photos` bucket): staff adds pick-up
  and return photos (camera or Files); owner sees the gallery. Plus odometer
  in/out and a `ready_by` estimate — guards on `advanceStatus`.
- **Contact**: staff detail + owner tracker both have Call (`tel:`) and Message
  (existing `ActivityChatScreen`, `serviceRequestId`). Owner tracker now shows
  the **real assigned staff** (was hard-coded "Halim K.").
- **Service centre chosen on accept** (bottom sheet in `ServiceRequestsScreen`).
- Booking form now **requires a contact number** (saved to `profiles.phone`)
  and **geocodes the pick-up** so it always has coordinates.
- Solo-demo `advanceStatus` toggle stays but only shows while `driver_id` is
  null; it auto-ticks tasks + auto-approves extras on `returned`.

## IMPORTANT: turn off email confirmation for testing

Supabase → **Authentication → Sign In / Providers → Email** → turn **"Confirm
email" OFF**. Otherwise every sign-up sends a confirmation email, the free-tier
email service hits its hourly rate limit fast, and you get
`email rate limit exceeded`. With it off, sign-up logs you straight in.

## End-to-end testing (2026-08-29, Pixel 8 Pro emulator, real Supabase)

Tested live with three accounts (`pax@ganti.test`, `driver@ganti.test`,
`staff@ganti.test`, all password `password123`):

- **Passenger booking → driver → completion:** pax books Find a Driver →
  booking row `searching`. Driver logs in, sees it under *Available requests*,
  taps **Accept trip** → row `enRoute`, `driver_id` set. Driver **Picked up
  passenger** → `onTrip`; **Complete trip** → `completed` (snackbar "Trip
  completed. Nice work!"). Pax Home *Last trip* card flips to **COMPLETED** via
  Realtime. ✅
- **Car Service → service partner → pay:** pax adds a vehicle (Profile → My
  vehicle details — required before booking), submits a Car Service request →
  row `requested`. Staff logs in, **Accept request** → `assigned`, then
  **Advance** ×3 → `pickedUp` / `atCentre` / `returned`. Staff enters itemised
  cost (labour/parts/inspection/transport) → **Send final cost to owner**. Pax
  Status Tracker shows all 5 steps done + **Final service cost**; **Review &
  pay** shows the real line items and total; paying writes a receipt. ✅
- **RLS:** a `driver` / `service_staff` account can now read other users'
  unassigned rows (policies use `auth.uid() is not null`, not `auth.role()`).

### Fixed during testing

- **Itemised final cost was faked.** `car_service_requests` only stored a single
  `final_cost`, so Review & Pay reverse-engineered a labour/parts split from the
  total (showed odd figures like RM 126.50). Added `final_labour`,
  `final_parts`, `final_inspection`, `final_transport` columns;
  `ServiceStaffProvider.setFinalCost` now writes all four; Review & Pay shows the
  partner's actual numbers. The generated split remains only as a fallback for
  the demo status toggle / legacy rows. **Re-run `supabase_schema.sql`** for the
  new columns.
- Searching-screen driver-wait bumped 8 s → 25 s so a real driver has time to
  accept before the solo simulation kicks in.

## Fixes (2026-09-01)

- **Driver saw a passenger's own car after accepting?** He didn't - added it.
  `DriverProvider._loadJobVehicle()` fetches the passenger's `vehicles` row on
  accept / on restore; `DriverJobDetailScreen` shows a **"The car you will be
  driving"** card (model · colour, plate, transmission), or a "confirm at
  pick-up" note if the passenger never added a car. **Re-run
  `supabase_schema.sql`** - the `vehicles` RLS is now `read any` for select
  (write still owner-only) so the assigned driver can see the row.
- **Cancelled trip request stayed in the driver's "Available requests", and
  re-requesting from the same place duplicated it.** Two causes, both fixed:
  1. `DriverProvider.watchAvailableJobs()` filtered the realtime stream with
     `.eq('status','searching')`. A realtime stream never delivers the update
     that moves a row *out* of its filter, so a cancelled/accepted booking
     lingered. Now it streams recent bookings unfiltered and filters status +
     `driver_id` in Dart.
  2. `BookingProvider.confirmAndPay()` now cancels any of the user's own
     still-`searching` bookings before inserting the new one, and
     `cancelActiveBooking()` is `await`ed from the Cancel button + does a
     `.select()` to detect an RLS no-op.

## Weather page + Profile wiring (2026-08-29)

- **Weather forecast is now its own page** (`weather_forecast_screen.dart`),
  opened from a renamed Home quick-action tile ("Weather Forecast · 7-day
  outlook by state"). The Notification tab keeps the safety-alert feed + safe
  route only. `WeatherProvider.ensureForecastLoaded()` restores the saved state
  and loads it once (no race between the shell refresh and the page).
- **New `PreferencesProvider`** (device-level, SharedPreferences): owns the
  language choice and the safety-alert toggles, so the Profile menu label, the
  Notification feed and the safe-route card all react immediately. Replaces the
  scattered `SharedPreferences` reads in `language_screen` / `safety_preferences`.
- **Every Profile function now does something real:**
  - *Edit profile* — tap the profile hero → sheet to edit name + phone,
    written to `profiles` (`AccountProvider.updateProfile`). Fixes accounts
    showing "Guest".
  - *Payment methods* — add a card now prompts for the last 4 digits; methods
    can be removed (swipe-left + confirm, `removePaymentMethod`, promotes the
    next default).
  - *Activity & receipts* — export shows "No receipts to export yet." instead
    of doing nothing when empty.
  - *Language* — choice is shown on the Profile menu ("Language — …") straight
    away. Full UI translation stays out of scope (caption says so).
  - *Notification settings* — the `Safety alerts` master toggle now hides the
    safety feed (with a "muted" note); `Trip updates` / `Car service updates`
    surface the latest trip / service status as feed items in the Updates tab.
  - *Safety alert preferences* — flood / storm / road-closure toggles filter
    the Notification feed by alert type; `Automatic safe rerouting` makes the
    safe-route card apply itself without the button.
  - *Help & support* — "Contact support" opens a sheet with the support email /
    phone, tap-to-copy (Clipboard), instead of a dead "not available" snackbar.

## Flow / logic fixes (2026-08-28)

- Trip Tracking now has a **Finish** button when the trip is completed
  (`BookingProvider.finishActiveTrip` — cancels the realtime sub + timer,
  clears the active trip, refreshes Activity).
- The driver-simulation fallback no longer races a real driver: it bails if a
  `driver` account already accepted.
- The passenger's **Status Tracker** and the partner's **request detail**
  screen now follow the row live (Supabase Realtime), so a status change or a
  final-cost entry shows on the other side immediately.
- Driver Jobs and Service Requests lists refresh live when a new request comes
  in (`watchAvailableJobs` / `watchRequests`).
- `AccountProvider.load()` retries once if the profile row isn't committed yet
  (fixes a driver/staff briefly landing in the passenger shell after sign-up).
- Car Service date picker no longer crashes if the default date has passed.
- Friendlier auth error messages (rate-limit hint, "already registered").

## Supabase connection (Practical 11 style)

Following **Practical 11**, the connection is not read from `.env` any more.
`lib/supabase_config.dart` holds the two constants and the shared client:

```dart
const String supabaseUrl = '...';   // Connect -> Flutter
const String supabaseKey = '...';   // Project Settings -> API Keys
final supabase = Supabase.instance.client;
```

`main()` calls `Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey)`
directly, and every provider uses the top-level `supabase`. `flutter_dotenv`
and the old `SupabaseService` wrapper (URL cleaning, placeholder fallback,
clock-skew retry) have been removed. There is no offline fallback now — a
bad URL/key just throws on the first call.

To run against real data:

1. Paste your real server URL + key into `lib/supabase_config.dart`.
2. In the Supabase dashboard, SQL Editor, run `supabase_schema.sql` once. It
   creates every table from the brief's schema, enables RLS, seeds 3 demo
   drivers, and installs a trigger that auto-creates the `profiles` +
   `notification_settings` rows on sign-up.
3. `flutter pub get && flutter run`.

A `web/` target was added so the app can be run with `flutter run -d chrome`
on a machine without an Android emulator.

**Viva note / brief conflict:** CLAUDE.md section 3 says never hardcode keys
(use `.env`). Practical 11 hardcodes them. This build follows Practical 11 by
choice. `supabase_config.dart` IS committed, so the anon key lands in git
history — acceptable because the anon key is public by design (RLS is what
protects the data), but be ready to explain that trade-off.

## What exists (by module)

```
lib/
  supabase_config.dart           # Practical 11: const url/key + shared `supabase` client
  core/
    services/
      weather_service.dart       # Practical 10: data.gov.my /weather/forecast + /weather/warning; alertsFromForecast() + alertsFromWarnings() -> WeatherAlert (flood/road-closure/rain); 60s cache; offline seed only when both endpoints fail
      routing_service.dart       # OSRM public demo server: route() + safeRoute(); straight-line fallback on failure
      geocoding_service.dart     # OSM Nominatim search() + reverse(); in-memory cache; MY-biased
      translation_service.dart   # key-less Google translate endpoint; English fallback; batched
    theme/app_theme.dart         # colours/fonts ported from the prototype CSS + AppStyles helpers
    widgets/
      app_shell.dart             # 4-tab shell; loads account/weather/activity on mount
      bottom_nav_bar.dart
      screen_header.dart         # navy top-header used across sub-screens
      primary_button.dart        # PrimaryButton + GhostButton
      map_view.dart              # flutter_map (OSM tiles) wrapper: route + driver polylines, pin/dot markers
      weather_banner.dart        # SHARED Module 2 widget: Home hero AND Trip Tracking
      location_search_screen.dart# reusable debounced Nominatim address search
      tr.dart                    # Tr() text widget + context.tr() — runtime UI translation
  models/                        # profile, vehicle, driver, booking, car_service_request,
                                 # activity_message, payment_method, receipt, weather_alert,
                                 # forecast + weather_warning (Practical 10 / data.gov.my),
                                 # notification_settings, route_result,
                                 # place, home_action (Home quick-action tile, role-swappable)
  features/
    auth/                        # email/password + AuthProvider; sign-up picks a role
    driver/                      # DRIVER ROLE
      providers/driver_provider.dart   # available jobs, accept, status, location timer
      screens/  driver_shell (4 tabs, reuses Home/Activity/Notification/Profile),
                driver_jobs (accept queue, pushed from the Home tile),
                driver_job_detail
    service_staff/               # SERVICE_STAFF ROLE
      providers/service_staff_provider.dart  # open requests, accept, advance, setFinalCost
      screens/  service_shell (Requests + shared Profile),
                service_requests, service_request_detail
    booking/                     # MODULE 1
      providers/booking_provider.dart  # draft, OSRM route, fare, confirmAndPay, driver simulation, activity load
      services/fare_calculator.dart    # flagfall + per-km + wet-weather buffer + hourly tier
      screens/  home, find_driver, confirm_pay, payment_success, searching,
                trip_tracking, activity, activity_chat
    weather_safety/              # MODULE 2
      providers/weather_provider.dart      # alerts + 7-day forecast, SharedPreferences state memory
      screens/notification_screen.dart     # safety-alert feed (settings-aware) + safe route
      screens/weather_forecast_screen.dart # Practical 10 state dropdown + 7-day forecast
      widgets/alert_card.dart, safe_route_card.dart, forecast_list.dart
    vehicle_services/            # MODULE 3
      providers/car_service_provider.dart  # form draft, submit, advanceStatus (demo toggle), itemised final cost, payForService
      screens/  car_service_form (date/time via native pickers), select_location,
                pick_map, select_service_type, status_tracker, review_pay
    account/                     # MODULE 4
      providers/account_provider.dart      # profile (+edit), vehicle, payment methods (+delete), receipts, notification settings
      providers/preferences_provider.dart  # device prefs: language + safety toggles (SharedPreferences)
      services/receipt_exporter.dart   # real CSV (hand-built) + PDF (pdf + printing) export/share
      screens/  profile, payment_methods, receipts, vehicle_details,
                notification_settings, language, safety_preferences, help_support
test/
  fare_calculator_test.dart      # unit tests for the fare algorithm
  widget_test.dart               # skipped smoke test
```

## Key logic (for the viva)

- **Fare calc** (`fare_calculator.dart`): flagfall covers the first 10 km; every
  km past that is `perKm × extraKm` for the selected tier; a flat RM2
  "wet-weather routing buffer" is added when any flagged hazard coordinate is
  within ~1.5 km of the OSRM route polyline. The `hourly` tier is billed per
  half-hour of estimated travel time with no distance term.
- **Weather API** (`weather_service.dart` + `models/forecast.dart`): done the
  **Practical 10** way. `fetchForecast(locationId)` calls
  `api.data.gov.my/weather/forecast?contains=<St code>@location__location_id&sort=date`,
  checks for HTTP 200, `jsonDecode`s the body as a `List` and maps each element
  through `Forecast.fromJson` (a `switch` map-pattern that throws
  `FormatException` on a bad shape). The 16 Malaysian states use `St0xx`
  location ids; the Notification screen has the Practical 10 state
  `DropdownButton` + a 7-day `ForecastList`, and the chosen state is remembered
  with `SharedPreferences`.
- **Safety alerts** (`weather_service.dart` + `models/weather_warning.dart`):
  `fetchAlerts()` merges **two** live data.gov.my feeds:
  - `weather/warning` — MET Malaysia's warning bulletins. `alertsFromWarnings()`
    keeps the land-relevant ones and keyword-classifies each into a
    **flood** (`flood` / `banjir` / `continuous rain` / `hujan berterusan`),
    **road-closure** (`landslide` / `tanah runtuh` / `road closed`) or
    **rain / severe-weather** alert; severity is `severe` on
    `first category` / `danger` / `flash flood`, else `moderate`; the state
    named in the text gives the `area` + a hazard coordinate for the
    safe-route logic.
  - `weather/forecast` — `alertsFromForecast()` still turns "rain / thunderstorm
    ahead" phrases into alerts.

  Results are de-duped, sorted most-severe-first, and cached 60 s. The seeded
  pair is used **only when both endpoints are unreachable** (offline).
  data.gov.my has **no** flood-gauge or road-closure API — a flood alert is a
  continuous-/heavy-rain warning (which is how MET issues flood warnings in
  Malaysia); road-closure alerts only appear if a bulletin text mentions
  landslides/roads. `test/weather_warning_probe.dart` (skipped by default)
  prints the live alerts.
- **OSRM routing** (`routing_service.dart`): GET
  `router.project-osrm.org/route/v1/driving/{lng,lat};{lng,lat}?overview=full&geometries=geojson`,
  parse `routes[0].geometry.coordinates` ([lng,lat] → LatLng), `distance` (m→km)
  and `duration` (s). On any failure → straight line + 30 km/h estimate.
- **Safe route** (`routing_service.safeRoute`): request `alternatives=true`,
  score each alternative by its minimum distance to the hazard points, pick the
  one with the largest clearance (falls back to the default if none is safer).
- **State management**: one root `MultiProvider` (main.dart) with 5
  `ChangeNotifier`s. Screens `context.watch<T>()` to rebuild and
  `context.read<T>()` to call methods.
- **Realtime chat** (`activity_chat_screen.dart`):
  `supabase.from('activity_messages').stream(primaryKey:['id']).eq(threadCol, id).order('created_at')`
  drives a `StreamBuilder`.

## Documented simplifications (flag these in the viva)

- **Driver simulation fallback.** If no real `driver` account accepts a booking
  within 8 s, `BookingProvider.runSimulationFallback` drives the trip locally
  (a `Timer` walking a marker along the OSRM polyline) so a solo demo works.
  When a real driver accepts, the passenger follows the live row instead.
- **Driver location** for the real flow is a timer on the driver's device
  walking the route and writing `driver_lat/lng` (stands in for real GPS).
- **Two-device / two-account demo.** The driver and service-staff flows are
  real, so showing them end-to-end needs a second account signed in (a second
  browser tab or device). Chat is genuinely two-sided (no canned auto-reply).
- **Driver's Activity / "Last trip" tabs** show that account's own history *as a
  customer* (bookings + car-service requests it made), not the trips it drove.
  The driver's accepted jobs live in `DriverProvider` and are reached through
  the "Available trips" screen. Giving a driver the full passenger shell means
  a driver can also book a substitute driver or a car service for their own car.
- **The user-side "Advance status (demo)"** button on the passenger Status
  Tracker still exists as a solo shortcut (hidden once a `service_staff` account
  has taken the job); the real advancing is done by a `service_staff` account.
  Its generated final cost is a plausible split, not a real quote.
- **Safe-route algorithm** picks the best OSRM *alternative* by hazard
  clearance rather than routing around a hazard polygon.
- **Weather severity** is keyword-based (EN + BM) because the forecast endpoint
  returns text, not rainfall amounts. The `data.gov.my` forecast endpoint is
  public (no key); `DATA_GOV_MY_API_KEY` in `.env` is optional and currently a
  placeholder.
- **Flood / road-closure alerts** are parsed from MET Malaysia's
  `weather/warning` bulletins on data.gov.my (see "Safety alerts" above), not
  hardcoded. data.gov.my has no flood-gauge or road-closure feed, so: a flood
  alert = a continuous-/heavy-rain warning (how MET issues flood warnings in
  Malaysia); a road-closure alert only appears when a bulletin text mentions
  landslides or road closures. On a calm day the feed may therefore show only
  thunderstorm / strong-wind warnings. The seeded "Flooded road — Jalan Burma"
  alert now shows **only offline**; when it does, it also gives the safe-route
  logic a hazard coordinate near the demo trip.
- **Settings split:** notification settings are account-level (Supabase via
  `AccountProvider`); language + safety-alert preferences are device-level
  (`shared_preferences` via `PreferencesProvider`). Both now filter the
  Notification feed / safe-route behaviour, not just persist.
- **Localisation:** every UI string is authored in English and machine-
  translated at runtime. `Profile → Language` (English / Bahasa Malaysia /
  中文 / Tamil) switches `PreferencesProvider.language`; the `Tr` widget
  (`core/widgets/tr.dart`, a drop-in for `Text`) and the `context.tr()`
  extension (for `labelText` / validators / hints) look the string up via
  `PreferencesProvider.t()`, which returns the cached translation, or English
  while `TranslationService` (`core/services/translation_service.dart`, the
  key-less Google translate endpoint, same `http` pattern as Practical 10)
  fetches it in batches. Translations are cached in SharedPreferences per
  language (`tr_<code>`), so a language is downloaded once and then works
  offline. `Tr` is applied across every screen — auth, Home, the booking
  flow, car service, weather forecast, notifications, activity, the driver
  and service-staff screens — plus the shared `ScreenHeader`,
  `PrimaryButton`/`GhostButton`, `WeatherBanner` and bottom-nav widgets. Not
  translated: transient `SnackBar` text, and genuine data (addresses, plate
  numbers, names). Verified on a Pixel emulator — switching to 中文 is instant
  after the pre-warm and survives a cold `am force-stop` restart. (The Home
  quick-action grid `mainAxisExtent` was bumped 104 → 118 so longer
  translated tile subtitles don't clip.)

  **Instant switching + persistence.** `PreferencesProvider` also persists the
  set of every English string the app has rendered (`tr_seen`). Three things
  make the switch feel instant: (1) `main()` `await`s `PreferencesProvider.load()`
  before `runApp`, so the app opens straight in the saved language with the
  on-disk translation cache already loaded — no English flash on restart;
  (2) ~3 s after launch, and again whenever the Language screen opens, the
  provider pre-warms *every* language in the background (translates the whole
  `tr_seen` set); (3) `setLanguage()` writes the choice immediately, shows a
  spinner on that row, fetches only what is still missing (capped at 6 s), and
  flips `language` **atomically** once done — so there is never a
  half-translated frame. After the pre-warm has run, tapping a language is a
  pure cache hit and switches with no delay.

  **Hand overrides.** `lib/core/i18n/translation_overrides.dart` is a small
  `code -> {english: correct}` table for terms the machine translator gets
  wrong in context (it returned "Save" as 节省 / "economise", "Profile" as
  轮廓 / "silhouette", "Home" as 家 / "house"). `t()` checks this table
  *before* the download cache, so an override always wins and needs no
  network call; `_ensureCached` skips those strings too.

  Flag in the viva: (a) it depends on an unofficial public endpoint — English
  is the graceful fallback if it is blocked/offline (a failed batch aborts
  early so the spinner never hangs); (b) machine translation of short UI
  labels can read awkwardly (the Language screen says so; the worst offenders
  are hand-corrected in the overrides table); (c) a brand-new install with no
  network that switches language before the pre-warm finishes will fall back
  to English until it can reach the endpoint.
- **Push notifications:** the `Chat messages` / `Promotions` notification
  toggles persist but have no effect in this build (no mobile push service);
  `Trip updates` / `Car service updates` instead surface in the in-app
  Notification feed.
- **RLS** on `bookings` / `car_service_requests` / `activity_messages` is
  relaxed to "any signed-in account can read" (a driver must see unassigned
  jobs); writes are limited to the owner or the assigned driver. Noted as a
  simplification per the brief.

## Comments

The code is commented for development. **Strip all comments before final
submission** (the brief's marking policy).
