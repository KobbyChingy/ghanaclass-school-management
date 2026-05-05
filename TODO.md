# GhanaClass School Management — TODOs

This is an **actionable, repo-specific** TODO list (updated 2026-02-02).

## Done (this pass)

- Fix GoRouter name collision by renaming the alarms route to `admin_alarms`: [lib/core/router/app_router.dart](lib/core/router/app_router.dart#L181)
- Replace deprecated `DropdownButtonFormField.value` usage with `initialValue` (and `ValueKey` for sync):
  - Staff directory filter: [lib/features/staff/staff_screen.dart](lib/features/staff/staff_screen.dart#L136-L137)
  - Staff attendance filter: [lib/features/attendance/staff_attendance_screen.dart](lib/features/attendance/staff_attendance_screen.dart#L182-L183)
  - ID cards staff filter: [lib/features/id_cards/id_cards_screen.dart](lib/features/id_cards/id_cards_screen.dart#L269-L270)

- Add **local database Backup & Restore** in Settings (export `.db` file, restore from backup):
  - UI + logic: [lib/features/settings/settings_screen.dart](lib/features/settings/settings_screen.dart)

- Add **Staff Data Repair** tool (admin-only) to scan and repair legacy staff↔user linkage and NULL legacy fields:
  - UI: [lib/features/staff/staff_repair_screen.dart](lib/features/staff/staff_repair_screen.dart)
  - Logic: [lib/features/staff/staff_repair_service.dart](lib/features/staff/staff_repair_service.dart)
  - Route + entry point: [lib/core/router/app_router.dart](lib/core/router/app_router.dart)

- Add unit tests for Staff bulk actions (deactivate/delete + attendance-safe skip):
  - Tests: [test/staff_service_test.dart](test/staff_service_test.dart)
  - Test DB constructor: [lib/core/database/app_database.dart](lib/core/database/app_database.dart)

- Preserve leading-zero phone numbers during CSV import preview (disable numeric parsing) + add coverage:
  - Parser: [lib/features/staff/staff_import_service.dart](lib/features/staff/staff_import_service.dart)
  - Test: [test/staff_import_service_preview_test.dart](test/staff_import_service_preview_test.dart)

- Stabilize Windows test runs by pre-creating `build/unit_test_assets` to avoid an intermittent Flutter tool crash:
  - Script: [scripts/flutter_test_stable.ps1](scripts/flutter_test_stable.ps1)

## P0 — Must-do (stability / production blockers)

- Ensure all GoRouter route names are unique (prevents hard crash at startup/tests). Start with: [lib/core/router/app_router.dart](lib/core/router/app_router.dart)
- Keep alarm icon usage compatible with the installed Lucide package (avoid missing icon members). Check: [lib/features/alarms/alarms_screen.dart](lib/features/alarms/alarms_screen.dart)

## P1 — Should-do (data integrity / expected behavior)

- Confirm **every staff record has a profile** and stays consistent across legacy DBs:
  - Add/verify a "repair" pass that ensures the staff ↔ user linkage is valid and required fields are not null.
  - Related: [lib/core/database/app_database.dart](lib/core/database/app_database.dart)
  - Related staff reads: [lib/features/staff/staff_service.dart](lib/features/staff/staff_service.dart)

- Clarify filtering definition:
  - Current UI filters by `staff.position` as "Role/Position".
  - If you want portal/account roles, add a join against the linked user role and filter by that.
  - Staff directory: [lib/features/staff/staff_screen.dart](lib/features/staff/staff_screen.dart)

## P1 — Auth security / UX

- Server Mode password recovery:
  - Currently supported for local/offline only via master password.
  - If Server Mode is enabled, either implement a backend endpoint + client flow, or hide/disable recovery UI.
  - Auth service: [lib/core/services/auth_service.dart](lib/core/services/auth_service.dart)

- Add throttling/lockout for master-password recovery attempts (local), plus simple audit logging.

## P2 — Build & codegen hygiene

- Drift warning: `Duplicate orderings/filters detected for field "payrollRecordsRefs" on table "$UsersTable"`.
  - Status: resolved (codegen runs without this warning).
  - Table definitions: [lib/core/database/finance_expenditure_tables.dart](lib/core/database/finance_expenditure_tables.dart)

- Make build_runner execution repeatable on Windows (avoid stuck `Terminate batch job (Y/N)?` sessions):
  - Status: done (VS Code tasks added).
  - Prefer VS Code tasks in [.vscode/tasks.json](.vscode/tasks.json):
    - `Codegen: build_runner build`
    - `Codegen: build_runner watch`
  - If you prefer terminal commands:
    - Build once: `flutter pub run build_runner build --delete-conflicting-outputs`
    - Watch: `flutter pub run build_runner watch --delete-conflicting-outputs`
    - Note: avoid `dart run build_runner ...` in this Flutter app unless you're 100% sure `dart` is the one bundled with Flutter (standalone Dart SDKs can cause huge "invalid-type" errors like missing `Rect`/`Offset`).
  - Tip: If you started a watch task from VS Code, stop it via **Terminal: Terminate Task** / stopping the task, instead of Ctrl+C (reduces the chance of the interactive `Terminate batch job (Y/N)?` prompt on Windows).

## P3 — Nice-to-have

- Add a small widget test that boots the router and asserts the auth screen renders (guards against future route/name regressions).
  - Existing tests: [test/widget_test.dart](test/widget_test.dart)
