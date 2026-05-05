# Staff Import QA (manual)

Use these files:

- `staff_import_sample_valid.csv`
- `staff_import_sample_errors.csv`

## Quick checks

Notes on phone numbers:

- CSV import preserves leading zeros (e.g. `055...`).
- For Excel imports, ensure the Phone column is formatted as **Text** to avoid Excel stripping leading zeros.

1. Open **Staff** → **Import**.
2. Import `staff_import_sample_errors.csv`.
   - Expect: import fails for specific rows.
   - Click **Download error report** and confirm the `.txt` opens and contains row numbers + reasons.
3. Import `staff_import_sample_valid.csv`.
   - Expect: staff profiles created/updated.
   - Verify: Staff Directory shows the new staff and portal login works (or at least user account exists).

## Bulk actions checks

1. In **Staff Directory**, click **Bulk Actions**.
2. **Select All** (or select 1–2 records).
3. Click **Deactivate**.
   - Expect: selected staff `isActive=false` and their portal login is disabled.
4. Click **Delete**.
   - Expect: selected staff are deleted _unless_ they have staff attendance records (those should be skipped).
   - Verify: snackbar shows deleted/skipped counts.
