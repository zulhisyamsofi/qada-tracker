# Validation record — v1.7.0+8

## Automated checks

The final `scripts/validate.sh` completed successfully:

- Formatting: 30 Dart files, 0 changes.
- Flutter static analysis: no issues found.
- Flutter tests: **62 passed, 0 failed**. Includes the previous daily tracking, qada, history, backup, and check-in tests, plus API parsing, official-source comparison, timezone/epoch handling, malformed API rejection, schema migration, backup defaults, stale-place response rejection, offline fallback, cache reuse, place switching, location denial, and offline/permission-denied notification controls.
- Android JVM tests: **29 passed, 0 failures/errors/skips** (7 check-in tests, 5 prayer-time tests, and 17 native widget tests). Verified their current JUnit XML result files. Policy cases cover UNIX seconds conversion, exactly one upcoming occurrence per prayer, no replay of past events, and early/late broadcast suppression.
- Universal and per-architecture Android debug APK builds succeeded.

The tests do not verify real AlarmManager delivery, location hardware, WorkManager execution, Doze, reboot broadcasts, or OEM battery management.

## Cards and historical maintenance — v1.7

Three new domain tests cover historical performed/missed records before first launch, exclusion of untouched gaps, optional-day review membership, clearing optional days, qada correction conflicts, and backup round trips. Three new widget tests measure full content width for all six weekly/monthly Progress cards, open the adjacent qada formula tooltip, and edit a pre-start calendar date through the real checkbox/missed-confirmation controls. The latter test closes and reopens file-backed SQLite, remounts the app, verifies persisted statuses and review membership, and confirms the unchanged start date with no intervening records created.

Light/dark Flutter raster captures were inspected for the full-width Progress cards, tappable formula tooltip, and selected pre-start History date. The existing narrow-screen case now also checks Qada and Progress at 320 × 720 with 1.6× text and high contrast. All 62 Flutter tests and the 29 Android tests passed, with universal and per-architecture debug APK builds. No connected Android device was available for phone validation.

The calendar now allows dates from 1 January 1900 through today. The actual first-launch start date is preserved. An explicitly confirmed older day joins review/progress; untouched older days and gaps remain excluded. Clearing its last confirmed prayer removes that optional day again, unless a qada conflict requires undoing a replacement first. The database schema and backup structure/version are unchanged; backup date validation now accepts these older records. No production dependency, permission, or API changed.

## Compact widget — v1.6

The widget now requests four columns by one row, with a 280 × 56 dp minimum. Its single horizontal row uses 4 dp root padding and five boxed toggles, with no header/date or progress/instruction footer. Background padding and inter-box gaps open Today; prayer-box taps toggle performed/unrecorded.

Four new native cases cover offline/early/wrong-place clearing followed by revalidation on the next performed mark; rollback of failed clearing; real touch gestures on padding, gaps, and boxes in an attached Android test window; and minimum-size rendering with 1.6× system text. Existing tests now check repeated toggles, missed-to-performed-to-unrecorded ledger preservation, two-widget updates in both directions, and stale-date protection when the old view was performed. The Flutter reload test also confirms the app counter decreases after a native clear.

Native previews in both themes were inspected at 360 × 64 and at a minimum 280 × 56. Names remain untruncated and prayer touch targets remain at least 48 × 48 dp. Existing placed widgets retain launcher dimensions: resize them to one row or remove and re-add the widget once. Actual 4 × 1 placement remains to be checked on the user's launcher.

## Integrated times and start validation

The eight new Flutter tests cover exact start-time boundaries, missing/wrong-place/wrong-date caches, historical edits and preserved confirmations, phone-date versus timetable-date selection, atomic queued changes, concurrent calendar replacement, actual checkbox/menu restrictions, and notification routing to Today. The existing offline-refresh test also confirms matching times remain available while refreshing. Existing tests now use deterministic timetable fixtures on Today instead of live network requests.

Two new native widget tests verify rejection immediately before start with acceptance exactly at start, plus absent, wrong-source, wrong-date, and malformed cache rejection. All earlier persistence, qada, widget, backup, reminder, API, and theme checks remain passing.

Updated Flutter raster captures were inspected in light/dark at 390 × 844, including the prayer-time settings sheet; 320 × 720 high-contrast/large-text coverage remains. Current previews and detailed recording rules are in [docs/prayer-recording.md](docs/prayer-recording.md). No database schema, backup version, permission, production dependency, or API source changed.

## Home-screen widget

Six Flutter tests cover native-change events, resume reload, stale UI rebasing, compare-and-swap collision retries, write failures, launcher refresh, pinning fallback, and export of native marks before their UI event arrives. Existing prayer/history/qada/backup tests pass with disk-based mutations.

