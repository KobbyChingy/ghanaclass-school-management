# Stable Cloudflare URL

If you want a production-grade stable URL while still running the backend on your own machine, use a named Cloudflare Tunnel with your own domain.

This keeps the current backend architecture but replaces the temporary `trycloudflare.com` URL with a fixed hostname such as:

- `https://api.yourdomain.com`

## What You Need

1. A domain name you control
2. That domain added to Cloudflare DNS
3. A Cloudflare Zero Trust account
4. `cloudflared` installed on the Windows machine that runs the backend

## Why This Is More Stable

- the hostname stays the same across restarts
- you can use your own branded domain
- Cloudflare manages TLS for the public hostname
- your Flutter builds can point at a permanent API base URL

## Important Limits

This still runs on your own PC.

- your PC must stay on
- your internet connection must stay up
- if the local backend stops, the public hostname stops working

If you need true server-side uptime, the next step is a VM or paid host, not a tunnel.

## Recommended Setup In Cloudflare

Use the Cloudflare dashboard flow because it is simpler and avoids storing tunnel credentials in this repo.

1. Add your domain to Cloudflare.
2. Open Cloudflare Zero Trust.
3. Go to `Networks` or `Networking` and then `Tunnels`.
4. Create a new named tunnel.
5. Choose a tunnel name such as `ghanaclass-backend`.
6. Add a published application route:
   - Hostname: `api.yourdomain.com`
   - Service URL: `http://localhost:8081`
7. Copy the tunnel token that Cloudflare gives you for the connector.

## Start The Backend And Named Tunnel

From the repo root:

```powershell
./scripts/start_named_public_backend.ps1 `
  -DatabaseUrl "postgresql://postgres.<project-ref>:<url-encoded-password>@aws-...pooler.supabase.com:5432/postgres?sslmode=require" `
  -TunnelToken "your-cloudflare-tunnel-token" `
  -JwtSecret "your-long-random-secret" `
  -RunMigrate
```

What this does:

- starts the backend locally on port `8081`
- starts `cloudflared tunnel run --token ...`
- keeps both running in separate PowerShell windows

Your stable public URL is the hostname you created in Cloudflare, for example `https://api.yourdomain.com`.

## Flutter Configuration

Use your stable hostname as `GHANACLASS_API_BASE_URL`.

Example:

```powershell
flutter build appbundle --release `
  --dart-define=GHANACLASS_API_BASE_URL=https://api.yourdomain.com `
  --dart-define=GHANACLASS_TENANT_SCHEMA=school_demo `
  --dart-define=GHANACLASS_SUPABASE_URL=https://eqrkfynzaznoarcziepm.supabase.co `
  --dart-define=GHANACLASS_SUPABASE_PUBLISHABLE_KEY=sb_publishable_7oThgrzPu25cDp-4i_7I-w_y8YJ7H0f
```

## Verification

1. Start the script.
2. Open your stable hostname in a browser.
3. Confirm it returns JSON with `status: ok`.
4. Test login and registration through the same hostname.

## Security Note

Treat the tunnel token as a secret. Do not commit it into the repository.