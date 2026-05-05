# Flutter mobile + desktop with Supabase and cloud-first sync

This project is best deployed as a shared Flutter application for mobile and desktop, backed by Supabase for cloud data and authentication, while keeping Drift/SQLite as the on-device local store.

The current app configuration has now been moved to an online-based mode: server mode is forced on, and the client should be treated as cloud-backed rather than as a standalone offline build.

## Backend API base URL and tenant defaults

This project currently uses a dedicated GhanaClass backend API in front of the cloud database. That means the Flutter client should not point its base URL directly at the Supabase project URL.

Use these roles:

- Supabase URL: database/auth/storage platform
- GhanaClass backend API URL: app-facing auth and sync API consumed by Flutter

Example:

- Supabase project URL: `https://<project-ref>.supabase.co`
- Backend API base URL: `https://api.your-domain.com`
- Legacy tenant schema header: `x-school-schema: school_demo`

Practical value split for this codebase:

- `GHANACLASS_API_BASE_URL`: your deployed GhanaClass backend URL, for example `https://api.your-domain.com`
- `GHANACLASS_TENANT_SCHEMA`: the school schema this app instance should target, for example `school_demo`
- backend `DATABASE_URL` or `DB_*` values: the Supabase Postgres connection details used by the GhanaClass backend, not by the Flutter client directly
- For local Windows backend development, prefer the exact Session pooler `DATABASE_URL` from Supabase Connect when the direct `db.<project-ref>.supabase.co` host is not reachable.

Authenticated sync no longer depends on always sending `x-school-schema` from Flutter. When the client has a valid bearer token, the backend resolves tenant context from `school_id` first, derives the schema from the school registry, and only uses the JWT schema claim as a compatibility fallback.

The sync endpoints themselves are now strictly authenticated: if the bearer token is missing or invalid, `/sync/push` and `/sync/pull` do not downgrade to header-only tenant resolution.

The Flutter client now supports default values through `dart-define`:

- `GHANACLASS_API_BASE_URL`
- `GHANACLASS_TENANT_SCHEMA`
- `GHANACLASS_SUPABASE_URL`
- `GHANACLASS_SUPABASE_PUBLISHABLE_KEY`

These values are centralized in [lib/core/config/backend_config.dart](c:/Users/ENOCH/Desktop/ghanaclass-school-management/lib/core/config/backend_config.dart).

Supabase client bootstrap values are centralized in [lib/core/config/supabase_config.dart](c:/Users/ENOCH/Desktop/ghanaclass-school-management/lib/core/config/supabase_config.dart).

There is also a checked-in backend env template at [backend/.env.example](c:/Users/ENOCH/Desktop/ghanaclass-school-management/backend/.env.example).

Example client launch:

```powershell
flutter run -d windows --dart-define=GHANACLASS_API_BASE_URL=https://api.your-domain.com --dart-define=GHANACLASS_TENANT_SCHEMA=school_demo --dart-define=GHANACLASS_SUPABASE_URL=https://eqrkfynzaznoarcziepm.supabase.co --dart-define=GHANACLASS_SUPABASE_PUBLISHABLE_KEY=sb_publishable_7oThgrzPu25cDp-4i_7I-w_y8YJ7H0f
```

Or use the local helper script from the repo root:

```powershell
./scripts/run_windows_cloud_local.ps1 -ApiBaseUrl http://localhost:8081
```

## Manual Setup Still Needed

These are the remaining setup steps you still need to do yourself because they involve secrets or Supabase dashboard access:

1. In Supabase, copy the exact Session pooler `DATABASE_URL` from the Connect dialog.
2. Keep the real database password available and URL-encode special characters if you ever compose the DSN manually.
3. Choose a backend `JWT_SECRET` value and store it only in your local env or deployment secrets.
4. If you deploy the backend later, decide the public backend URL that Flutter should use for `GHANACLASS_API_BASE_URL`.

Local development sequence:

```powershell
./backend/scripts/start_supabase_local.ps1 -DatabaseUrl "<exact session pooler dsn>" -JwtSecret "<jwt secret>" -RunMigrate
./scripts/run_windows_cloud_local.ps1 -ApiBaseUrl http://localhost:8081
```

If you want production deployment later, the only values you will need to swap are the backend API URL and your deployment secrets. The Flutter-side Supabase URL and publishable key are already wired into the app.

Note: the Next.js files you posted such as `.env.local`, `page.tsx`, `utils/supabase/server.ts`, and `middleware.ts` do not apply to this repository because this workspace is Flutter + Dart Frog, not Next.js. The equivalent setup in this codebase is `supabase_flutter` initialization during app startup.

The codebase already points in that direction:

