# Qada Tracker — user and development guide

A personal Android prayer journal built with Flutter, Riverpod, and SQLite through Drift. English/Malay interface; Malay prayer names. Prayer records stay on the phone unless you export them. Today loads JAKIM prayer times from the free WaktuSolat API using the saved place coordinates (Kuala Lumpur by default).

## Downloads and versions

[Browse Android releases](https://github.com/zulhisyamsofi/qada-tracker/releases/latest). APK availability varies by release; v1.35.0 used a temporary download that expires. Source and build instructions remain available. These are personal-installation builds, not Play Store releases. See [RELEASES.md](RELEASES.md) and [CHANGELOG.md](CHANGELOG.md).

## Smaller installation downloads

From v1.12.0, GitHub downloads use optimized **release-mode** APKs with Dart AOT compilation, tree shaking, R8 code shrinking, resource shrinking, and icon tree shaking. No app features are removed. Choose the **arm64-v8a APK** for a Realme GT Master or most recent Android phones; the unsuffixed APK is a universal fallback containing all three supported processor types. Other downloads target older 32-bit ARM phones and x86-64 emulators. Keep the same APK variant for subsequent updates. Install one APK over the existing app to preserve the journal; the application ID and signing certificate remain the same.

Reproduce all four optimized APKs and their checksums with `./scripts/build-release.sh`; output is under `build/releases/v<version>/`. The ordinary `scripts/validate.sh` still builds a debug APK for development checks. **Do not use the debug APK for distribution.** Release mode does not expose debug tools; it retains the existing personal-use signing key for update compatibility. Dart obfuscation is unnecessary for this size reduction.

## First launch walkthrough

New installations open a seven-step guided tour that highlights real controls and visits all four tabs. It explains recording/clearing prayers, confirming misses, place selection and prayer alerts, historical edits and review, qada replacements and undo, progress, and Settings. Next, Back, and Skip tour are always available; the tour blocks taps on prayer records. Finishing or skipping saves the preference so the guide stays dismissed on subsequent launches. Its prayer-reminder step preselects notifications for new Android users, lets them choose a place, and requests Android permission only after Enable & continue. Skipping, turning the switch off, or declining permission keeps new users’ alerts off; replay respects an existing opt-out. An interrupted unfinished tour starts again next time.

Existing journals are not interrupted after updating. Use **Settings → App walkthrough** to replay the guide at any time. The centered guide has roomier spacing and follows light/dark appearance and reduced motion, and its instructions scroll when large text or a small screen needs more space. Scrollable text and setup controls reserve a separate gutter beside the scrollbar. It introduces no new permissions or network services.

## Language

Choose **Settings → Language / Bahasa → English / Bahasa Melayu**. The interface, walkthrough, date/time pickers, dates, new prayer/check-in notification text, and widget feedback follow the saved language. The preference is included in backups and defaults to English for older journals. Android permission and document-picker screens follow the phone’s system language. Menstrual dates are entered and confirmed manually; there is no cycle prediction.

## Daily use

Navigation contains **Today · Qada · History · Settings**. Progress is part of Qada; Settings is a full navigation destination.

- **Today:** times use 12-hour AM/PM format, such as `Subuh (5:48 AM)`. Each prayer has a green **Done** button and a red **Missed** button. Done records an unrecorded prayer as Performed. Missed saves immediately, without confirmation. Tap the selected button again to return to Unrecorded. Done on a confirmed miss records one dated qada replacement and displays **Qada completed**, keeping the original miss. Clearing that selected Done removes its linked replacement and the miss together; choosing Missed reopens the miss. Card borders and status text retain their green, red, and amber styling. Today’s new Done and Missed marks require the prayer time to have started. Early taps explain the start time and leave the record and qada balance unchanged. Existing marks can still be cleared. Compact prayer rows place Done/Missed to the right of the prayer/time labels with 48-pixel touch targets. Normal phone layouts show all five prayers immediately; enlarged text can scroll.
- **History:** select an earlier calendar date to use the same Done/Missed controls; choosing today opens Today. Each past date’s red badge counts confirmed misses without a dated qada completion. The navigation badge adds these **missed-prayer counts**. Unrecorded prayers, completed qada, performed prayers, and exemptions are excluded. Calendar checkmarks mean all five prayers are performed or have linked qada completions. Missed-prayer lists, review prompts, and bulk-review buttons are removed from History. Untouched dates before tracking began do not create obligations; explicitly backfilled dates join the calendar counts.
- **Qada:** five prayer balances sit beneath Outstanding qada. Tap a boxed number to see that prayer’s missed dates, newest first. **Open date** selects the exact date and month in History (or opens Today for a current-day miss). Open date scrolls directly to the selected prayer, highlights its card, and focuses Done. Record Done after completing its qada. Qada also contains replacement history and weekly/monthly Progress, retaining full-width metrics for performed prayers, replacements, completed days, and unrecorded prayers. Unrecorded prayers need attention but never add qada debt.
- **Settings:** consistently styled icon rows are grouped into Preferences, Prayer & tracking, Notifications, Backups, and Tools & help. Language and dark mode share Preferences. Location and menstrual-period/pausing controls share Prayer & tracking. Both reminder switches and their access controls remain together. Export/restore, the home-screen widget, and the walkthrough remain available.
- **Earlier data:** older starting balances and undated replacements are preserved. Older balances stay read-only. When an eligible earlier replacement exists, Done on a missed prayer offers **Use existing replacement**, associating one unit without another deduction. The app never guesses which dates were settled. Pending calendar counts can therefore include older misses until existing replacements are explicitly linked.

**Unrecorded does not mean missed.** Only confirmed misses add to qada. Balance = starting count + confirmed misses − replacements. Corrections cannot make balances negative; undo the conflicting replacement first. An explicitly confirmed **exempt** prayer has no qada obligation and does not need review; an ordinary unrecorded prayer still needs your confirmation.

## Exempt prayers and tracking pauses

Individual **Mark exempt** actions are removed from prayer menus. Manage menstrual period dates and pauses in Settings. Existing individual exemptions are preserved; their menu still permits explicitly marking them required (unrecorded), performed, or missed. Corrections continue to respect the nonnegative qada-balance rule.

In **Settings → Menstrual period & tracking pause**, select a date range and confirm it, or pause from a selected prayer today until you resume. Range/pause changes affect unrecorded prayers only: existing performed and missed confirmations are preserved. Future dates are represented by the interval, without creating daily records. Resume requires selecting the first required prayer today, or Tomorrow, so earlier prayers remain exempt. Removing a period asks for confirmation and can bring its unresolved prayers back into review; individually confirmed records remain saved.

Exempt prayers do not inflate the History badge, unrecorded counts, or required-prayer totals. Fully exempt dates have neutral calendar shading. **Silence prayer alerts for exempt prayers** defaults on, so an ongoing pause silences prayer-time alerts; daily check-ins always ignore exempt prayers and stay silent when no required prayers need recording. Existing reminder preferences are retained for resume. No reason, health information, or automatic exemption inference is collected.

## Daily check-in reminder

Enable **Settings → Notifications → Daily check-in reminder** and allow Android notifications. On Android 12+, use **Allow alarms & reminders** for reliable timing. Choose **Daily check-in time** in the same Settings group; it defaults to **11:00 PM in the phone's local timezone**. The reminder only appears when at least one required prayer that day is still unrecorded. Choose a time after your last prayer for an end-of-day check-in. Qada replacements and settings changes do not count as daily prayer records. Notifications never add qada debt or change prayer statuses.

The Android alarm receiver reads the saved SQLite journal at delivery, so it works when Flutter is not running. Resolving all required prayers (performed, missed, or explicitly exempt) dismisses an already displayed reminder; a partial check-in leaves it visible. A reminder is attempted at most once per calendar day; delayed reminders are suppressed after midnight. Reboot, app update, clock/timezone changes, permission changes, and app resume reschedule the check. Enabling after the selected time schedules an immediate check if that day has not already been checked.

Reminders are off until enabled. Without alarm access, Android's inexact fallback may be delayed or skipped; it cannot guarantee delivery at the selected time. Force-stopping the app in Android settings suppresses alarms until you reopen it. Battery restrictions may also affect delivery. This is a local notification: no server, account, or network connection is used. The preference is included in backups; backups from v1.0 default to reminders off. A notification tap opens Today.

## Prayer times on Today (v1.5)

The first tab integrates the five daily records and their AM/PM times; navigation contains Today, Qada, History, and Settings. It uses the free [WaktuSolat API](https://api.waktusolat.app) without an API key. Coordinates resolve to a Malaysian prayer zone, then previous/current/next months are downloaded from its JAKIM timetable. The selected place, resolved zone, and `Asia/Kuala_Lumpur` timetable timezone are visible in **Settings → Prayer times & location**. Today retains the five parenthesized prayer times. All 150 sample times for WLY01 in November 2026 matched the official e-Solat sample; zone lookup should still be checked near boundaries.

Open **Settings → Prayer times & location**. Select a place from the Malaysia dropdown or tap **Use device location**. Location is requested only on that action, at medium accuracy, rounded to three decimals. No background GPS or location history is collected. The saved point is reused for refreshes; tap the button again after travelling. Coordinates are sent to WaktuSolat and included in the plaintext journal backup along with the selected place and notification preference.

For on-time alerts, enable **Prayer-time notifications** during the walkthrough or in **Settings → Notifications**, then grant Android notifications and **alarms & reminders** access. Select the individual prayers under **Notify me for**; all five are selected by default, and selections are kept when the master switch is off. These alerts use a separate Android channel from the daily check-in; neither feature ticks prayers or adds qada. Notification taps open Today. Disabling is possible even while offline or when the API is unavailable.

Both reminder preferences are grouped in **Settings → Notifications**. Android permission does not enable either in-app switch. Only essential Android notification/alarm permission links appear when an enabled reminder needs access. Testing, rescheduling, and diagnostics controls are removed. The prayer-time location page contains only place, timetable, source, and refresh controls. Existing opt-outs are preserved.

Downloaded times are cached in SQLite and remain available offline. Android keeps only the next eligible occurrence of each selected prayer scheduled, skipping exempt slots when their alerts are silenced, then schedules successors after each alarm. WorkManager checks for refreshes every 12 hours when connected and downloads new months when fewer than 14 days remain. Refreshes use the last selected location, not a new GPS fix. Reboot, app updates, clock/timezone changes, and alarm-access grants reschedule alerts. Delayed broadcasts over 15 minutes old are discarded rather than replayed.

A network outage preserves an existing matching-place cache. Changing place immediately cancels the old place’s alarms; old responses cannot overwrite the new selection. Cached times for another place are never presented as the current result. When downloaded coverage runs out, alerts stop until a refresh succeeds; the app does not invent times. Android battery restrictions, denied permissions, or force-stop can delay/suppress delivery. Foreground refresh and background retry recover when access returns.

New **performed or missed** marks for today are allowed only at or after the matching prayer's exact saved start instant. This covers Today’s Done/Missed buttons, dated qada completions and reopened misses for today, and app mutations. The home-screen widget applies the same start-time restriction to its performed marks. An early tap shows a message and changes nothing. Past-day corrections, qada completions for earlier dates, existing performed records, and confirmed backup restores remain available. With no valid timetable for the selected place/date, the app asks you to refresh first. Saved times work offline, stay in place when prayers are marked, remain visible during refresh, and are never substituted from another place. Journal days use the phone's local calendar; matching timetable dates use the displayed zone and are compared as absolute instants. See [recording rules and previews](docs/prayer-recording.md).

The database migrates from schema 1 to 2 by adding a separate calendar cache table. Existing prayer records are retained. Older backups default to Kuala Lumpur with prayer-time alerts off. Calendar downloads are regenerable and excluded from backups; restoring a different place reschedules its alerts.

## Appearance (v1.3)

Use the sun/moon button beside Settings for a quick light/dark toggle, or **Settings → Dark mode**. The selection is saved across restarts and included in backups. The redundant Appearance dropdown is removed. Existing system-following preferences remain supported until you manually choose light or dark; backups retain all existing theme values.

The redesigned screens use mint/emerald colors, rounded glass panels, bordered pill buttons, circular outlined controls, and bundled Nunito typography. High contrast uses solid surfaces and stronger borders; large text remains scrollable. Glass blur is limited to summary/navigation panels. See the [design reference and render comparison](docs/design/glass-ui.md).

## Home-screen widget (v1.6)

Use **Settings → Home-screen widget** to open your launcher's Add widget prompt. You can also touch and hold an empty part of the home screen, choose **Widgets → Qada Tracker → Today’s prayers**, and drag it into place. Open the app once first so your journal is initialized. The widget targets 4 × 1 cells, with a compact title above five padded prayer boxes. The titled widget needs about 80 dp of content height. Existing placements may need a small vertical resize or re-adding; launchers retain dimensions and determine grid placement.

Five boxed buttons show Subuh, Zohor, Asar, Maghrib, and Isyak. Once its saved prayer time has started, tap a box to mark that prayer **performed for today**, even when the app is closed. An early tap or missing timetable shows a short message without changing the record. A check means performed, a circle means unrecorded, and an amber box with `!` means confirmed missed. A muted dash means exempt and opens Today instead of changing the record; stale widget actions also recheck exemptions under the database write lock. Tap a performed prayer again to return it to unrecorded, even offline. Marking it performed again still checks its start time. Tap any padding or gap outside the prayer boxes to open Today. A compact Qada Tracker title sits above the padded boxes. Tap the title to open Today; the performed-count/instruction footer stays removed. All widget instances and the app share the same saved records and appearance preference.

The date follows the phone's local calendar. A midnight alarm, periodic launcher updates, app changes, and clock/timezone/reboot events refresh the display without changing old records. Android may delay background refresh; a stale-date tap refreshes the widget and asks you to tap again, never writing yesterday's prayer or guessing a miss. No new permissions are needed. A correction that would make a qada balance negative is refused until you undo the conflicting replacement in the app.

See [widget previews, implementation, and phone checks](docs/home-widget.md).

## Development

The setup scripts support Linux x86-64. For other hosts, install the pinned Flutter SDK and matching Android toolchain manually.

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

The development-only universal debug APK is generated at `build/app/outputs/flutter-apk/app-debug.apk`. Smaller architecture-specific builds are also available as `app-arm64-v8a-debug.apk`, `app-armeabi-v7a-debug.apk`, and `app-x86_64-debug.apk` in the same directory. Use the universal build if unsure. It is for personal installation, not store publication. Uninstalling the app deletes local records: export a backup first. The main manifest now includes Internet access for prayer-time downloads and foreground location permissions for the optional location button. No background location permission is declared. Platform automatic cloud backup is disabled; backups are explicitly user initiated.

## Storage and backups

`lib/model.dart` owns calendar-date records, confirmation rules, starting balances, and the qada ledger. `lib/controller.dart` serializes mutations and publishes state only after disk writes succeed. `lib/database.dart` stores a versioned journal document in a single-row SQLite table, committed atomically. App mutations read the latest document and use compare-and-swap updates with conflict retries against both the journal and timetable, so a native widget tap cannot be overwritten by a stale UI snapshot and a concurrent timetable refresh is revalidated. The schema needs no code generation. Schema 2 adds the regenerable prayer calendar cache; a background Android worker can refresh it transactionally after checking the selected source is still current.

Backups include every record, setting, starting balance, replacement entry, and exempt period. The journal/backup format is now **version 3**, including exemptions and reminder configuration. Version 1 and 2 backups still restore with safe defaults (11 PM, all five prayer alerts selected, exemption alert muting on); existing master opt-ins are preserved. Earlier app versions cannot read a version 3 journal or backup. Dated replacements contain a `missedDate`, require quantity one, must reference a confirmed miss, cannot predate it, and are unique per date/prayer. Keep a pre-update backup if you need to downgrade. The SQLite schema remains version 2 and the separate regenerable calendar cache remains format version 1. Imports validate dates, enums, counts, unique replacement IDs, version, and resulting balances before asking for confirmation. Restore replaces rather than merges data; SQLite commits it atomically. Cancelling either picker or confirmation preserves current data. Backup files are plain text, not encrypted; keep them private. The picker accepts files up to 10 MB (the plugin loads selected bytes into memory before validation).

Tracking begins on first launch. Manually recorded older days join the journal individually; confirmed misses count toward qada and remaining unrecorded prayers appear in review. Clearing the last confirmed prayer removes an optional older day from totals again, subject to the usual qada conflict checks. The original start date stays unchanged, and untouched earlier days do not create obligations. Elapsed days are derived from calendar dates, so missed app launches do not require a background process. Old unticked prayers never silently become debt. A local midnight timer and resume observer refresh Today. Both optional notification features use notification/alarm access. The location button in Settings → Prayer times & location requests foreground location access only.

## Tests and current validation status

Tests cover configurable times and selective alerts, exact-entry quick-qada Undo, exempt intervals and partial-day resume, preserved confirmations, required-only progress, current version 3 backups with legacy version 1/2 restore support, and the qada ledger and corrections, unrecorded gaps, backup validation and round trips, SQLite persistence and write-failure rollback, rapid serialized mutations, restore cancellation and confirmation, midnight/resume, and the main review-to-replacement UI flow. Reminder tests cover permission/opt-in settings, backup compatibility, the platform bridge, duplicate and late suppression, timezone changes, and daylight-saving transitions.

Verified in the cloud instance:

- Pinned Flutter/Dart and JDK setup, with checksum verification and TLS trust intact.
- Frozen dependency resolution with `pubspec.lock`, and repeatable `scripts/setup.sh` execution.
- Formatting checks, static analysis with **no issues**, **155 passing Flutter tests**, and a successful Android debug APK build. `scripts/validate.sh` runs these checks plus Android JVM tests.
- **63 Android JVM tests** passed for v1.35.0; optimized universal and per-architecture release APKs also built successfully.

Today stability tests hold timetable reads pending while tapping Done on all five prayers at normal and narrow phone widths, checking every animation frame for stable card positions and scroll offsets. Provider tests verify ordinary prayer saves and notification preferences do not reload the timetable, while real place changes still do.

Prayer-time validation tests cover before/exactly-at/after start, Done buttons, source/date mismatches, absent or malformed caches, atomic bulk changes, concurrent calendar refresh, notification routing, and historical/restore behavior.

Widget tests cover native RemoteViews, actual pending-intent clicks, SQLite writes, app/launcher synchronization, duplicate taps, date rollover, qada conflicts, write rollback, and launcher fallback instructions. Native widget tests use pinned Robolectric **4.16.1** on Android API **35**, with native graphics/SQLite. Notification integration tests run on API **33 and 35**, covering channel permissions, exact/inexact alarms, real pending-intent payloads, successor scheduling, stale/duplicate suppression, repair, opt-out, independent channels, and partially recorded daily check-ins. Test runtimes download from Maven Central on first use.

Run `QADA_CAPTURE_UI=1 flutter test test/navigation_actions_test.dart test/history_review_indicators_test.dart` for the new buttons, qada date links, grouped Settings, and calendar counters. Theme tests also check persistent toggling, system-theme behavior, both themes across all tabs, and a narrow-screen/high-contrast/large-text layout. To regenerate ignored Flutter raster captures, run `QADA_CAPTURE_UI=1 flutter test test/theme_ui_test.dart`. Use `QADA_CAPTURE_UI=1 flutter test test/notification_onboarding_test.dart test/prayer_card_status_test.dart` for the consent and status-card previews. `QADA_CAPTURE_UI=1 flutter test test/history_review_indicators_test.dart` captures the History badge and marked calendar. `QADA_CAPTURE_UI=1 flutter test test/history_navigation_test.dart` captures yesterday’s default view and the first-day helper. `QADA_CAPTURE_UI=1 flutter test test/today_layout_test.dart` captures the restored Today layout and saved-location Settings entry. `QADA_CAPTURE_UI=1 flutter test test/routine_ui_test.dart` captures reminder configuration, dated qada, and exemption management.

The original Flutter download restriction has been resolved. The debug APK is available at the path above. Android runtime validation uses a separate disposable software emulator; see [VALIDATION.md](VALIDATION.md) for its result and limitations. No real phone has been tested. Chrome and Linux desktop doctor warnings are outside this Android app’s target.
