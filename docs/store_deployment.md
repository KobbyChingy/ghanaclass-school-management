# Store Deployment

This project is already set up for a hosted backend with Supabase as the database layer.

If you need the cheapest practical hosting path, prefer Google Cloud Run for the backend. See `docs/cloud_run_deployment.md`.
If billing verification blocks that path, use the local-machine plus Cloudflare Tunnel fallback in `docs/free_public_hosting.md`.

For production distribution, keep this split:

- Flutter app on Windows and Android
- GhanaClass backend API as the application server
- Supabase Postgres as the hosted database
- Supabase Auth / Storage as needed

Do not point the Flutter app directly at the Supabase dashboard URL for app business operations. Production builds should point `GHANACLASS_API_BASE_URL` at your deployed backend API.

## Cross-Platform Login Requirement

If you want an account created on one device to login on both Android and Windows:

- both platform builds must use the same hosted `GHANACLASS_API_BASE_URL`
- do not use `localhost` for store/distributed builds
- both builds must target the same production backend + database environment

This repo's release scripts now fail fast when `GHANACLASS_API_BASE_URL` is localhost unless you explicitly opt in for local testing.

## Required Release Values

Every store build should set these compile-time values:

- `GHANACLASS_API_BASE_URL`: your deployed backend URL
- `GHANACLASS_TENANT_SCHEMA`: default schema for the first-run tenant contract while the backend still supports it
- `GHANACLASS_SUPABASE_URL`: your Supabase project URL
- `GHANACLASS_SUPABASE_PUBLISHABLE_KEY`: your Supabase publishable key

To avoid retyping these values for every store build, copy `scripts/release.env.example` to `scripts/release.env` and fill in your production values.

## Windows Desktop / Microsoft Store

Use MSIX for Microsoft Store or enterprise-style Windows deployment.

Before running the store build helper, copy `scripts/msix.release.env.example`
to `scripts/msix.release.env` and fill in your production values:

- `MSIX_DISPLAY_NAME`
- `MSIX_PUBLISHER_DISPLAY_NAME`
- `MSIX_IDENTITY_NAME`
- `MSIX_PUBLISHER`
- `MSIX_VERSION`
- `MSIX_CERTIFICATE_PATH`
- `MSIX_CERTIFICATE_PASSWORD`

The store build helper now patches `msix_config` in memory from that file,
packages the app, and restores `pubspec.yaml` afterward. It will refuse to use
the checked-in development PFX for store builds.

Helper script:

```powershell
./scripts/build_windows_store_release.ps1
```

What it does:

- builds a Windows release executable with the hosted backend and Supabase values baked in
- packages that existing build into an `.msix` using `dart run msix:create --build-windows false`

For EXE installer distribution outside the Store:

```powershell
./scripts/build_inno_installer.ps1 -Configuration Release
```

Before publishing to Microsoft Store:

- create `scripts/msix.release.env` from the example file and point it at your real signing certificate
- use your real publisher identity and signing certificate
- verify app name, icons, version, and package identity

## Android / Play Store

Use an Android App Bundle (`.aab`) for Play Store submission.

Helper script:

```powershell
./scripts/build_android_play_release.ps1
```

Optional APK for pilot testing:

```powershell
./scripts/build_android_play_release.ps1 -IncludeApk
```

Before publishing to Play Store:

- configure Android signing/keystore
- copy `android/key.properties.example` to `android/key.properties` and fill in your real keystore values
- confirm `applicationId`, version name, and version code
- verify internet permissions and release metadata
- test login, sync, and offline reopen using the production backend

The Android project in this repo now uses:

- application ID: `com.ghanaclass.schoolmanagement`
- app label: `GhanaClass`

If `android/key.properties` is missing, release builds fall back to the debug signing config for local testing only. That is not suitable for Play Store submission.

## Supabase Notes

For deployment, Supabase remains the hosted database and identity platform, but your app traffic should still go through the deployed backend for auth-sensitive and sync-sensitive operations.

Recommended environment split:

- development Supabase project
- staging Supabase project
- production Supabase project

Each environment should have its own:

- backend API URL
- Supabase URL
- publishable key
- database connection secrets on the backend

## Suggested Release Sequence

1. Deploy the backend API against the production Supabase project.
2. Verify backend health and smoke test against production/staging.
3. Build Windows MSIX and Android AAB with production `dart-define` values.
4. Test login, sync push/pull, and offline reopen on both platforms.
5. Publish MSIX to Microsoft Store and AAB to Play Store.
