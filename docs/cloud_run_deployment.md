# Cloud Run Deployment

If you need a practical free hosting path for this backend, use Google Cloud Run with Supabase Postgres.

Why this is the best fit for the current repo:

- the backend already has a production Dockerfile
- Cloud Run scales to zero on idle traffic
- low-traffic API usage can stay inside the Cloud Run free tier
- Supabase remains the database, so you do not need to move data hosting

## Important Cost Note

Cloud Run is the best free-tier option for this repo, but it is not an unlimited always-on free VM.

To stay as close to free as possible:

- deploy in `us-central1`
- keep `min-instances=0`
- keep `max-instances=1`
- keep memory at `512Mi`
- avoid unnecessary redeploys from source, because source deploys use Cloud Build and Artifact Registry

For a small school backend with low traffic, this is usually the easiest path to near-zero cost.

## Prerequisites

1. A Google Cloud project
2. Billing enabled on that project
3. Google Cloud CLI installed locally
4. A Supabase `DATABASE_URL`

## One-Command Deploy

Use the helper script from the repo root:

```powershell
./scripts/deploy_cloud_run.ps1 `
  -ProjectId your-gcp-project-id `
  -DatabaseUrl "postgres://.../postgres?sslmode=require"
```

What the script does:

- enables Cloud Run, Cloud Build, and Artifact Registry APIs
- deploys from `backend/`, which already contains the Dockerfile
- sets `DATABASE_URL`
- generates `JWT_SECRET` automatically if you do not provide one
- deploys the service publicly so the Flutter app can reach it
- prints the resulting Cloud Run URL

Optional parameters:

```powershell
./scripts/deploy_cloud_run.ps1 `
  -ProjectId your-gcp-project-id `
  -DatabaseUrl "postgres://.../postgres?sslmode=require" `
  -ServiceName ghanaclass-backend `
  -Region us-central1 `
  -JwtSecret "your-long-random-secret"
```

## Manual Deploy

If you prefer to deploy without the helper script:

```powershell
gcloud services enable run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com

gcloud run deploy ghanaclass-backend `
  --source backend `
  --region us-central1 `
  --allow-unauthenticated `
  --cpu 1 `
  --memory 512Mi `
  --concurrency 20 `
  --min-instances 0 `
  --max-instances 1 `
  --set-env-vars DATABASE_URL="postgres://.../postgres?sslmode=require" `
  --set-env-vars JWT_SECRET="your-long-random-secret"
```

If a Dockerfile is present in the source directory, Cloud Run source deployment uses that Dockerfile. This repo already satisfies that requirement in `backend/`.

## After Deploy

Take the Cloud Run URL and use it for Flutter builds:

```powershell
flutter build appbundle --release `
  --dart-define=GHANACLASS_API_BASE_URL=https://your-service-url.a.run.app `
  --dart-define=GHANACLASS_TENANT_SCHEMA=school_demo `
  --dart-define=GHANACLASS_SUPABASE_URL=https://your-project.supabase.co `
  --dart-define=GHANACLASS_SUPABASE_PUBLISHABLE_KEY=your-publishable-key
```

## Verification

After deployment:

1. Open `https://your-service-url.a.run.app/`
2. Confirm the service responds with JSON containing `status: ok`
3. Register a school through `POST /auth/register_school` or the app flow
4. Test login from both Android and Windows against the same backend URL

## If You Need Truly Always-Free Compute

If you need a backend that never scales to zero and still stays free, the next option is an Oracle Cloud Always Free VM.

That is still viable, but it requires manual Linux VM setup, Docker or systemd management, firewall rules, and TLS configuration. Cloud Run is much simpler for this repo.