Seventeen Robolectric tests exercise native SQLite and actual Android RemoteViews: all five prayers, repeated toggles, unchanged past records/settings/ledger, valid and conflicting miss corrections, missing/unsupported journals, invalid input, atomic rollback, stale dates, multi-day gaps, local midnight/DST, all-instance updates and restore, distinct PendingIntents, and rendering in both themes at 360 × 64 and 280 × 56 dp. A real PendingIntent click through the provider saves a prayer, updates two widget instances, sends the Flutter change event, and cancels a displayed check-in notification.

The test runtime is pinned to Robolectric 4.16.1, Android API 35, native graphics and native SQLite. The native-rendered light/dark previews and architecture/phone checklist are in [docs/home-widget.md](docs/home-widget.md). The minimum-size render was inspected and repaired so Maghrib's full name fits. Widget work introduces no database schema, backup version, production dependency, permission, or network API change.

This is simulated Android validation. Actual launcher placement/pinning, drag/resize behavior, process eviction, reboot/Doze delivery, and OEM battery restrictions remain unverified on a phone.

## Appearance and visual checks

Four appearance widget tests verify header and Settings theme toggles, SQLite persistence across app remount, Follow system mode, all four tabs and Settings in light/dark, and a 320 × 720 layout with 1.6× text, high contrast, and reduced motion. The entire existing prayer, qada, backup, reminder, and API suite also passes.

Actual Flutter raster captures at 390 × 844 were compared against the generated design reference, with separate narrow-screen captures. Repairs included font weight, shadow strength, body contrast, sheet opacity, selected navigation capsules, and full tab labels. Browser tools are unavailable; native Flutter rendering was used rather than a web imitation. This verifies widget rendering and interaction, not phone GPU performance or OS integration. See [the design ledger](docs/design/glass-ui.md) for the reference, comparisons, and capture command.

Nunito's four static weight assets and OFL license are bundled locally; no network font service is used. The existing saved theme setting is reused, requiring no schema or backup format change.

## API evidence

Live HTTPS probes of the free WaktuSolat v2 API returned HTTP 200 for GPS-to-zone lookup and explicit previous/current/next months. No API key was required. Coordinates for Kuala Lumpur resolved to WLY01.

All **150 times** in the WLY01 November 2026 sample matched the official e-Solat monthly response. Those public responses are stored under `test/fixtures` for an offline regression test. This verifies that sample, not every zone or future API response.

An initial Aladhan method-17 sample differed from e-Solat, so the implementation uses WaktuSolat's JAKIM zone timetable instead. Today shows the resolved zone; approximate GPS near a boundary should be checked against the user's locality.

## Data and background scheduling

Schema 1 → 2 migration adds the calendar cache table without replacing the journal. Selected place and alert settings are included in backups; old backups default to Kuala Lumpur with prayer alerts off. The downloadable calendar cache is excluded from backups and may be regenerated.

A selected-place key guards foreground/background cache writes. Alarms recheck the current source, downloaded event, timing window, permission, and duplicate token before posting. Only the next occurrence of each prayer is pending; successors are scheduled from the cache. A connected WorkManager task checks every 12 hours and refreshes when less than 14 days remain. A place change replaces an old pending refresh.

Device location is requested only from the location button, at medium accuracy, rounded to three decimals. Background refresh uses the saved point and does not request GPS. An attempted precision increase was rejected by automatic approval review; that change was not applied.

## APK compatibility

- Package: `com.personal.qada_tracker`; version **1.7.0** (code **8**); minimum API 24; target API 36.
- Universal APK: `build/app/outputs/flutter-apk/app-debug.apk`.
- SHA-256: `6665f4b98a13f43d96a08a816ae4ec04d589d1afb22abff4594ebc17f5d41db7`.
- Signing certificate matches the previous debug APKs, allowing an in-place update that retains the private journal.
- Smaller ARM64, ARM32, and x86-64 variants are in the same output directory.

Toolchain: Flutter 3.38.5 / Dart 3.10.4; Temurin JDK 17.0.17+10; Gradle 8.14; AGP 8.11.1; Kotlin 2.2.20; WorkManager 2.10.1. Downloads retain checksum and TLS verification.

## Native runtime limitation

No connected Android device was available, and `/dev/kvm` is absent. The earlier software emulator encountered System UI ANRs and never verified journal rendering. **Physical GPS, notification delivery, background refresh, notification taps, and launcher widget placement/background lifecycle remain unverified on a phone.**

On a phone: install as an update; open Today’s prayer-time settings; select a place or request device location; check the resolved zone; enable Prayer-time notifications; grant notifications and alarms access. Verify a real upcoming prayer alert with the app closed, then disable alerts and confirm cancellation. Also check place changes, reboot, permissions revocation, and offline use within the downloaded coverage. Preserve real prayer records when testing.

The feature editions are published through annotated Git tags and private GitHub releases; see [RELEASES.md](RELEASES.md). No Android store or environment publication is part of this release.

The private v1.6.0 release contains the checked APK and SHA256SUMS. App source and release tooling changes are recorded under the v1.6.0 feature tag.
