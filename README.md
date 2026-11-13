# Qada Tracker

A personal Android prayer journal built with Flutter, Riverpod, and SQLite through Drift. English interface; Malay prayer names. Prayer records stay on the phone unless you export them. The optional Times tab sends the saved place coordinates to WaktuSolat for JAKIM zone timetables.

## Daily use

- **Today:** tick a performed prayer. Untick to leave it unrecorded. Use the prayer's menu to confirm a miss.
- **Review:** previous unrecorded days appear for review; mark prayers individually or confirm all remaining prayers for a day.
- **History:** select a date and correct its records. Earlier days remain saved when Today rolls over at local midnight or the app resumes.
- **Qada:** enter optional old balances in Settings, record replacements by prayer and quantity, or undo entries. Replacements never tick today's obligatory prayers.
- **Progress:** weekly/monthly performed totals, fully completed days, replacements, and unrecorded prayer totals.
- **Times:** choose a Malaysian place or device location, view prayer times, and enable prayer alerts.
- **Settings:** enable the daily check-in reminder, change appearance, or export/restore a versioned JSON backup using Android's document picker.

**Unticked does not mean missed.** Only confirmed misses add to qada. Balance = starting count + confirmed misses − replacements. Corrections cannot make balances negative; undo the conflicting replacement first. There is no “Not required” status.

## Daily check-in reminder (v1.1)

Enable **Settings → Daily check-in reminder** and allow Android notifications. On Android 12+, use **Allow alarms & reminders** for reliable timing. The reminder targets **11:00 PM in the phone's local timezone** and only appears when none of that day's five prayers is marked performed or missed. Qada replacements and settings changes do not count as daily prayer records. Notifications never add qada debt or change prayer statuses.

The Android alarm receiver reads the saved SQLite journal at delivery, so it works when Flutter is not running. Recording a prayer dismisses an already displayed reminder. A reminder is attempted at most once per calendar day; delayed reminders are suppressed after midnight. Reboot, app update, clock/timezone changes, permission changes, and app resume reschedule the check. Enabling after 11 PM schedules an immediate check if that day has not already been checked.

Reminders are off until enabled. Without alarm access, Android's inexact fallback may be delayed or skipped; it cannot guarantee 11 PM delivery. Force-stopping the app in Android settings suppresses alarms until you reopen it. Battery restrictions may also affect delivery. This is a local notification: no server, account, or network connection is used. The preference is included in backups; backups from v1.0 default to reminders off. A notification tap opens Today.


## Prayer Times (v1.2)

