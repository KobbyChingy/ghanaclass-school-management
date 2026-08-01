# Tailscale Funnel Deployment

If you want a stable free public URL without buying a domain, use Tailscale Funnel.

This exposes the locally running backend through a stable HTTPS hostname like:

- `https://your-device.your-tailnet.ts.net`

For this machine, the current hostname pattern is the Tailscale device DNS name.

## Why Use This Path

- stable free hostname
- no domain purchase required
- no billing setup required
- HTTPS is handled by Tailscale
- avoids the temporary `trycloudflare.com` URL rotation

## Important Limits

This is still self-hosting from your own PC.

- your PC must stay on
- your internet connection must stay up
- the backend process must stay running
- Tailscale Funnel bandwidth limits are controlled by Tailscale

## Prerequisites

1. Tailscale installed
2. Signed in to Tailscale
3. Funnel approved for your tailnet
4. Supabase pooler `DATABASE_URL`

## One-Command Start

From the repo root:

```powershell
./scripts/start_tailscale_funnel_backend.ps1 `
  -DatabaseUrl "postgresql://postgres.<project-ref>:<url-encoded-password>@aws-...pooler.supabase.com:5432/postgres?sslmode=require" `
  -JwtSecret "your-long-random-secret" `
  -RunMigrate
```

What this does:

- starts the backend locally on port `8081`
- waits for the backend to begin listening
- enables `tailscale funnel --bg 8081`
- prints the stable `https://...ts.net` URL

## Current Stable URL

The currently active stable URL on this machine is:

- `https://savage.tail859933.ts.net`

## Flutter Configuration

Use the Tailscale Funnel URL as `GHANACLASS_API_BASE_URL`.

Example Android build:

```powershell
flutter build appbundle --release `
  --dart-define=GHANACLASS_API_BASE_URL=https://savage.tail859933.ts.net `
  --dart-define=GHANACLASS_TENANT_SCHEMA=school_demo `
  --dart-define=GHANACLASS_SUPABASE_URL=https://eqrkfynzaznoarcziepm.supabase.co `
  --dart-define=GHANACLASS_SUPABASE_PUBLISHABLE_KEY=sb_publishable_7oThgrzPu25cDp-4i_7I-w_y8YJ7H0f
```

For local Windows app runs:

```powershell
./scripts/run_windows_cloud_local.ps1 `
  -ApiBaseUrl "https://savage.tail859933.ts.net" `
  -TenantSchema "school_demo"
```

## Verification

1. Open the Funnel URL in a browser.
2. Confirm it returns JSON with `status: ok`.
3. Test login and registration against the same URL.

## Turn Funnel Off

```powershell
tailscale funnel --https=443 off
```