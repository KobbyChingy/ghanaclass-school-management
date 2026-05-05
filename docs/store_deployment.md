# Store Deployment

This project is already set up for a hosted backend with Supabase as the database layer.

For production distribution, keep this split:

- Flutter app on Windows and Android
- GhanaClass backend API as the application server
- Supabase Postgres as the hosted database
- Supabase Auth / Storage as needed

Do not point the Flutter app directly at the Supabase dashboard URL for app business operations. Production builds should point `GHANACLASS_API_BASE_URL` at your deployed backend API.

## Required Release Values

Every store build should set these compile-time values:

- `GHANACLASS_API_BASE_URL`: your deployed backend URL
- `GHANACLASS_TENANT_SCHEMA`: default schema for the first-run tenant contract while the backend still supports it
- `GHANACLASS_SUPABASE_URL`: your Supabase project URL
- `GHANACLASS_SUPABASE_PUBLISHABLE_KEY`: your Supabase publishable key

To avoid retyping these values for every store build, copy `scripts/release.env.example` to `scripts/release.env` and fill in your production values.

## Windows Desktop / Microsoft Store

Use MSIX for Microsoft Store or enterprise-style Windows deployment.

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

- replace the development MSIX certificate settings in `pubspec.yaml`
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