The **Times** tab uses the free [WaktuSolat API](https://api.waktusolat.app) without an API key. Coordinates resolve to a Malaysian prayer zone, then previous/current/next months are downloaded from its JAKIM timetable. The selected zone and `Asia/Kuala_Lumpur` timezone are visible in the tab. All 150 sample times for WLY01 in November 2026 matched the official e-Solat sample; zone lookup should still be checked near boundaries.

Select a place from the Malaysia dropdown or tap **Use device location**. Location is requested only on that action, at medium accuracy, rounded to three decimals. No background GPS or location history is collected. The saved point is reused for refreshes; tap the button again after travelling. Coordinates are sent to WaktuSolat and included in the plaintext journal backup along with the selected place and notification preference.

Enable **Prayer-time notifications** in the Times tab and grant notifications plus **alarms & reminders** access for on-time alerts. These alerts use a separate Android channel from the 11 PM check-in; neither feature ticks prayers or adds qada. Notification taps open the Times tab. Disabling is possible even while offline or when the API is unavailable.

Downloaded times are cached in SQLite and remain available offline. Android keeps only the next occurrence of each of the five prayers scheduled, then schedules successors after each alarm. WorkManager checks for refreshes every 12 hours when connected and downloads new months when fewer than 14 days remain. Refreshes use the last selected location, not a new GPS fix. Reboot, app updates, clock/timezone changes, and alarm-access grants reschedule alerts. Delayed broadcasts over 15 minutes old are discarded rather than replayed.

A network outage preserves an existing matching-place cache. Changing place immediately cancels the old place’s alarms; old responses cannot overwrite the new selection. Cached times for another place are never presented as the current result. When downloaded coverage runs out, alerts stop until a refresh succeeds; the app does not invent times. Android battery restrictions, denied permissions, or force-stop can delay/suppress delivery. Foreground refresh and background retry recover when access returns.

The database migrates from schema 1 to 2 by adding a separate calendar cache table. Existing prayer records are retained. Older backups default to Kuala Lumpur with prayer-time alerts off. Calendar downloads are regenerable and excluded from backups; restoring a different place reschedules its alerts.


## Appearance (v1.3)

Use the sun/moon button beside Settings for a quick light/dark toggle, or **Settings → Dark mode**. The selection is saved across restarts and included in backups. **Appearance → Follow system** restores automatic switching with the phone's theme.

The redesigned screens use mint/emerald colors, rounded glass panels, bordered pill buttons, circular outlined controls, and bundled Nunito typography. High contrast uses solid surfaces and stronger borders; large text remains scrollable. Glass blur is limited to summary/navigation panels. See the [design reference and render comparison](docs/design/glass-ui.md).


## Development

Use the existing checkout; each cloud task is isolated. Do not create a worktree unless explicitly requested.

Pinned toolchain: Flutter **3.38.5**, Gradle **8.14**, Android Gradle Plugin **8.11.1**, Kotlin **2.2.20**, Temurin JDK **17.0.17+10**, Android platform **36**, build tools **35.0.0**. The Android project follows the pinned Flutter release's templates.

On Linux x86-64, with Git, curl, unzip, and Python 3 installed (the setup script installs the pinned JDK):

```bash
cd /workspace/qada-tracker
./scripts/setup.sh
source scripts/env.sh
dart format lib test
./scripts/validate.sh
flutter devices
flutter run -d <android-device-id>
```

`QADA_TOOLS` can override `/workspace/toolchains`. Scripts retain the session proxy and TLS verification, verify the JDK checksum, and add the environment’s supplied public CA to that JDK when present. The Linux test runner reuses the image’s system SQLite library through a local soname alias. Dart and ADB also use their standard user-home caches; in a restricted sandbox these commands may need approved execution outside it. Downloads need GitHub, `storage.googleapis.com`, `pub.dev`, `dl.google.com`, Gradle distribution hosts, and Google/Maven Central artifact repositories (including redirects). Configure these in environment settings when network access is restricted.

The universal debug APK is generated at `build/app/outputs/flutter-apk/app-debug.apk`. Smaller architecture-specific builds are also available as `app-arm64-v8a-debug.apk`, `app-armeabi-v7a-debug.apk`, and `app-x86_64-debug.apk` in the same directory. Use the universal build if unsure. It is for personal installation, not store publication. Uninstalling the app deletes local records: export a backup first. Debug builds have the Internet permission for Flutter's development VM service; the main manifest has no network permission. Platform automatic cloud backup is disabled; backups are explicitly user initiated.

## Storage and backups

`lib/model.dart` owns calendar-date records, confirmation rules, starting balances, and the qada ledger. `lib/controller.dart` serializes mutations and publishes state only after disk writes succeed. `lib/database.dart` stores a versioned journal document in a single-row SQLite table, committed transactionally. The initial schema needs no code generation.

Backups include every record, setting, starting balance, and replacement entry. Imports validate dates, enums, counts, unique replacement IDs, version, and resulting balances before asking for confirmation. Restore replaces rather than merges data; SQLite commits it atomically. Cancelling either picker or confirmation preserves current data. Backup files are plain text, not encrypted; keep them private. The picker accepts files up to 10 MB (the plugin loads selected bytes into memory before validation).

Tracking begins on first launch. Elapsed days are derived from calendar dates, so missed app launches do not require a background process. Old unticked prayers never silently become debt. A local midnight timer and resume observer refresh Today; recording itself needs no permissions; the optional reminder uses notification/alarm access.

## Tests and current validation status

Tests cover the qada ledger and corrections, unrecorded gaps, backup validation and round trips, SQLite persistence and write-failure rollback, rapid serialized mutations, restore cancellation and confirmation, midnight/resume, and the main review-to-replacement UI flow.

Verified in the cloud instance:

- Pinned Flutter/Dart and JDK setup, with checksum verification and TLS trust intact.
- Frozen dependency resolution with `pubspec.lock`, and repeatable `scripts/setup.sh` execution.
- `scripts/validate.sh`: formatting checks, static analysis with **no issues**, **42 passing Flutter tests and 12 passing Android tests**, and a successful Android debug APK build.

The original Flutter download restriction has been resolved. The debug APK is available at the path above. Android runtime validation uses a separate disposable software emulator; see [VALIDATION.md](VALIDATION.md) for its result and limitations. No real phone has been tested. Chrome and Linux desktop doctor warnings are outside this Android app’s target.
