# GhanaClass Backend (Dart Frog)

## Requirements

- Dart SDK (bundled with Flutter is fine)
- PostgreSQL (local or managed)

Optional (recommended for quick local setup):

- Docker Desktop

## Configure

Set environment variables (PowerShell example), or create a `backend/.env` file.

Preferred for Supabase:

- `DATABASE_URL` from the Supabase Connect dialog

- `DB_HOST`
- `DB_PORT` (default: 5432)
- `DB_NAME`
- `DB_USER`
- `DB_PASSWORD`

Optional:

- `DB_SSL` (`true`/`false`)

Auth:

- `JWT_SECRET` (signs login tokens; use a strong random value in production)

Supabase-backed deployment:

- Keep using this backend as the API layer for the Flutter app.
- Point the backend database environment variables at your Supabase Postgres connection.
- The Flutter app's API base URL should point to this deployed backend, not directly to the Supabase project URL.
- The current tenant contract uses `x-school-schema` and values such as `school_demo` or `school_001`.
- For Supabase, use SSL and prefer the exact connection string shown in the Supabase Connect dialog.
- For local Windows development, prefer the Session pooler `DATABASE_URL` from Supabase Connect unless you know the machine has working IPv6 reachability to the direct database host.

Example `backend/.env`:

```env
DATABASE_URL=postgres://postgres.your-project-ref:[YOUR-PASSWORD]@aws-0-your-region.pooler.supabase.com:5432/postgres?sslmode=require
JWT_SECRET=replace-with-a-long-random-secret
```

You can start from [backend/.env.example](c:/Users/ENOCH/Desktop/ghanaclass-school-management/backend/.env.example).

If `DATABASE_URL` is present, the backend will use it and ignore the individual `DB_*` fields.

Multi-school tenancy:

- Send `x-school-schema: school_<code>` header (e.g. `school_001`) on requests.

Example production split:

- Supabase project URL: `https://<project-ref>.supabase.co`
- GhanaClass backend API URL: `https://api.your-domain.com`
- Flutter `GHANACLASS_API_BASE_URL`: `https://api.your-domain.com`
- Flutter `GHANACLASS_TENANT_SCHEMA`: `school_demo`

Practical mapping:

- `DATABASE_URL`: the full Postgres connection string copied directly from Supabase Connect
- Direct `db.<project-ref>.supabase.co:5432` URLs may fail on local Windows networks when IPv6/DNS reachability is unavailable.
- Session pooler is the safer default for local backend development, but you must use the exact dashboard-issued DSN instead of reconstructing it by hand.
- `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`: taken from Supabase Database connection settings
- `DB_SSL=true`: required for hosted Supabase connections
- `GHANACLASS_API_BASE_URL`: the public URL where this Dart Frog backend is deployed
- `GHANACLASS_TENANT_SCHEMA`: the schema name the current backend should target for a given school

## Run

From the `backend` folder:

- `dart pub get`
- `dart run bin/migrate.dart`
- `dart run dart_frog_cli:dart_frog dev --port 8081`

Create a school schema (example):

- `SCHOOL_CODE=001 SCHOOL_NAME="Demo School" dart run bin/bootstrap_school.dart`

If you don’t have PostgreSQL installed locally, you can start one with Docker:

- `docker compose -f docker-compose.yml up -d`
- Then run the migrate + bootstrap commands above.

Health check:

- `GET http://localhost:8081/`

For Flutter builds, you can inject the backend defaults with `--dart-define`:

```powershell
flutter run -d windows --dart-define=GHANACLASS_API_BASE_URL=https://api.your-domain.com --dart-define=GHANACLASS_TENANT_SCHEMA=school_demo
```

Or use the root helper script for local Windows development:

```powershell
./scripts/run_windows_cloud_local.ps1 -ApiBaseUrl http://localhost:8081
```

For local backend development with PowerShell:

```powershell
$env:DATABASE_URL="postgres://postgres.your-project-ref:[YOUR-PASSWORD]@aws-0-your-region.pooler.supabase.com:5432/postgres?sslmode=require"
$env:JWT_SECRET="replace-with-a-long-random-secret"
dart run dart_frog_cli:dart_frog dev --port 8081
```

If the direct DSN fails with a host lookup or connection-refused error, switch to the exact Session pooler DSN from the Supabase dashboard.

You can also use the helper script:

```powershell
./scripts/start_supabase_local.ps1 -DatabaseUrl "postgres://postgres.your-project-ref:[YOUR-PASSWORD]@aws-0-your-region.pooler.supabase.com:5432/postgres?sslmode=require" -JwtSecret "replace-with-a-long-random-secret" -RunMigrate
```

The helper script expects the exact DSN from Supabase Connect and is the simplest way to start the local backend against Supabase.

Practical local sequence:

1. Copy the exact Session pooler `DATABASE_URL` from Supabase Connect.
2. Choose a `JWT_SECRET` value for the backend.
3. Start the backend:

```powershell
./backend/scripts/start_supabase_local.ps1 -DatabaseUrl "<exact session pooler dsn>" -JwtSecret "<jwt secret>" -RunMigrate
```

4. Start the Flutter Windows app against that backend:

```powershell
./scripts/run_windows_cloud_local.ps1 -ApiBaseUrl http://localhost:8081
```

For sync requests, authenticated clients no longer need to rely on `x-school-schema` as the primary tenant selector. The backend now resolves tenant context from the authenticated `school_id` first, derives the schema from `public.schools`, and keeps the JWT schema claim only as a compatibility fallback.

For `/sync/push` and `/sync/pull`, an invalid or missing bearer token no longer falls back to `x-school-schema`. Those routes are now strictly authenticated.

## Auth endpoints

- `POST /auth/register_school`
  - Creates a school + schema and an initial admin user (email/password)
  - Returns `token` for the admin

- `POST /auth/register_staff` (requires `Authorization: Bearer <token>` for an admin)
  - Creates a staff user (email/password) for the admin's school

- `POST /auth/login`
  - Login by `email` + `password` and returns a signed `token`