- Local data and offline queues already exist in Drift, including `sync_outbox` and `sync_metadata` in [lib/core/database/sync_tables.dart](c:/Users/ENOCH/Desktop/ghanaclass-school-management/lib/core/database/sync_tables.dart).
- A custom backend auth/sync path already exists through `RemoteAuthApi`, `RemoteSyncApi`, and `SyncService`.
- A small Supabase bootstrap exists in [lib/core/services/supabase_service.dart](c:/Users/ENOCH/Desktop/ghanaclass-school-management/lib/core/services/supabase_service.dart), but Supabase is not yet the primary runtime backend.

This document defines the recommended production direction.

## Recommended deployment model

### Client platforms

- Mobile: Android and iOS using the same Flutter app
- Desktop: Windows first, with macOS optional later

### Cloud backend

- Supabase PostgreSQL as the central system of record
- Supabase Auth for user identities and session management
- Supabase Storage for documents, receipts, report exports, and media assets
- Supabase Realtime only where truly needed, such as notifications or approval dashboards
- Supabase Edge Functions or a secured backend service for privileged workflows

### Local device layer

- Drift/SQLite remains the local operational database on every device
- In the current build, Drift acts as the local store and sync cache for a cloud-backed app
- Sync sends and receives deltas between the local Drift database and Supabase-backed cloud services

This is the right model for schools that may have unstable connectivity, shared office desktops, and mobile users working across weak networks.

## Recommended tenancy model for Supabase

### Recommended for Supabase: shared schema + `school_id` + Row Level Security

For plain PostgreSQL, schema-per-school is a valid choice. For Supabase specifically, a shared schema with strong tenant isolation through Row Level Security is the more practical production model.

Recommended pattern:

- Keep tenant tables in one application schema, usually `public`
- Add `school_id` to every tenant-owned table
- Enforce access with Supabase Row Level Security policies
- Derive the effective `school_id` from the authenticated user profile or membership table

Why this is better for Supabase:

- It fits Supabase Auth and PostgREST access patterns naturally
- It simplifies dashboards, migrations, backups, and generated APIs
- It avoids per-school schema management overhead during onboarding
- It works better with Realtime, Storage policies, and Edge Functions

### Core cloud tables

Recommended shared tables:

- `schools`
- `school_memberships`
- `profiles`
- `devices`
- `applied_ops`
- `change_log`
- domain tables such as `students`, `staff`, `payments`, `attendance_records`, `classes`, `subjects`, `payroll_runs`, `shop_sales`

Each tenant-owned table should include:

- `id`
- `school_id`
- `remote_id` if local numeric IDs remain in Drift
- `created_at`
- `updated_at`
- `deleted_at` for tombstones where sync deletes must propagate

## Role and access model

The active portal scope in this codebase is:

- Director
- Admin
- Headmaster/Headmistress
- Teacher
- Accountant
- Shop

Recommended Supabase authorization design:

- Supabase Auth stores the user identity
- `profiles` stores person metadata
- `school_memberships` links each user to a school and role
- RLS policies restrict all tenant rows by `school_id`
- Edge Functions or secure backend endpoints enforce privileged workflows such as staff creation, audit-sensitive changes, and finance approvals

Do not rely on Flutter-side role checks as the primary security layer.

## Current codebase alignment

The current implementation is still centered on a custom backend base URL and custom sync/auth endpoints:

- [lib/core/services/remote_auth_api.dart](c:/Users/ENOCH/Desktop/ghanaclass-school-management/lib/core/services/remote_auth_api.dart)
- [lib/core/services/remote_sync_api.dart](c:/Users/ENOCH/Desktop/ghanaclass-school-management/lib/core/services/remote_sync_api.dart)
- [lib/core/services/sync_service.dart](c:/Users/ENOCH/Desktop/ghanaclass-school-management/lib/core/services/sync_service.dart)
- [backend/lib/db/postgres_pool.dart](c:/Users/ENOCH/Desktop/ghanaclass-school-management/backend/lib/db/postgres_pool.dart)
- [backend/lib/tenancy/tenant_schema.dart](c:/Users/ENOCH/Desktop/ghanaclass-school-management/backend/lib/tenancy/tenant_schema.dart)

That means there are two realistic production paths:

### Path A: Supabase as database and auth, keep a custom sync/backend layer

This is the recommended path for this project.

- Keep the existing `RemoteAuthApi` and `RemoteSyncApi` pattern
- Point that backend at Supabase Postgres instead of a separate unmanaged Postgres deployment
- Replace schema-header tenancy with authenticated `school_id` resolution
- Use Supabase Auth tokens in the backend for identity validation
- Keep privileged logic in Edge Functions or in the existing backend service

### Path B: Move most backend operations directly into Supabase client access

This is possible but less ideal for this codebase today because:

- sync rules are already modeled as custom push/pull endpoints
- privileged operations are easier to protect server-side
- conflict handling and audit enforcement are easier in dedicated functions/services

## Offline sync strategy between Drift and Supabase

### Local-first rule

Every feature should continue to write locally first. The cloud must not be required for normal user interaction.

