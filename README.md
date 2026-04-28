# Track My Weight

Track every change, clearly.

Track My Weight is a Flutter mobile app for recording people's weights over time. It replaces the paper weight book with a clean digital register, history tracking, charts, local storage, and optional Supabase cloud sync.

## Features

- Add multiple people
- Log weight entries by date
- Add optional notes per entry
- View latest weight and recent change
- View total change, highest weight, and lowest weight
- Weight trend chart
- Entry history
- Delete people and weight records
- Light, dark, and system theme modes
- App icon and native splash screen
- Local SQLite storage by default
- Optional Supabase cloud storage

## Tech Stack

- Flutter
- Dart
- SQLite with `sqflite`
- Supabase with `supabase_flutter`
- Charts with `fl_chart`

## Project Structure

```text
lib/
  main.dart
  models/
    person.dart
    weight_entry.dart
  services/
    app_database.dart
    supabase_config.dart
    supabase_database.dart
assets/
  brand/
tool/
  generate_brand_assets.dart
```

## Getting Started

Install dependencies:

```powershell
flutter pub get
```

Run the app locally:

```powershell
flutter run
```

Analyze code:

```powershell
flutter analyze
```

Run tests:

```powershell
flutter test
```

## Storage Modes

The app supports two storage modes.

### Local SQLite

If no Supabase credentials are provided, the app stores data locally on the device in SQLite.

This is private and offline-friendly, but data does not appear on other phones.

### Supabase Cloud

If Supabase credentials are provided, the app stores data in Supabase.
Supabase Project: Track My Weight
Pass: TrackMyWeight1

Run with:

```powershell
flutter run `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

Create the database tables using:

- `supabase_schema.sql`
- `SUPABASE_SETUP.md`

Current Supabase mode is a shared cloud database. Before public release, add Supabase Auth and Row Level Security so users only see their own records.

## Git Workflow

Use small, focused commits. Each commit should explain one logical change.

Recommended branch names:

```text
feat/supabase-sync
fix/delete-entry-crash
ui/dashboard-polish
docs/readme-update
chore/flutter-deps
```

## Commit Message Convention

Use Conventional Commits:

```text
type(scope): short description
```

Examples:

```text
feat(storage): add Supabase cloud sync
fix(history): prevent deleting wrong entry
ui(theme): add dark mode support
docs(readme): document setup steps
chore(deps): add launcher icon package
test(widget): update dashboard smoke test
refactor(database): split Supabase service
```

Common commit types:

- `feat`: new feature
- `fix`: bug fix
- `ui`: visual or interaction change
- `docs`: documentation only
- `chore`: maintenance, tooling, dependencies
- `test`: tests only
- `refactor`: code restructuring without behavior change
- `perf`: performance improvement
- `build`: build system or platform config

## Pull Request Checklist

Before opening or merging a PR:

- Run `flutter analyze`
- Run `flutter test`
- Confirm no secrets are committed
- Keep generated build files out of Git
- Update README or setup docs when behavior changes
- Use a clear PR title following the commit convention

## Files That Should Not Be Committed

Do not commit:

- `.env`
- Supabase service role keys
- Google OAuth client secret files
- Firebase service files unless intentionally configured for the app
- Build outputs
- Local IDE folders

The `.gitignore` includes protections for common local secret files.

## Current Status

The app is an MVP with polished UI, local storage, and Supabase-ready cloud storage. Next planned work:

- Supabase Auth
- Row Level Security
- Edit person and weight records
- Goal weight tracking
- Export/backup
