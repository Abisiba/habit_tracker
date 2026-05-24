# Habittracker Project Notes

## Overview

This repository contains a personal habit tracker with two clients sharing one Supabase row:

- `habittracker/`: KDE Plasma 6 widget.
- `habittracker-android/`: Flutter Android app.

Both clients read and write the same JSON document in `public.habittracker_state`, row `id = 'default'`.

## Data Model

Supabase table:

```sql
public.habittracker_state (
  id text primary key,
  data jsonb not null,
  updated_at timestamptz not null
)
```

`data` shape:

```json
{
  "habits": [
    {"id": 1, "name": "Drink Water", "points": 20, "isExtra": 0}
  ],
  "dailyRecords": {
    "2026-05-24": {"1": true}
  },
  "scoreHistory": {
    "2026-05-24": 20
  },
  "lastModified": "2026-05-24T11:30:00.000Z"
}
```

Unchecked habits should be absent from the day record, not stored as `false`.

## Sync Rules

- Sync uses Supabase REST with the anon key.
- Both clients upsert row `id = 'default'`.
- Conflict behavior is intentionally simple: the latest `lastModified` wins.
- Timestamps should be UTC ISO strings with `Z`.
- Do not add the previous `habittracker_prevent_stale_update` trigger back unless the conflict strategy is redesigned. It caused valid updates to be rejected when older timezone-less timestamps existed.

## Supabase Setup

Use the SQL in `habittracker-android/KURULUM.md`.

Required grants:

```sql
grant select, insert, update on public.habittracker_state to anon;
```

RLS policies allow public anon access only to row `id = 'default'`. This is acceptable for personal use but not secure for multi-user/public deployment. For a real multi-user app, add Supabase Auth, a `user_id` column, and user-scoped RLS policies.

## Android App

Path: `habittracker-android/`

Main files:

- `lib/main.dart`: UI, local preferences, sync orchestration.
- `lib/services/supabase_service.dart`: REST fetch/upsert, merge logic, HTTP error reporting.
- `test/supabase_service_test.dart`: regression test for unchecked habit merge.

Commands:

```bash
cd habittracker-android
flutter pub get
flutter test
flutter build apk --release
```

APK output:

```text
habittracker-android/build/app/outputs/flutter-apk/app-release.apk
```

Install on connected Android device:

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

## Plasma Widget

Path: `habittracker/`

Main files:

- `metadata.json`: Plasma package metadata, id `com.user.habittracker`.
- `contents/ui/main.qml`: widget UI and Supabase sync.
- `contents/config/main.xml`: persisted widget settings.

Local development install can use a symlink:

```bash
ln -sfn /path/to/Habittracker/habittracker \
  ~/.local/share/plasma/plasmoids/com.user.habittracker
systemctl --user restart plasma-plasmashell.service
```

The widget stores Supabase URL/key in Plasma config, not in the repository.

## Known Pitfalls

- If Android shows a red sync indicator, the app now displays the HTTP status/body text near the top of the screen.
- If the widget appears stale after code changes, restart Plasma shell.
- Do not commit generated folders: `build/`, `.dart_tool/`, `.gradle/`, `.idea/`, APKs, or Android `local.properties`.
- Real Supabase credentials should never be committed. The app asks for Project URL and anon key at runtime.

## Current Remote

GitHub remote:

```text
git@github.com:Abisiba/habit_tracker.git
```