### Existing local sync structures

Already present:

- `sync_outbox`
- `sync_metadata`

Recommended additions over time:

- entity-level sync state helpers
- per-row `remote_id`
- `last_synced_at`
- `is_dirty`
- optional `sync_error`

### Push flow

1. User performs an action in the app
2. Drift writes the local domain row
3. Drift appends an outbox record with `op_id`, entity type, operation, and payload
4. Background sync sends pending operations to the backend
5. Backend validates identity, role, school membership, and business rules
6. Backend writes to Supabase Postgres transactionally
7. Backend records the operation in `applied_ops` for idempotency
8. Backend appends a normalized change event to `change_log`
9. Client marks the outbox item as acknowledged

### Pull flow

1. Client sends its last applied cloud cursor
2. Backend returns ordered changes after that cursor
3. Client applies supported changes into Drift in a transaction
4. Client advances its local cursor in `sync_metadata`

### Conflict policy

Use different rules by data class:

- Reference data: last-write-wins with `updated_at`
- Attendance: prefer append-only or server-validated updates
- Finance: server-side validation and explicit rejection on illegal conflicts
- Exams and results: require stronger audit trails and explicit overwrite rules
- Security or approvals: never silent overwrite; log and require review when necessary

### Deletes

Use tombstones rather than hard deletes in synced cloud tables.

- cloud rows should set `deleted_at`
- pull responses should include delete operations or deleted records
- local client should mirror the delete or soft-delete locally

## Recommended Supabase data model mapping

The local Drift schema is large, so the migration should happen by domain rather than all at once.

### Phase 1 domains

Start with these cloud domains first:

- schools and memberships
- users and staff
- students
- classes and subjects
- attendance
- fees and payments

### Phase 2 domains

- payroll
- expenditures
- reports
- shop or canteen operations
- lesson notes and academic planning

### Phase 3 domains

- alerts and workflows
- analytics materializations
- audit and compliance enrichments
- document storage integrations

### Mapping rule of thumb

- Keep local Drift integer primary keys if that simplifies the UI and joins
- Add a stable `remote_id` UUID for cloud identity
- Treat `remote_id` as the cross-device synchronization key
- Keep cloud-side timestamps authoritative for merge ordering where needed

## Authentication and session model

Recommended production approach:

- Use Supabase Auth for login
- Store the authenticated user session securely in the Flutter app
- After login, fetch the user profile and school membership
- Persist school membership metadata locally for offline use
- Keep the last known role and school in local cache so the app can reopen offline

If the current custom login API is retained, it should exchange credentials for a Supabase-authenticated identity or a backend-issued session tied to Supabase Auth.

## Mobile and desktop release plan

### Android

- produce `aab` for Play Store release
- produce `apk` for direct school-side testing and pilot rollouts
- configure app signing, package id, environment config, and secure release keys

### iOS

- build later from macOS when App Store or TestFlight distribution is needed
- configure bundle id, signing certificates, and App Store Connect metadata

### Windows

- keep `.msix` for managed enterprise-style deployment
- keep `.exe` installer for simpler direct distribution
- sign the installer if the deployment model requires reduced SmartScreen friction

### Environment configuration

Use at least three environments:

- development
- staging
- production

Each environment should have separate:

- Supabase project
- auth keys
- storage buckets
- backend base URLs or function URLs
- release config values

Do not hardcode production URLs or secrets in the client.

## Recommended production rollout sequence

1. Keep Drift as the primary local database on every platform.
2. Use Supabase Postgres as the cloud source of truth.
3. Move tenancy from schema-header routing to authenticated `school_id` membership checks.
4. Implement RLS policies for every tenant-owned table.
5. Keep a server-side sync API or Edge Function layer for push/pull, conflict handling, and audit-sensitive writes.
6. Ship Android and Windows first.
7. Add iOS after the mobile production path is stable.

## Immediate implementation roadmap

1. Choose Path A formally: Supabase-backed database and auth with a retained custom sync/backend layer.
2. Introduce a canonical cloud tenant model using `school_id` and `school_memberships`.
3. Define the first cloud migration set for students, staff, classes, attendance, and finance basics.
4. Replace schema-based tenancy assumptions in backend sync/auth logic.
5. Connect the existing Flutter login and sync services to the chosen production backend path.
6. Add RLS policies and role tests before broad rollout.
7. Prepare Android and Windows release configuration per environment.

## Bottom line

For this project, the best production architecture is:

- Flutter on mobile and desktop
- Drift/SQLite for offline-first local operation
- Supabase Postgres as the cloud database
- Supabase Auth for identity
- Supabase Storage for files
- a controlled server-side sync/auth layer for push, pull, conflict handling, approvals, and audit-sensitive operations

That gives you reliable school-side offline behavior, a single cloud data platform, and a deployment model that works for both mobile app distribution and desktop installer distribution.
