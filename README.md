# D-Dart — CIT-U Peer-to-Peer Campus Pabili & Delivery App

D-Dart is a Flutter peer-to-peer campus errand and delivery ("Pabili") platform built for **Cebu Institute of Technology - University (CIT-U)** using standard Flutter (`StatefulWidget`), **Supabase** (Auth, PostgreSQL with Row Level Security & atomic RPCs, Realtime, Storage, Edge Functions), and **Google Gemini Vision** (`gemini-3.8-flash`) for student Certificate of Registration (COR) / Study Load verification and schedule extraction.

---

## Core Modules & Architecture

| WBS | Module | Key Files |
| --- | --- | --- |
| **1** | **Foundation & Routing** | `lib/main.dart`, `lib/services/app_router.dart`, `lib/constants/supabase_constants.dart`, `supabase_schema.sql` |
| **2** | **Auth, Verification & Document Upload** | `lib/signup.dart`, `lib/login.dart`, `lib/verification_pending_screen.dart`, `lib/services/supabase_service.dart` |
| **3** | **Customer Mode & Pabili Requests** | `lib/customer_home_screen.dart`, `lib/pabili_request_screen.dart`, `lib/order_tracking_screen.dart`, `lib/utils/validators.dart` |
| **4** | **Runner Mode & Atomic Claiming** | `lib/runner_gig_board_screen.dart`, `lib/main_dashboard.dart`, `lib/role_selection.dart` |
| **5** | **Delivery Execution & 4-Digit OTP Handover** | `lib/order_tracking_screen.dart`, `lib/models/delivery_order.dart`, `verify_and_complete_delivery` RPC |
| **6** | **AI-Assisted COR Processing** | `lib/cor_upload_screen.dart`, `lib/services/gemini_service.dart`, `lib/models/class_schedule.dart`, `supabase/functions/verify-cor/index.ts` |
| **7** | **Academic Protection ("Duty Lock") & Admin** | `lib/services/duty_lock_service.dart`, `lib/admin_dashboard_screen.dart`, `lib/models/campus_location.dart`, `lib/models/system_config.dart`, `lib/models/problem_report.dart` |
| **8** | **Automated Tests** | `test/duty_lock_test.dart`, `test/gemini_parser_test.dart`, `test/order_lifecycle_test.dart`, `test/validators_test.dart`, `test/widget_test.dart` |

---

## Key Safeguards & Workflows

- **Role & Verification Gating**: Students and Faculty/Staff register with valid CIT-U IDs and upload ID documents (plus COR/Study Load for Students) into private Supabase Storage (`verification-documents`). If email confirmation is enabled during registration, document uploads and extracted schedules are staged locally and flushed automatically upon the user's first confirmed sign-in.
- **Atomic Delivery Lifecycle**:
  - Claiming a request runs through PostgreSQL RPC `claim_delivery_request(uuid)` with `FOR UPDATE` row locking to prevent duplicate claims.
  - Cancelling unclaimed orders runs through `cancel_delivery_request(uuid)`.
  - Handover completion requires matching the customer's 4-digit OTP via `verify_and_complete_delivery(uuid, text)` and records a finalized row in `delivery_records`.
- **Academic Protection (Duty Lock)**:
  - Only **verified Student** accounts with a confirmed COR schedule can enter Runner Mode.
  - Runner actions are automatically blocked during active classes, within the admin-configured pre-class buffer (`pre_class_buffer_minutes`, default `15`), or after reaching `daily_delivery_limit` (default `5`).
- **AI COR Verification (`verify-cor`)**:
  - Client sends base64 image + detected MIME type (`image/jpeg`, `image/png`, or `image/webp`) to the Supabase Edge Function `verify-cor` powered by `gemini-3.8-flash`.
  - Clearly unrelated images return a strict validation rejection (`is_valid: false`).
  - Transient upstream `503` / `429` capacity limits fall back cleanly to Demo OCR Mode so students can still review, edit, and submit their schedule manually.

---

## Setup & Supabase Administration

### 1. Run Flutter Locally

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

### 2. Supabase Database & Edge Function Setup

1. Execute [`supabase_schema.sql`](supabase_schema.sql) in the **Supabase SQL Editor** (safe & idempotent; seeds `locations` and `system_configurations`, creates private RLS helpers, triggers, and RPCs).
2. Ensure Edge Function **`verify-cor`** is deployed and set its secret in **Supabase Dashboard -> Edge Functions -> Secrets**:
   - `GEMINI_API_KEY`: Google AI Studio key with access to `gemini-3.8-flash`.
3. **Promoting an Administrator Account**:
   Because `public.protect_profile_privileged_fields()` blocks self-escalation via client APIs, promote your admin test account in the Supabase SQL Editor after signup:
   ```sql
   update public.profiles
   set account_type = 'admin',
       role = 'admin',
       verification_status = 'verified'
   where email = 'your-admin@cit.edu';
   ```
4. **Optional Supabase Dashboard Hardening**:
   - Enable **Leaked Password Protection** in **Authentication -> Providers / Security**.
   - Re-running [`supabase_schema.sql`](supabase_schema.sql) in the SQL Editor removes older overlapping `FOR ALL` RLS policies (`Allow admins manage locations`, `Allow users manage their schedules`, `Allow admins update configs`) in favor of the granular per-action policies already defined in the script.

---

## Known Limitations & Operational Notes

- **Google AI Studio Upstream Capacity**: During peak Google Gemini API traffic spikes (`503` / `429`), `verify-cor` automatically retries once and, if still unavailable, returns `503`; the Flutter client transitions to editable Demo OCR Mode so onboarding is not blocked.
- **Auth Email Confirmation & Rate Limits**: Default Supabase hosted email confirmation applies to new signups; users must confirm their email (or confirm via Supabase Auth Dashboard) before first login, at which point staged ID/COR documents and class schedules are uploaded automatically.
- **No Unverified Client Secret**: No Gemini private API key or Supabase `service_role` key is embedded in the Flutter client binary.
