# Free Public Hosting

If paid hosts and billing verification are blocked, the simplest working fallback is:

- run the backend on your own Windows machine
- expose it publicly with Cloudflare Tunnel
- point the Flutter app at that tunnel URL

This is genuinely free, and this repo now includes a helper for it.

## What This Gives You

- a public HTTPS URL for the backend
- no Google Cloud or Render billing setup
- no Docker requirement for the hosted path itself
- continued use of Supabase as the database

## Important Limits

This is a practical fallback, not a production cloud platform.

- your PC must stay on
- your internet connection must stay up
- the tunnel URL changes each time unless you later set up a named Cloudflare tunnel
- if the PC sleeps or shuts down, the backend disappears

Use this for demos, pilot testing, school onboarding, and short-term deployments.

If you want a stable production hostname instead of a temporary `trycloudflare.com` URL, use the named tunnel flow in `docs/stable_cloudflare_tunnel.md`.

## Prerequisites

1. Supabase `DATABASE_URL`
2. `cloudflared` installed
3. Dart / Flutter already working locally

This machine already appears to have `cloudflared` available.

## One-Command Start

From the repo root:

```powershell
./scripts/start_free_public_backend.ps1 `
  -DatabaseUrl "postgres://.../postgres?sslmode=require" `
  -JwtSecret "your-long-random-secret" `
  -RunMigrate
```

What happens:

- one PowerShell window starts the backend on `http://localhost:8081`
- a second PowerShell window starts `cloudflared`
- Cloudflare prints a public `https://...trycloudflare.com` URL

Use that printed URL as your app backend base URL.

## Manual Two-Terminal Option

If you want full control, use two separate terminals.

Backend terminal:

```powershell
./backend/scripts/start_supabase_local.ps1 `
  -DatabaseUrl "postgres://.../postgres?sslmode=require" `
  -JwtSecret "your-long-random-secret" `
  -RunMigrate
```

Tunnel terminal:

```powershell
./scripts/start_public_tunnel.ps1 -Port 8081
```

## Point Flutter At The Tunnel

For local Windows testing against the public tunnel:

```powershell
./scripts/run_windows_cloud_local.ps1 `
  -ApiBaseUrl "https://your-subdomain.trycloudflare.com" `
  -TenantSchema "school_demo"
```

For release builds, use the same tunnel URL as `GHANACLASS_API_BASE_URL`.

## Verification

1. Open the tunnel URL in a browser
2. Confirm it returns JSON with `status: ok`
3. Register a school or log in
4. Test Android and Windows against the same public URL

## Next Upgrade Path

When you are ready for a more stable hosted environment, move this same backend to:

- Tailscale Funnel, if you want a stable free `*.ts.net` hostname without buying a domain
- Google Cloud Run, if billing verification starts working later
- Oracle Cloud Always Free VM, if you want a more permanent free host and can handle Linux server setup