# Tiffin Tracker

A Flutter + Supabase application for office colleagues to log daily tiffin orders (`Full`, `Half`, `Skip`), view real-time team choices, and track INR monthly budgets with immutable daily price snapshotting.

## Features (Phase 1 MVP)

- **Email & Password Authentication:** Supabase Auth sign-in/sign-up with automatic `public.users` row creation.
- **Space Gateway & 2-Day Cooldown:** Create an office Space as Leader (generates a 6-digit invite code) or join via code. Leaving a Space triggers a server-enforced 2-day (48-hour) cooling period before joining another Space.
- **Home Dashboard:** One-tap `Full` / `Half` / `Skip` daily logging, countdown to the Space's daily order cut-off (logging remains allowed after cut-off with a warning banner), and real-time horizontal **Squad View**.
- **History (Read-Only):** Calendar and list views displaying past logs with snapshotted INR costs.
- **Money & Week-Wise Budget:** Month-to-date INR spend, week-wise breakdown (`Week 1`–`Week 5`), weekday (`Mon–Fri`) monthly budget projection, and a **Leader Billing Breakdown** showing monthly per-member totals and vendor grand total.
- **Settings:** Profile editing, copyable invite code, Leader admin controls (prices, cut-off time, leadership transfer), leave space, and sign out.

## Supabase Setup

1. Create a new Supabase project.
2. Open the **SQL Editor** in your Supabase dashboard and run [`supabase/migrations/001_initial_schema.sql`](supabase/migrations/001_initial_schema.sql).
3. Copy your **Project URL** and **Publishable / Anon Key** from **Project Settings -> API**.
4. Create a `.env` file in the project root (already gitignored):

```env
SUPABASE_URL=https://YOUR_PROJECT.supabase.co
SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

## Running the App

```bash
flutter pub get
flutter run
```

## Running Verification

```bash
flutter analyze
```
