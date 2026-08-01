# Render Deployment

This project should be deployed to Render as a backend API service, not as the Flutter client.

The deploy target is the Dart Frog backend in `backend/`, and the public Render URL becomes the value for Flutter's `GHANACLASS_API_BASE_URL`.

## What Is Already Configured

The repository already contains:

- `render.yaml` for a Render Blueprint service named `ghanaclass-backend`
- `backend/Dockerfile` for the production container build
- a backend-scoped Render root directory so frontend-only changes do not trigger backend redeploys
- automatic startup migrations via `dart run bin/migrate.dart`
- a health check at `GET /`

## Required Environment Variables

Set these in Render:

```env
DATABASE_URL=postgres://.../postgres?sslmode=require
```

Use the exact Supabase Postgres connection string from the Supabase Connect dialog.
Render generates `JWT_SECRET` automatically from the Blueprint on first creation.

## Deploy Steps

1. Push the repository to GitHub.
2. In Render, choose New + and then Blueprint.
3. Select this repository.
4. Render should discover `render.yaml` and create the `ghanaclass-backend` web service.
5. Add `DATABASE_URL` in the Render dashboard when prompted.
6. Deploy the service.

## After Deploy

Take the public Render URL, for example `https://ghanaclass-backend.onrender.com`, and use it for Flutter builds:

```powershell
flutter build appbundle --release `
  --dart-define=GHANACLASS_API_BASE_URL=https://your-render-url.onrender.com `
  --dart-define=GHANACLASS_TENANT_SCHEMA=school_demo `
  --dart-define=GHANACLASS_SUPABASE_URL=https://your-project.supabase.co `
  --dart-define=GHANACLASS_SUPABASE_PUBLISHABLE_KEY=your-publishable-key
```

You can also use the same Render URL for Windows builds.

## First School Bootstrap

You do not need a separate Render job to create the first school if you use the existing registration flow.

Create the first school through:

- the app flow that calls `POST /auth/register_school`, or
- a direct API request to `POST /auth/register_school`

That endpoint creates the school, creates its schema, creates the first admin user, and returns an auth token.

## Verification

After deployment:

1. Open `https://your-render-url.onrender.com/`
2. Confirm it returns JSON with `status: ok`
3. Register a school or log in with an existing admin account
4. Point Flutter builds at the same Render base URL