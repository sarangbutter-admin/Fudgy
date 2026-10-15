# Restore points (backups)

Before every change, a restore point is saved on GitHub as a branch named `backup-<date>-<number>-<label>`.
See them all: GitHub → the repo → the branch drop-down. Netlify only builds `dev`, so these cost nothing.

## Go back to an older version (code)
Ask Claude: "roll back dev to backup-2026-10-13-01-working". It runs:

    git checkout dev
    git reset --hard origin/<backup-branch>
    git push --force-with-lease origin dev

Only `dev` is rolled back. `main` (the live shop) is never touched without the owner's permission.

## Database (Supabase)
Code tags do not undo SQL migrations. Each migration is safe to run again, and a newer one replaces the older
function. To go back, run the older migration file again from the backup branch (`supabase/migrations/…` there).
Before risky data changes, take a copy: Supabase → Database → Backups (or Table Editor → export CSV).
