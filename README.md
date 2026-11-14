# Qada Tracker

A personal Android prayer journal built with Flutter, Riverpod, and SQLite through Drift. English interface; Malay prayer names. Prayer records stay on the phone unless you export them. Today loads JAKIM prayer times from the free WaktuSolat API using the saved place coordinates (Kuala Lumpur by default).

## Downloads and versions

[Download the latest private Android release](https://github.com/zulhisyamsofi/qada-tracker/releases/latest). Sign in with a GitHub account that has repository access to download its APK. Each feature edition has a separate commit, annotated version tag, release notes, APK, and checksum file. See [RELEASES.md](RELEASES.md) and [CHANGELOG.md](CHANGELOG.md).

## Smaller installation downloads

From v1.12.0, GitHub downloads use optimized **release-mode** APKs with Dart AOT compilation, tree shaking, R8 code shrinking, resource shrinking, and icon tree shaking. No app features are removed. Choose the **arm64-v8a APK** for a Realme GT Master or most recent Android phones; the unsuffixed APK is a universal fallback containing all three supported processor types. Other downloads target older 32-bit ARM phones and x86-64 emulators. Install one APK over the existing app to preserve the journal; the application ID and signing certificate remain the same.

Reproduce all four optimized APKs and their checksums with `./scripts/build-release.sh`; output is under `build/releases/v<version>/`. The ordinary `scripts/validate.sh` still builds a debug APK for development checks. **Do not use the debug APK for distribution.** Release mode does not expose debug tools; it retains the existing personal-use signing key for update compatibility. Dart obfuscation is unnecessary for this size reduction.

## First launch walkthrough

New installations open an eight-step guided tour that highlights real controls and visits all four tabs. It explains recording/clearing prayers, confirming misses, place selection and prayer alerts, historical edits and review, qada replacements and undo, progress, and Settings. Next, Back, and Skip tour are always available; the tour blocks taps on prayer records. Finishing or skipping saves the preference so the guide stays dismissed on subsequent launches. Its prayer-reminder step preselects notifications for new Android users, lets them choose a place, and requests Android permission only after Enable & continue. Skipping, turning the switch off, or declining permission keeps new users’ alerts off; replay respects an existing opt-out. An interrupted unfinished tour starts again next time.

Existing journals are not interrupted after updating. Use **Settings → App walkthrough** to replay the guide at any time. The guide follows light/dark appearance and reduced motion, and its instructions scroll when large text or a small screen needs more space. It introduces no new permissions or network services.

## Daily use

- **Today:** performed cards have green borders and softer text; confirmed misses use bold red styling. Past unrecorded cards use amber borders and an explicit needs-review label, excluding them from qada until confirmed. Each prayer shows its time, e.g. `Subuh (05:48)`. Tick it once its time has started; early taps explain when you can record it. Untick to leave it unrecorded, or use the menu to confirm a miss. All five checkboxes are shown immediately in the compact Today layout at normal text sizes. The date is in the app bar, with a slim completion indicator above the prayers. Pull down to refresh times.
- **Review:** use the prompt above History’s calendar to open previous unrecorded days; mark prayers individually or confirm all remaining prayers for a day.
- **History:** the red navigation badge counts past days with at least one unrecorded prayer, excluding today. Matching red calendar rings identify those days, and both update as records are corrected; the badge hides at zero. Select any past date (from 1900) and maintain its records. Days before first launch are optional: recording a prayer includes only that day, leaving untouched gaps outside review and totals. Earlier records remain saved when Today rolls over at local midnight or the app resumes.
- **Qada:** tap the info icon beside Outstanding qada for the balance formula. Enter optional old balances in Settings, record replacements by prayer and quantity, or undo entries. Replacements never tick today's obligatory prayers.
- **Progress:** full-width cards for weekly/monthly performed totals, fully completed days, replacements, and unrecorded prayer totals.
- **Settings:** saved place/device location is in **Prayer times & location**; add a home-screen widget, enable the daily check-in reminder, change appearance, or export/restore a versioned JSON backup using Android's document picker.

**Unticked does not mean missed.** Only confirmed misses add to qada. Balance = starting count + confirmed misses − replacements. Corrections cannot make balances negative; undo the conflicting replacement first. There is no “Not required” status.

## Daily check-in reminder (v1.1)

Enable **Settings → Daily check-in reminder** and allow Android notifications. On Android 12+, use **Allow alarms & reminders** for reliable timing. The reminder targets **11:00 PM in the phone's local timezone** and only appears when none of that day's five prayers is marked performed or missed. Qada replacements and settings changes do not count as daily prayer records. Notifications never add qada debt or change prayer statuses.

The Android alarm receiver reads the saved SQLite journal at delivery, so it works when Flutter is not running. Recording a prayer dismisses an already displayed reminder. A reminder is attempted at most once per calendar day; delayed reminders are suppressed after midnight. Reboot, app update, clock/timezone changes, permission changes, and app resume reschedule the check. Enabling after 11 PM schedules an immediate check if that day has not already been checked.

Reminders are off until enabled. Without alarm access, Android's inexact fallback may be delayed or skipped; it cannot guarantee 11 PM delivery. Force-stopping the app in Android settings suppresses alarms until you reopen it. Battery restrictions may also affect delivery. This is a local notification: no server, account, or network connection is used. The preference is included in backups; backups from v1.0 default to reminders off. A notification tap opens Today.

## Prayer times on Today (v1.5)

The first tab integrates the five daily records and their times; navigation now contains Today, History, Qada, and Progress. It uses the free [WaktuSolat API](https://api.waktusolat.app) without an API key. Coordinates resolve to a Malaysian prayer zone, then previous/current/next months are downloaded from its JAKIM timetable. The selected zone and `Asia/Kuala_Lumpur` timezone are visible on Today and in **Prayer times & location**. All 150 sample times for WLY01 in November 2026 matched the official e-Solat sample; zone lookup should still be checked near boundaries.

Tap the sliders button on Today’s location card. Select a place from the Malaysia dropdown or tap **Use device location**. Location is requested only on that action, at medium accuracy, rounded to three decimals. No background GPS or location history is collected. The saved point is reused for refreshes; tap the button again after travelling. Coordinates are sent to WaktuSolat and included in the plaintext journal backup along with the selected place and notification preference.

Use the first-launch walkthrough, **Settings → Prayer-time notifications**, or Today’s location card to open **Prayer times & location** and enable **Prayer-time notifications** and grant notifications plus **alarms & reminders** access for on-time alerts. These alerts use a separate Android channel from the 11 PM check-in; neither feature ticks prayers or adds qada. Notification taps open Today. Disabling is possible even while offline or when the API is unavailable.

Downloaded times are cached in SQLite and remain available offline. Android keeps only the next occurrence of each of the five prayers scheduled, then schedules successors after each alarm. WorkManager checks for refreshes every 12 hours when connected and downloads new months when fewer than 14 days remain. Refreshes use the last selected location, not a new GPS fix. Reboot, app updates, clock/timezone changes, and alarm-access grants reschedule alerts. Delayed broadcasts over 15 minutes old are discarded rather than replayed.

A network outage preserves an existing matching-place cache. Changing place immediately cancels the old place’s alarms; old responses cannot overwrite the new selection. Cached times for another place are never presented as the current result. When downloaded coverage runs out, alerts stop until a refresh succeeds; the app does not invent times. Android battery restrictions, denied permissions, or force-stop can delay/suppress delivery. Foreground refresh and background retry recover when access returns.

New **performed** marks for today are allowed only at or after the matching prayer's exact saved start instant. This applies to checkboxes, the prayer menu, today's History records, and the home-screen widget. An early tap shows a message and changes nothing. Past-day corrections, qada entries, existing performed records, and confirmed backup restores remain available. With no valid timetable for the selected place/date, the app asks you to refresh first. Saved times work offline, remain visible during refresh, and are never substituted from another place. Journal days use the phone's local calendar; matching timetable dates use the displayed zone and are compared as absolute instants. See [recording rules and previews](docs/prayer-recording.md).

The database migrates from schema 1 to 2 by adding a separate calendar cache table. Existing prayer records are retained. Older backups default to Kuala Lumpur with prayer-time alerts off. Calendar downloads are regenerable and excluded from backups; restoring a different place reschedules its alerts.

## Appearance (v1.3)

Use the sun/moon button beside Settings for a quick light/dark toggle, or **Settings → Dark mode**. The selection is saved across restarts and included in backups. **Appearance → Follow system** restores automatic switching with the phone's theme.

The redesigned screens use mint/emerald colors, rounded glass panels, bordered pill buttons, circular outlined controls, and bundled Nunito typography. High contrast uses solid surfaces and stronger borders; large text remains scrollable. Glass blur is limited to summary/navigation panels. See the [design reference and render comparison](docs/design/glass-ui.md).

## Home-screen widget (v1.6)

Use **Settings → Home-screen widget** to open your launcher's Add widget prompt. You can also touch and hold an empty part of the home screen, choose **Widgets → Qada Tracker → Today’s prayers**, and drag it into place. Open the app once first so your journal is initialized. The compact widget uses a 4 × 1 space with only the five prayer boxes. Resize an existing older widget to one row, or remove and re-add it once; launchers retain existing widget dimensions.

Five boxed buttons show Subuh, Zohor, Asar, Maghrib, and Isyak. Once its saved prayer time has started, tap a box to mark that prayer **performed for today**, even when the app is closed. An early tap or missing timetable shows a short message without changing the record. A check means performed, a circle means unrecorded, and an amber box with `!` means confirmed missed. Tap a performed prayer again to return it to unrecorded, even offline. Marking it performed again still checks its start time. Tap any padding or gap outside the prayer boxes to open Today. The header and progress/instruction footer are removed. All widget instances and the app share the same saved records and appearance preference.

The date follows the phone's local calendar. A midnight alarm, periodic launcher updates, app changes, and clock/timezone/reboot events refresh the display without changing old records. Android may delay background refresh; a stale-date tap refreshes the widget and asks you to tap again, never writing yesterday's prayer or guessing a miss. No new permissions are needed. A correction that would make a qada balance negative is refused until you undo the conflicting replacement in the app.

See [widget previews, implementation, and phone checks](docs/home-widget.md).

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

The universal debug APK is generated at `build/app/outputs/flutter-apk/app-debug.apk`. Smaller architecture-specific builds are also available as `app-arm64-v8a-debug.apk`, `app-armeabi-v7a-debug.apk`, and `app-x86_64-debug.apk` in the same directory. Use the universal build if unsure. It is for personal installation, not store publication. Uninstalling the app deletes local records: export a backup first. The main manifest now includes Internet access for prayer-time downloads and foreground location permissions for the optional location button. No background location permission is declared. Platform automatic cloud backup is disabled; backups are explicitly user initiated.

## Storage and backups

`lib/model.dart` owns calendar-date records, confirmation rules, starting balances, and the qada ledger. `lib/controller.dart` serializes mutations and publishes state only after disk writes succeed. `lib/database.dart` stores a versioned journal document in a single-row SQLite table, committed atomically. App mutations read the latest document and use compare-and-swap updates with conflict retries against both the journal and timetable, so a native widget tap cannot be overwritten by a stale UI snapshot and a concurrent timetable refresh is revalidated. The schema needs no code generation. Schema 2 adds the regenerable prayer calendar cache; a background Android worker can refresh it transactionally after checking the selected source is still current.

Backups include every record, setting, starting balance, and replacement entry. Imports validate dates, enums, counts, unique replacement IDs, version, and resulting balances before asking for confirmation. Restore replaces rather than merges data; SQLite commits it atomically. Cancelling either picker or confirmation preserves current data. Backup files are plain text, not encrypted; keep them private. The picker accepts files up to 10 MB (the plugin loads selected bytes into memory before validation).

Tracking begins on first launch. Manually recorded older days join the journal individually; confirmed misses count toward qada and remaining unrecorded prayers appear in review. Clearing the last confirmed prayer removes an optional older day from totals again, subject to the usual qada conflict checks. The original start date stays unchanged, and untouched earlier days do not create obligations. Elapsed days are derived from calendar dates, so missed app launches do not require a background process. Old unticked prayers never silently become debt. A local midnight timer and resume observer refresh Today. Both optional notification features use notification/alarm access. The location button on Today’s prayer-time settings requests foreground location access only.

## Tests and current validation status

Tests cover the qada ledger and corrections, unrecorded gaps, backup validation and round trips, SQLite persistence and write-failure rollback, rapid serialized mutations, restore cancellation and confirmation, midnight/resume, and the main review-to-replacement UI flow. Reminder tests cover permission/opt-in settings, backup compatibility, the platform bridge, duplicate and late suppression, timezone changes, and daylight-saving transitions.

Verified in the cloud instance:

- Pinned Flutter/Dart and JDK setup, with checksum verification and TLS trust intact.
- Frozen dependency resolution with `pubspec.lock`, and repeatable `scripts/setup.sh` execution.
- `scripts/validate.sh`: formatting checks, static analysis with **no issues**, **94 passing Flutter tests and 29 passing Android tests**, and a successful Android debug APK build.

Prayer-time validation tests cover before/exactly-at/after start, checkboxes and menus, source/date mismatches, absent or malformed caches, atomic bulk changes, concurrent calendar refresh, notification routing, and historical/restore behavior.

Widget tests cover native RemoteViews, actual pending-intent clicks, SQLite writes, app/launcher synchronization, duplicate taps, date rollover, qada conflicts, write rollback, and launcher fallback instructions. Native widget tests use pinned Robolectric **4.16.1** on Android API **35**, with native graphics/SQLite; the test runtime is downloaded from Maven Central on first use.

Theme tests also check persistent toggling, system-theme behavior, both themes across all tabs, and a narrow-screen/high-contrast/large-text layout. To regenerate ignored Flutter raster captures, run `QADA_CAPTURE_UI=1 flutter test test/theme_ui_test.dart`. Use `QADA_CAPTURE_UI=1 flutter test test/notification_onboarding_test.dart test/prayer_card_status_test.dart` for the consent and status-card previews.

The original Flutter download restriction has been resolved. The debug APK is available at the path above. Android runtime validation uses a separate disposable software emulator; see [VALIDATION.md](VALIDATION.md) for its result and limitations. No real phone has been tested. Chrome and Linux desktop doctor warnings are outside this Android app’s target.
