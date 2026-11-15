# Project Context: Tiffin Tracker App

## 1. Project Overview
A Flutter application designed for office colleagues to track their daily tiffin (lunch) consumption, manage group orders, and calculate monthly expenses. The app replaces manual tracking and avoids end-of-month billing disputes with the tiffin vendor. 

**Target Audience:** Office workers sharing a daily tiffin service.
**Core Mechanics:** Users join an office "Space". One person is the "Leader" who sets fixed prices. Users log their daily tiffin (Full, Half, or Skip). The app calculates monthly totals based on the price on the exact day they logged it (Price Snapshotting).

## 2. Tech Stack
*   **Frontend:** Flutter
*   **Backend & Database:** Supabase (PostgreSQL)
*   **Authentication:** Supabase Auth (Email/Password & Google Sign-In)
*   **State Management:** Standard Flutter `StatefulWidget` / `setState` (or `flutter_hooks` `useState`) for Phase 1 MVP.

## 3. Core User Flow
1.  **Auth:** User registers/logs in using Supabase Auth.
2.  **Space Gateway:** 
    *   *Create Space:* User creates a space, sets Full/Half tiffin prices, becomes the Leader, and gets a 6-digit Invite Code.
    *   *Join Space:* User enters an existing 6-digit Invite Code to join as a Member.
3.  **Home Dashboard:** User sees today's status, taps a button to log their tiffin (Full/Half/Skip), and sees a real-time list of what colleagues in their Space are eating today.
4.  **Month-End:** User checks the "Money" tab to see exactly how much they owe the vendor/leader for the month.

## 4. App Screens (MVP Navigation)
*   **Auth Screen:** Login and Sign-up UI.
*   **Space Gateway Screen:** "Create Space" or "Join Space" options.
*   **Main App (Bottom Navigation Bar):**
    *   **🏠 Home (Dashboard):** 
        *   Action buttons to log today's tiffin (Full/Half/Skip).
        *   Countdown to daily order cut-off.
        *   Horizontal list of colleagues (Squad View) showing their today's status.
    *   **📅 History:** A calendar or list view showing past logs to verify no days were missed.
    *   **💰 Money:** Total amount spent this month, projected monthly budget, and current fixed prices for the space.
    *   **⚙️ Settings:** Profile details, logout, and (if Space Leader) an admin panel to update global tiffin prices.

## 5. Database Schema & Architecture (Supabase / PostgreSQL)

### Crucial Architectural Rules:
*   **Price Snapshotting:** The `tiffin_logs` table stores the `cost` at the time of logging. If the Leader changes the space price mid-month, past logs remain unaffected.
*   **Single Log per Day:** A unique constraint on `tiffin_logs` `(user_id, space_id, log_date)` ensures users can only have one active entry per day (updated if they change their mind).
*   **Auth Trigger:** A PostgreSQL trigger automatically creates a row in `public.users` when a user registers in `auth.users`.

### SQL Schema Overview:

**Table 1: `users`**
*   `id` (UUID, PK, references auth.users)
*   `full_name` (Text)
*   `avatar_url` (Text)
*   `created_at` (Timestamptz)

**Table 2: `spaces`**
*   `id` (UUID, PK)
*   `name` (Text)
*   `invite_code` (Text, Unique)
*   `leader_id` (UUID, references users.id)
*   `price_full` (Numeric)
*   `price_half` (Numeric)
*   `created_at` (Timestamptz)

**Table 3: `space_members`**
*   `id` (UUID, PK)
*   `space_id` (UUID, references spaces.id)
*   `user_id` (UUID, references users.id)
*   `role` (Text, 'leader' or 'member')
*   `joined_at` (Timestamptz)
*   *Constraint:* UNIQUE(space_id, user_id)

**Table 4: `tiffin_logs`**
*   `id` (UUID, PK)
*   `user_id` (UUID, references users.id)
*   `space_id` (UUID, references spaces.id)
*   `log_date` (Date)
*   `type` (Text, 'full', 'half', 'skip')
*   `cost` (Numeric) - *Snapshot of the price on this day*
*   `created_at` (Timestamptz)
*   *Constraint:* UNIQUE(user_id, space_id, log_date)

### Row Level Security (RLS)
*   Users can only edit their own profile and their own logs.
*   Users can read data (logs, member names) ONLY for the Spaces they are a member of.
*   Only the `leader_id` of a Space can update the `price_full` and `price_half`.