# Validation record — v1.26.0

Aligns navigation destination corners with the surrounding rounded bar and its inset. Keeps all existing navigation and prayer behavior.

Downloads:
- **Realme GT Master / most current Android phones:** `qada-tracker-v1.26.0-arm64-v8a.apk` (21.6 MB).
- **Universal fallback:** `qada-tracker-v1.26.0.apk` (61.0 MB).
- Other assets target 32-bit ARM phones and x86-64 emulators. Choose one APK and keep the same processor variant for later updates. The app ID and signing certificate match previous releases, preserving the journal on an in-place update.

Validation: formatting, static analysis, **125 Flutter tests**, **60 Android JVM tests**, debug compilation, and optimized universal/per-architecture release builds passed. All four APKs have verified signatures, correct versions/architectures, and no debug flag or debug Dart kernel. `SHA256SUMS` covers all downloads. Physical launcher placement, notification timing, and OEM background behavior remain unverified; no Android device is connected. No database schema, journal/backup version, qada calculation, permission, or API change is introduced. Existing journal/backup version 2 remains supported.

Signing certificate SHA-256: `ccb3ba84ae54baeaa960c1f87f1f7a7f88c5a9604c49945dd3be8f734422d837`. R8 retains the persisted WorkManager entry-point name. Earlier records and checksums below describe their own checkpoints.

- `qada-tracker-v1.26.0-arm64-v8a.apk` (21,550,758 bytes): `abdc6859191c053118d333197a4ff8fe42926f0f4278416d32051b5aab12c700`.
- `qada-tracker-v1.26.0-armeabi-v7a.apk` (19,177,246 bytes): `92f4dd56faa9bad2048ddce3f5c3054c05ce4691c87cb67e8866d3f46dc94546`.
- `qada-tracker-v1.26.0-x86_64.apk` (23,030,286 bytes): `d332fb70bd58828c2bd0ce1e88e310308a7ab39cd3e9ccff232008cb41cecfba`.
- `qada-tracker-v1.26.0.apk` (61,041,746 bytes): `f6d1d845efd8a866e19744da01993a6e6b253181023926fa26476584b398e6ee`.

---

# Validation record — v1.25.0

Publication completed: v1.25.0 has a separate fix commit, annotated tag, and private GitHub release marked latest. [The upload workflow](https://github.com/zulhisyamsofi/qada-tracker/actions/runs/43785210046) passed. All four APK digests/sizes and the checksum file were independently verified before publication; the temporary private transfer branch was deleted. The ARM64 download is **21,550,758 bytes (21.6 MB)** and retains the existing app ID and signing certificate.

Reserves a dedicated gutter between the walkthrough scrollbar and its title, description, hints, and notification-setup controls. Text wraps within the content area while the scrollbar stays separate. Keeps the existing tour navigation and checks clearance across all steps, enlarged text, both themes, and rotation.

Downloads:
- **Realme GT Master / most current Android phones:** `qada-tracker-v1.25.0-arm64-v8a.apk` (21.6 MB).
- **Universal fallback:** `qada-tracker-v1.25.0.apk` (61.0 MB).
- Other assets target 32-bit ARM phones and x86-64 emulators. Choose one APK and keep the same processor variant for later updates. The app ID and signing certificate match previous releases, preserving the journal on an in-place update.

Validation: formatting, static analysis, **125 Flutter tests**, **60 Android JVM tests**, debug compilation, and optimized universal/per-architecture release builds passed. All four APKs have verified signatures, correct versions/architectures, and no debug flag or debug Dart kernel. `SHA256SUMS` covers all downloads. Physical launcher placement, notification timing, and OEM background behavior remain unverified; no Android device is connected. No database schema, backup format, prayer status, qada calculation, permission, dependency, or API change is introduced. Journal/backup version 2, SQLite schema 2, and calendar-cache format 1 remain unchanged.

Walkthrough content now reserves 20 dp at the trailing edge beside a 6 dp scrollbar. Existing tour tests measure text clearance from the scrollbar corridor across all steps, normal and enlarged text, both themes, and landscape rotation. The focused walkthrough/notification-consent run passed 16 tests; normal and narrow rendered previews were inspected. Buttons remain outside the scrolling content. No physical Android device is connected; no new emulator validation was performed.

Signing certificate SHA-256: `ccb3ba84ae54baeaa960c1f87f1f7a7f88c5a9604c49945dd3be8f734422d837`. R8 retains the persisted WorkManager entry-point name. Earlier records and checksums below describe their own checkpoints.

- `qada-tracker-v1.25.0-arm64-v8a.apk` (21,550,758 bytes): `782bd1881fb6b05b0f624eb0bccf52f093d247544e0a7655044544152973a6df`.
- `qada-tracker-v1.25.0-armeabi-v7a.apk` (19,177,242 bytes): `55b68a23e2021e2f8680b5ed6e14e7c0356376e38e8980d2ac249103521877f3`.
- `qada-tracker-v1.25.0-x86_64.apk` (23,030,286 bytes): `d663d2f6efd5e535157c299dd450cc00be25b9fbc6bb1f9c0b6a0fb1760c629c`.
- `qada-tracker-v1.25.0.apk` (61,041,746 bytes): `3e665115056ac67090fcd5cf5b5d8c7f611a0eeb45a3bfc48fd5715bc7d810a1`.

---

# Validation record — v1.24.0

Publication completed: v1.24.0 has a separate feature commit, annotated tag, and private GitHub release marked latest. [The upload workflow](https://github.com/zulhisyamsofi/qada-tracker/actions/runs/43740478374) passed. All four APK digests/sizes and the checksum file were independently verified before publication; the temporary private transfer branch was removed. The ARM64 download is **21,550,762 bytes (21.6 MB)**, with the existing app ID and signing certificate for in-place updates.

Keeps current-day prayer editing on Today. History defaults to yesterday and supports earlier-date review and corrections; choosing today from its calendar or date picker opens Today. The first tracking day shows a helper message with a Go to Today action while earlier dates remain available for optional backfill. Review badges, exempt dates, rollover handling, and the separate qada replacement ledger are retained.

Downloads:
- **Realme GT Master / most current Android phones:** `qada-tracker-v1.24.0-arm64-v8a.apk` (21.6 MB).
- **Universal fallback:** `qada-tracker-v1.24.0.apk` (61.0 MB).
- Other assets target 32-bit ARM phones and x86-64 emulators. Choose one APK and keep the same processor variant for later updates. The app ID and signing certificate match previous releases, preserving the journal on an in-place update.

Validation: formatting, static analysis, **125 Flutter tests**, **60 Android JVM tests**, debug compilation, and optimized universal/per-architecture release builds passed. All four APKs have verified signatures, correct versions/architectures, and no debug flag or debug Dart kernel. `SHA256SUMS` covers all downloads. Physical launcher placement, notification timing, and OEM background behavior remain unverified; no Android device is connected. No database schema, backup format, prayer status, qada calculation, permission, dependency, or API change is introduced. Journal/backup version 2, SQLite schema 2, and calendar-cache format 1 remain unchanged.

Six new navigation cases cover light/dark yesterday defaults, past edits leaving today unchanged, calendar/date-picker routing to Today, cancelled selection, the first-day helper with optional older-record entry, open midnight across a month boundary, reopening after a multi-day gap, and app resume. The large-text first-day helper and both themed calendar views were rendered and inspected. Existing review-ring assertions now distinguish today’s green navigation ring from red past-day review rings. No physical Android device is connected; no new emulator validation was performed.

Signing certificate SHA-256: `ccb3ba84ae54baeaa960c1f87f1f7a7f88c5a9604c49945dd3be8f734422d837`. R8 retains the persisted WorkManager entry-point name. Earlier records and checksums below describe their own checkpoints.

- `qada-tracker-v1.24.0-arm64-v8a.apk` (21,550,762 bytes): `3336c82755a00b93fd2965d6662a7d11d60de94f2d68fc1b08c3b5d892b37e35`.
- `qada-tracker-v1.24.0-armeabi-v7a.apk` (19,177,242 bytes): `b122020214bb7abb2d1b85573915600b89185e28e947d495b700b3dcbe896e5a`.
- `qada-tracker-v1.24.0-x86_64.apk` (23,030,286 bytes): `91fe097d48424b1f2736fd7146f66cff727ddd1453886bb979c65171423cedb1`.
- `qada-tracker-v1.24.0.apk` (61,041,746 bytes): `3941847704e79bc7a1776ac2866236f08dc4dfab1778f0cdf6a70b650528fe4a`.

---

# Validation record — v1.23.0

Publication completed: v1.21.0–v1.23.0 have separate feature commits, annotated tags, private GitHub releases, optimized APKs, and checksum files. [The upload workflow](https://github.com/zulhisyamsofi/qada-tracker/actions/runs/43687274221) passed. All 12 APK digests/sizes and three checksum files were independently verified before publication. v1.23.0 is latest, and the temporary private transfer branch was deleted. The ARM64 download is **21,550,610 bytes (21.6 MB)**; app ID and signing certificate match previous releases.

Confirm individual exempt prayers, date ranges, or an ongoing tracking pause. Ranges preserve existing performed and missed records; resume from a chosen prayer today or tomorrow. Exempt prayers add no qada, do not need review, and are excluded from required-prayer totals. Their prayer-time alerts are silenced by default; daily check-ins ignore them. Widgets show a muted dash and open the app for exempt prayers. Includes configurable reminders and one-tap qada from v1.21.0–v1.22.0.

Downloads:
- **Realme GT Master / most current Android phones:** `qada-tracker-v1.23.0-arm64-v8a.apk` (21.6 MB).
- **Universal fallback:** `qada-tracker-v1.23.0.apk` (61.0 MB).
- Other assets target 32-bit ARM phones and x86-64 emulators. Choose one APK and keep the same processor variant for later updates. The app ID and signing certificate match previous releases, preserving the journal on an in-place update.

Validation: formatting, static analysis, **119 Flutter tests**, **60 Android JVM tests**, debug compilation, and optimized universal/per-architecture release builds passed. All four APKs have verified signatures, correct versions/architectures, and no debug flag or debug Dart kernel. `SHA256SUMS` covers all downloads. Physical launcher placement, notification timing, and OEM background behavior remain unverified; no Android device is connected. Journal/backup format is now version 2. Version 1 backups remain supported with safe defaults, but older app versions cannot read a version 2 journal/backup. Export a backup before updating if you may need to downgrade later. SQLite schema 2 and calendar cache format 1 are unchanged. No new dependency, permission, or API is introduced.

New coverage verifies:

- Configurable phone-local check-in time, picker cancellation, per-prayer alert selection, master-switch preference preservation, restart persistence, stale broadcasts after a time/mask change, and clearing deselected displayed alerts.
- Immediate +1 qada recording, unique replacement IDs even under a frozen clock, exact-entry Undo, zero-balance disabling, negative-balance protection, and unchanged daily/historical prayer records.
- Individual exempt prayers, confirmed date ranges, preservation of performed/missed records, partial first/last dates, ongoing pauses, selected-prayer/tomorrow resume, overlapping periods, removal, and explicit required exceptions. Future intervals do not create daily rows.
- Required-only progress and Today counts; review badges exclude exempt prayers. Native alarm filtering suppresses exempt slots and rechecks stale deliveries. Widget dash boxes open the app, and stale widget intents cannot change exemptions or overwrite malformed exemption metadata.
- Journal/backup version 2 round trips and strict validation, legacy version 1 defaults, file-backed SQLite restart/write-failure rollback, picker/confirmation cancellation, and atomic restore with the new preferences/periods.

The journal/backup format changes to version 2. SQLite schema 2 and calendar-cache format 1 are unchanged. Earlier apps cannot read a version 2 journal/backup; keep a pre-update backup before downgrading. Existing master notification opt-ins and prayer confirmations are preserved.

Flutter-rendered reminder settings, quick qada (light/dark and narrow enlarged text), active-pause management, partial exemptions on Today, and shaded History dates were inspected. Native RemoteViews captures show all five exempt dash boxes in light/dark without changing widget dimensions. Captures are reproducible with `QADA_CAPTURE_UI=1 flutter test test/routine_ui_test.dart` and `QADA_CAPTURE_WIDGET=1` during Android tests.


Signing certificate SHA-256: `ccb3ba84ae54baeaa960c1f87f1f7a7f88c5a9604c49945dd3be8f734422d837`. R8 retains the persisted WorkManager entry-point name. Earlier records and checksums below describe their own checkpoints.

- `qada-tracker-v1.23.0-arm64-v8a.apk` (21,550,610 bytes): `3934e705bf1a1a28b621d8e3e550a06a31e2de25104c95878aa83d1bc40dce8b`.
- `qada-tracker-v1.23.0-armeabi-v7a.apk` (19,177,094 bytes): `2afc78c6aa405ecb8a6303b0446143408fedb29fc9bcb3aa28641438e9e01f54`.
- `qada-tracker-v1.23.0-x86_64.apk` (23,030,134 bytes): `12df3e655dc122fd46d4c50154c88f27e24627509bb457a386ef560ef5a1d841`.
- `qada-tracker-v1.23.0.apk` (61,041,594 bytes): `68ecad3ca4357691bd7f6320c6e08f0876b935575d314015803b146446afb726`.

---

# Validation record — v1.22.0

Choose a phone-local daily check-in time (11 PM by default) and select individual prayer-time alerts in the shared Notifications settings. Choices survive master-switch changes, restart, and backup/restore. Android reads preferences from SQLite when scheduling and delivering, rejects stale deselected alerts, and clears their displayed notifications. Includes the quick-qada action from v1.21.0.

Downloads:
- **Realme GT Master / most current Android phones:** `qada-tracker-v1.22.0-arm64-v8a.apk` (21.4 MB).
- **Universal fallback:** `qada-tracker-v1.22.0.apk` (60.6 MB).
- Other assets target 32-bit ARM phones and x86-64 emulators. Choose one APK and keep the same processor variant for later updates. The app ID and signing certificate match previous releases, preserving the journal on an in-place update.

Validation: formatting, static analysis, **110 Flutter tests**, **52 Android JVM tests**, debug compilation, and optimized universal/per-architecture release builds passed. All four APKs have verified signatures, correct versions/architectures, and no debug flag or debug Dart kernel. `SHA256SUMS` covers all downloads. Physical launcher placement, notification timing, and OEM background behavior remain unverified; no Android device is connected. The journal/backup remains version 1 with backward-compatible optional preferences. SQLite schema and calendar cache format are unchanged. Existing master opt-ins are preserved.

Signing certificate SHA-256: `ccb3ba84ae54baeaa960c1f87f1f7a7f88c5a9604c49945dd3be8f734422d837`. R8 retains the persisted WorkManager entry-point name. Earlier records and checksums below describe their own checkpoints.

- `qada-tracker-v1.22.0-arm64-v8a.apk` (21,353,818 bytes): `153f77d07215b5ac870f08d060afe2c04b78fff6f44b5e668bce17dd8b00c486`.
- `qada-tracker-v1.22.0-armeabi-v7a.apk` (19,029,458 bytes): `2e618e1883e4cfbd3309b67c3299fc7e3495ca98fc9f3465dc953cc16d432eac`.
- `qada-tracker-v1.22.0-x86_64.apk` (22,898,882 bytes): `1a41538199dbbb21af8ce3571616d8596235a476b5ba58eea8ad19ec01a978f1`.
- `qada-tracker-v1.22.0.apk` (60,566,278 bytes): `0ba50a9261c81c8147e79ba6e7ee64a6ef74b7ee7f0ead48588bbd20ddbd5caf`.

---

# Validation record — v1.21.0

Adds a +1 action beside each prayer’s outstanding qada count, with immediate saving and Undo for the exact replacement entry. The action is disabled at zero and serialized balance checks prevent over-recording. Existing quantity entry and replacement history remain available. Daily prayer records and historical misses stay separate.

Downloads:
- **Realme GT Master / most current Android phones:** `qada-tracker-v1.21.0-arm64-v8a.apk` (21.2 MB).
- **Universal fallback:** `qada-tracker-v1.21.0.apk` (59.9 MB).
- Other assets target 32-bit ARM phones and x86-64 emulators. Choose one APK and keep the same processor variant for later updates. The app ID and signing certificate match previous releases, preserving the journal on an in-place update.

Validation: formatting, static analysis, **106 Flutter tests**, **47 Android JVM tests**, debug compilation, and optimized universal/per-architecture release builds passed. All four APKs have verified signatures, correct versions/architectures, and no debug flag or debug Dart kernel. `SHA256SUMS` covers all downloads. Physical launcher placement, notification timing, and OEM background behavior remain unverified; no Android device is connected. No database schema, backup format, or prayer-status migration is needed.

Signing certificate SHA-256: `ccb3ba84ae54baeaa960c1f87f1f7a7f88c5a9604c49945dd3be8f734422d837`. R8 retains the persisted WorkManager entry-point name. Earlier records and checksums below describe their own checkpoints.

- `qada-tracker-v1.21.0-arm64-v8a.apk` (21,157,050 bytes): `963ddc0c39f1524678e5542527c65cad84cc8af0f35bdb7d4bb679455bf9684c`.
- `qada-tracker-v1.21.0-armeabi-v7a.apk` (18,783,534 bytes): `2d76317ac3d515946482a326846e51ce6752aa5f24de8ce6a141f51b60685591`.
- `qada-tracker-v1.21.0-x86_64.apk` (22,636,574 bytes): `fe2d0d2ca9dc1e1ad0614053ac269def63b4d7d6861ff126f4c968686c65871f`.
- `qada-tracker-v1.21.0.apk` (59,861,606 bytes): `3177bfddccb323eaf4a10028ff62bb4e90f10c5be09be5167ea657455931a39b`.

---

# Validation record — v1.20.0

Publication completed: v1.16.0–v1.20.0 have separate feature commits, annotated tags, private GitHub releases, optimized APKs, and checksum files. [The upload workflow](https://github.com/zulhisyamsofi/qada-tracker/actions/runs/43618983708) passed. All 20 APK digests/sizes and all five checksum files were independently verified before publication. v1.20.0 is latest, and the temporary private transfer branch was deleted. No signing keys or journal data were transferred. The final ARM64 download is **21,157,054 bytes (21.2 MB)**; the universal fallback is 59,828,842 bytes.

Removes the notification testing/diagnostics expander and unused test-alert interfaces. Both reminder switches remain together. Android notification/alarm settings links appear only when an enabled reminder needs access; daily and prayer-channel permission checks remain independent. Includes the v1.16–v1.19 qada tooltip polish, titled/padded 4 × 1 widget, restored Today cards/circular progress panel, and simpler Dark mode settings. Existing widgets may need a small vertical resize or re-adding to accommodate the title.

Downloads:
- **Realme GT Master / most current Android phones:** `qada-tracker-v1.20.0-arm64-v8a.apk` (21.2 MB).
- **Universal fallback:** `qada-tracker-v1.20.0.apk` (59.8 MB).
- Other assets target 32-bit ARM phones and x86-64 emulators. Choose one APK and keep the same processor variant for later updates. The app ID and signing certificate match previous releases, preserving the journal on an in-place update.

Validation: formatting, static analysis, **103 Flutter tests**, **47 Android JVM tests**, debug compilation, and optimized universal/per-architecture release builds passed. All four APKs have verified signatures, correct versions/architectures, and no debug flag or debug Dart kernel. `SHA256SUMS` covers all downloads. Physical launcher placement, notification timing, and OEM background behavior remain unverified. No database, backup-format, status, or qada-calculation migration is needed.

Implementation checks also verify all five saved prayer statuses in both themes on 390 × 844, 320 × 640, and 320 × 568 viewports with Android-style safe areas. The larger layout shows all five without scrolling; smaller screens and large text retain full-size touch targets and can scroll. Six actual-tooltip cases measure outer screen clearance, bounded width, and inner padding in both themes and at enlarged text. Light/dark previews, readable Nunito tooltip text, and the borderless info icon were visually inspected.

The 17 widget cases cover the compact title, increased padding, 4 × 1 target metadata, full prayer names at 1.6× text, and 48 × 48 dp minimum prayer targets at 280 × 80 dp. Real title/background/gap/box gestures distinguish app navigation from toggling. Settings checks cover removed Appearance/testing controls, persistent light/dark/system values, independent reminder choices, and conditional permission links. The 18 notification-integration cases run across simulated API 33/35, alongside seven daily-policy and five prayer-time-policy cases. Physical launcher and OS notification delivery remain unverified; no new emulator validation was performed during release packaging.

Signing certificate SHA-256: `ccb3ba84ae54baeaa960c1f87f1f7a7f88c5a9604c49945dd3be8f734422d837`. R8 retains the persisted WorkManager entry-point name. Earlier records and checksums below describe their own checkpoints.

- `qada-tracker-v1.20.0-arm64-v8a.apk` (21,157,054 bytes): `80f5d24c2f07d75bbdd53f7062c419ed71bba6fdd5faacfe4b9e11fec2fd9cc5`.
- `qada-tracker-v1.20.0-armeabi-v7a.apk` (18,750,770 bytes): `74d369dfe85b5f65801cdd4cb9c483d9cd7be05f891ede533ed5092a3b72757f`.
- `qada-tracker-v1.20.0-x86_64.apk` (22,636,578 bytes): `e06e1f5372bb97f4c6866d5f7fa36fe8d7abac3ac81afc962c66f161243c2a50`.
- `qada-tracker-v1.20.0.apk` (59,828,842 bytes): `a58133d600696650090445c9a658a7c49e0fe321d2e6a91b1451db82c6dba2e8`.

---

# Validation record — v1.19.0

Removes the redundant Appearance dropdown. The Settings Dark mode switch and app-bar shortcut remain, with persistent theme changes and backup compatibility. Existing system-following preferences remain supported until a manual light/dark selection is made.

Downloads:
- **Realme GT Master / most current Android phones:** `qada-tracker-v1.19.0-arm64-v8a.apk` (21.2 MB).
- **Universal fallback:** `qada-tracker-v1.19.0.apk` (59.9 MB).
- Other assets target 32-bit ARM phones and x86-64 emulators. Choose one APK and keep the same processor variant for later updates. The app ID and signing certificate match previous releases, preserving the journal on an in-place update.

Validation: formatting, static analysis, **103 Flutter tests**, **49 Android JVM tests**, debug compilation, and optimized universal/per-architecture release builds passed. All four APKs have verified signatures, correct versions/architectures, and no debug flag or debug Dart kernel. `SHA256SUMS` covers all downloads. Physical launcher placement, notification timing, and OEM background behavior remain unverified. No database, backup-format, status, or qada-calculation migration is needed.

Signing certificate SHA-256: `ccb3ba84ae54baeaa960c1f87f1f7a7f88c5a9604c49945dd3be8f734422d837`. R8 retains the persisted WorkManager entry-point name. Earlier records and checksums below describe their own checkpoints.

- `qada-tracker-v1.19.0-arm64-v8a.apk` (21,157,082 bytes): `3b72cebf3a3cae7997c9592ccc8eeec6b4922f33812da1bbf9ada7b26d8cb9a3`.
- `qada-tracker-v1.19.0-armeabi-v7a.apk` (18,783,566 bytes): `d95578e4032eb660d49fda3b84f5f56fb645d82febdf92b4c7f7af8ec310ddbd`.
- `qada-tracker-v1.19.0-x86_64.apk` (22,636,610 bytes): `ebce899cb25fce637f63492f756ce6e07b49516279cc30a2522d8337381ebca0`.
- `qada-tracker-v1.19.0.apk` (59,861,638 bytes): `cdf0067fc04cbbc9074d67dab20b7ffae460acaed578dd1d5aac11cff4dd421f`.

---

# Validation record — v1.18.0

Restores Today’s original prayer-card padding, spacing, and rounded progress panel with a circular completion counter. Location controls stay in Settings and reviews stay in History. The tested 390 × 844 layout shows all five prayers without scrolling; shorter screens and enlarged text scroll without shrinking controls.

Downloads:
- **Realme GT Master / most current Android phones:** `qada-tracker-v1.18.0-arm64-v8a.apk` (21.2 MB).
- **Universal fallback:** `qada-tracker-v1.18.0.apk` (59.9 MB).
- Other assets target 32-bit ARM phones and x86-64 emulators. Choose one APK and keep the same processor variant for later updates. The app ID and signing certificate match previous releases, preserving the journal on an in-place update.

Validation: formatting, static analysis, **103 Flutter tests**, **49 Android JVM tests**, debug compilation, and optimized universal/per-architecture release builds passed. All four APKs have verified signatures, correct versions/architectures, and no debug flag or debug Dart kernel. `SHA256SUMS` covers all downloads. Physical launcher placement, notification timing, and OEM background behavior remain unverified. No database, backup-format, status, or qada-calculation migration is needed.

Signing certificate SHA-256: `ccb3ba84ae54baeaa960c1f87f1f7a7f88c5a9604c49945dd3be8f734422d837`. R8 retains the persisted WorkManager entry-point name. Earlier records and checksums below describe their own checkpoints.

- `qada-tracker-v1.18.0-arm64-v8a.apk` (21,157,086 bytes): `406c445ea5dfae68419058b9b085f88f72534d0aa16ae1892e2b99c5a656e5a8`.
- `qada-tracker-v1.18.0-armeabi-v7a.apk` (18,799,954 bytes): `89eb50a4a3552bd6037962715c5f680af15a6013f12714153ccb6573838de215`.
- `qada-tracker-v1.18.0-x86_64.apk` (22,636,610 bytes): `56f75f16ae4f3141a901e6ac607e47aa529b1484fbb9105c85912a2d591e5a1a`.
- `qada-tracker-v1.18.0.apk` (59,878,022 bytes): `c4a9d62ff6027be2581b8f3c4db5c920381ed44be115dff8030d6d124b8178e8`.

---

# Validation record — v1.17.0

Adds a compact Qada Tracker title above the five padded prayer boxes while retaining the 4 × 1 target. Title, background, and gaps open Today; prayer boxes keep toggling performed/unrecorded with the existing recording rules. Minimum content size is 280 × 80 dp. Existing launcher placements may need a small vertical resize or re-adding.

Downloads:
- **Realme GT Master / most current Android phones:** `qada-tracker-v1.17.0-arm64-v8a.apk` (21.2 MB).
- **Universal fallback:** `qada-tracker-v1.17.0.apk` (59.9 MB).
- Other assets target 32-bit ARM phones and x86-64 emulators. Choose one APK and keep the same processor variant for later updates. The app ID and signing certificate match previous releases, preserving the journal on an in-place update.

Validation: formatting, static analysis, **103 Flutter tests**, **49 Android JVM tests**, debug compilation, and optimized universal/per-architecture release builds passed. All four APKs have verified signatures, correct versions/architectures, and no debug flag or debug Dart kernel. `SHA256SUMS` covers all downloads. Physical launcher placement, notification timing, and OEM background behavior remain unverified. No database, backup-format, status, or qada-calculation migration is needed.

Signing certificate SHA-256: `ccb3ba84ae54baeaa960c1f87f1f7a7f88c5a9604c49945dd3be8f734422d837`. R8 retains the persisted WorkManager entry-point name. Earlier records and checksums below describe their own checkpoints.

- `qada-tracker-v1.17.0-arm64-v8a.apk` (21,157,086 bytes): `d9377074f150c200d17676a010411bfaef9000c899e8c7e5a344f885015817b3`.
- `qada-tracker-v1.17.0-armeabi-v7a.apk` (18,799,954 bytes): `9e96494187e4e8c6d27d9be94a2618543f954267c662f65ceaa3784c0e690504`.
- `qada-tracker-v1.17.0-x86_64.apk` (22,636,610 bytes): `8c7ddfb3a68b36ba2295d42823fab492f10b3ca883e293255c1431f92ed2e7ea`.
- `qada-tracker-v1.17.0.apk` (59,878,022 bytes): `c312946566c69ace64b54050435260790f606628852720e8187dc2d3067f35d5`.

---

# Validation record — v1.16.0

Removes the oversized circular border from the qada info button while keeping its accessible tap area. The formula popup now has a bounded width, screen-edge clearance, internal padding, rounded corners, and readable theme-aware text. Six popup checks cover light/dark, narrow screens, and enlarged text.

Downloads:
- **Realme GT Master / most current Android phones:** `qada-tracker-v1.16.0-arm64-v8a.apk` (21.2 MB).
- **Universal fallback:** `qada-tracker-v1.16.0.apk` (59.9 MB).
- Other assets target 32-bit ARM phones and x86-64 emulators. Choose one APK and keep the same processor variant for later updates. The app ID and signing certificate match previous releases, preserving the journal on an in-place update.

Validation: formatting, static analysis, **103 Flutter tests**, **49 Android JVM tests**, debug compilation, and optimized universal/per-architecture release builds passed. All four APKs have verified signatures, correct versions/architectures, and no debug flag or debug Dart kernel. `SHA256SUMS` covers all downloads. Physical launcher placement, notification timing, and OEM background behavior remain unverified. No database, backup-format, status, or qada-calculation migration is needed.

Signing certificate SHA-256: `ccb3ba84ae54baeaa960c1f87f1f7a7f88c5a9604c49945dd3be8f734422d837`. R8 retains the persisted WorkManager entry-point name. Earlier records and checksums below describe their own checkpoints.

- `qada-tracker-v1.16.0-arm64-v8a.apk` (21,156,154 bytes): `53bfddce5f00ed66d01d69850a77ff070bca444786569c445becd25ee4157d35`.
- `qada-tracker-v1.16.0-armeabi-v7a.apk` (18,799,026 bytes): `468b06022afeab57a049dbd2c937bae24e5c2f8a111bf5e36f526476c07365a5`.
- `qada-tracker-v1.16.0-x86_64.apk` (22,635,682 bytes): `f994d52d0e4978a6c46ee1c3f6b668d3b277781218b461fbd36fa6a73a6fc993`.
- `qada-tracker-v1.16.0.apk` (59,877,094 bytes): `c8d84bf4395e7cbced64cb1faca674d67efd32c958ead51d6873789c9e8e9bff`.

---

# Validation record — v1.15.0


Publication completed: v1.12.0–v1.15.0 are private GitHub releases with separate annotated feature tags. [The uploader workflow](https://github.com/zulhisyamsofi/qada-tracker/actions/runs/43606169544) passed; all 16 APK digests/sizes and all four checksum files were independently checked against the local artifacts before publication. v1.15.0 is latest. The temporary private APK transfer branch was deleted; no signing keys or journals were transferred. Its ARM64 download is **21,156,158 bytes (21.2 MB)**, about 88.6% smaller than the pre-publication 185,671,938-byte universal debug APK; the optimized universal fallback is 59,860,710 bytes.

A disposable software Android 15 emulator accepted the optimized x86-64 v1.12.0 install and an in-place update to v1.15.0. Activity launch returned success and the baseline tour rendered. Repeated emulator System UI/launcher ANRs prevented a reliable interactive end-to-end check, so runtime UI, notification timing, real hardware, and OEM background behavior remain unverified. Automated Flutter/Robolectric results below are separate from this limited smoke check. Flutter's standard per-ABI version-code offsets apply; keep the same APK variant for subsequent updates.

Groups Prayer-time notifications and Daily check-in reminder in Settings → Notifications, preserving their independent choices. Location settings contain only place/timetable controls. Adds shared permission checks, a same-channel test alert, rescheduling, and Android alarm/notification/battery settings links. The 11 PM check-in now triggers when any prayer is unrecorded, and stays until all five are confirmed. Repairs cached prayer alarms on startup/resume, separates channel checks, and retains the existing 15-minute stale-delivery cutoff. Removes repeated Qada Tracker screen subtitles.

Downloads:
- **Realme GT Master / most recent Android phones:** `qada-tracker-v1.15.0-arm64-v8a.apk` (21.2 MB).
- **Universal fallback:** `qada-tracker-v1.15.0.apk` (59.9 MB).
- Other assets target older 32-bit ARM phones and x86-64 emulators. Choose one APK, then install it over the existing app to keep the journal. Package and signing certificate are unchanged.

Validation: formatting, static analysis, **98 Flutter tests**, **49 Android JVM tests**, debug compilation, and optimized universal/per-architecture release builds passed. All four APKs have verified signatures, correct versions/architectures, and no debug flag. `SHA256SUMS` covers every download. Physical phone notification/Doze/battery behavior remains unverified.


Signing certificate SHA-256: `ccb3ba84ae54baeaa960c1f87f1f7a7f88c5a9604c49945dd3be8f734422d837`. R8 mapping confirms the persisted WorkManager entry-point name is retained. The source is Flutter 3.38.5 with the pinned Android toolchain. Earlier checkpoint records below retain their original hashes and results.

- `qada-tracker-v1.15.0-arm64-v8a.apk`: `d5e5e815a5a29f9a212410b8542b614bd83b4220504c86023d560b94116b935c`
- `qada-tracker-v1.15.0-armeabi-v7a.apk`: `62dc6525708c465cb6681d7b3e52957ed8e15df524425642c8601a360808dc8e`
- `qada-tracker-v1.15.0-x86_64.apk`: `7f19adfa1893b5800e21f28ca060a1fc23db22663add1a3723782179afdf7afa`
- `qada-tracker-v1.15.0.apk`: `9786c93f8ac7717033f213a58500827d3c87071dc5671ffe94b108f70b4042d6`

---

# Development checkpoint — Unified notification settings

The complete `scripts/validate.sh` passes: formatting (38 Dart files, zero changes), static analysis (no issues), **98 Flutter tests**, **49 Android JVM tests** (zero failures, errors, or skips), and universal Android debug APK compilation. Working APK: `build/app/outputs/flutter-apk/app-debug.apk`; SHA-256: `7dd0b8f9b88adc148d739f3590f211461ba741e7158bd71288d25d215df2afb9`. The existing debug certificate is retained: `ccb3ba84ae54baeaa960c1f87f1f7a7f88c5a9604c49945dd3be8f734422d837`. No version tag or release has been created for these working changes.

The user identified the disabled in-app prayer notification switch as the cause of the observed missing alerts. Both independent switches are now visible together at Settings → Notifications; prayer-time location settings contain no notification controls. Tests verify enabling/disabling either preference preserves the other, daily-channel denial does not prevent prayer opt-in, offline disabling works, existing consent behavior remains, and the diagnostics/test/reschedule/settings actions use the shared group. Light/dark Settings and location-page raster previews were inspected; all four theme rendering tests also passed with capture enabled. Repeated screen-title/Settings footer branding is removed, while Today retains its date subtitle.

The 11 PM native check-in tests cover one remaining unrecorded prayer, mixed performed/missed confirmations, retaining a displayed notification after partial app/widget edits, and clearing it after all five are confirmed. Missing daily slots count as unrecorded; no reminder changes prayer statuses or qada balances.

Twenty new notification integration cases run on simulated Android API 33 and 35 (10 cases each), using native SQLite, AlarmManager, NotificationManager, and real pending-intent payloads. They verify posting and successor scheduling, permission/channel denial, early/stale/duplicate suppression, opt-out cancellation, forced alarm repair, isolated same-channel test alerts, and partial daily check-ins. The existing 17 launcher-widget, seven daily-policy, and five prayer-policy cases also pass. The established 15-minute stale-alert cutoff is unchanged. Cached alarm setup is independent of background refresh initialization, and startup/resume repairs cached schedules. No schema, backup format, permission, dependency, or API source change is introduced.

No physical Realme or other Android device is connected. Robolectric component tests and APK compilation do not establish delivery under Realme battery restrictions, Doze, reboot, or Android system permission flows on a phone. Enable the prayer switch, send a test notification from the shared group, grant alarms/reminders access, and check the next actual prayer alert on the device. Earlier validation records below describe their own checkpoints and APKs.

---

# Development checkpoint — Focused Today screen

`scripts/validate.sh` passes: formatting (38 Dart files, no changes), static analysis (no issues), **94 Flutter tests**, **29 Android JVM tests** (no failures/errors/skips), and universal Android debug APK compilation. Working APK: `build/app/outputs/flutter-apk/app-debug.apk`; SHA-256: `4f688564a08eec0f6bd042c99e8463d931849198cc8bad722e9f0a420aaa242a`. Previously tagged release checksums below describe their own APKs.

Nine new widget tests verify all five checkboxes are visible, hit-testable, and at least 48 pixels across, with zero scroll extent on 390 × 844, 320 × 640, and 320 × 568 viewports in light/dark. Tests include 24-pixel Android-style top and bottom safe-area insets and actually mark all five prayers without scrolling. They also verify the review prompt is absent on Today and above History’s calendar, a saved device location appears in Settings without another GPS request and survives reopening, offline retry information remains available, and large text can scroll through every prayer without shrinking touch targets.

Rendered Today previews in both themes and the saved-location Settings entry were inspected. Today uses an app-bar date, compact count/progress strip, and five prayer cards; location, review, large introductory/summary blocks, and the footer have been removed from the home checklist. Settings → Prayer times & location retains place/GPS/source/notification controls, while History owns the review prompt. The walkthrough and existing user-flow tests follow these paths. All earlier History badge/calendar, qada, prayer-time policy, backup, reminder, and native widget tests remain passing.

No prayer status, start-time rule, qada calculation, saved place, schema, backup format, permission, dependency, or API change is introduced. Physical-device UI and OS notification delivery remain unverified in this environment; this validation uses Flutter rendering, simulated Android tests, and APK compilation.

---

# Development checkpoint — History review indicators

`scripts/validate.sh` passes: formatting (37 Dart files, no changes), static analysis (no issues), **85 Flutter tests**, **29 Android JVM tests** (zero failures/errors/skips), and universal Android debug APK compilation. Working APK: `build/app/outputs/flutter-apk/app-debug.apk`; SHA-256: `abe50c9b2470866ec511615287624b155bb8dd23daf82dc7d11961098fc207ad`. Older release checksums below refer to their tagged APKs.

Six new widget tests verify one count per unresolved past day rather than per prayer; two-date examples; exclusion of today, future dates, and untouched pre-start gaps; red outlines matching the badge; retained red selection outlines; partial updates and final resolution as performed/missed; re-opening a day by clearing a record; explicit backfilled dates; bulk review; hidden zero badge; midnight month rollover, resume/closed gaps; date input/jump/cancel; leap years and supported date bounds. Light/dark large-text tests verify exact long-gap counts above 999, accessible count/day labels, and matching marker colours. The existing file-backed history restart test also passes with the marked calendar.

Flutter raster previews were inspected at 390 × 844 and 320 × 720 with 1.6× text/high contrast. Badge digits use the bundled Nunito font and retain the full count. Calendar day text scales within its seven-column grid; semantic labels retain full dates and review state. Month buttons and the date/year chooser remain available. The walkthrough explains the badge and date rings.

Navigation, Today’s review prompt, and the History calendar share the same unresolved past-day set. The underlying statuses and qada rules are unchanged. Confirmed misses alone do not trigger this review badge, while unresolved prayers never add qada automatically. No schema, backup, dependency, permission, or API changes were introduced. Physical Android launcher/device validation remains unavailable.

---

# Validation record — v1.14.0

Opens Today directly to all five prayer cards without scrolling at normal font sizes on the tested phone layouts. Moves saved location controls to Settings → Prayer times & location, keeps review above History’s calendar, and updates the walkthrough. Large text remains scrollable with full touch targets.

Downloads:
- **Realme GT Master / most recent Android phones:** `qada-tracker-v1.14.0-arm64-v8a.apk` (21.2 MB).
- **Universal fallback:** `qada-tracker-v1.14.0.apk` (59.8 MB).
- Other assets target older 32-bit ARM phones and x86-64 emulators. Choose one APK, then install it over the existing app to keep the journal. Package and signing certificate are unchanged.

Validation: formatting, static analysis, **94 Flutter tests**, **29 Android JVM tests**, debug compilation, and optimized universal/per-architecture release builds passed. All four APKs have verified signatures, correct versions/architectures, and no debug flag. `SHA256SUMS` covers every download. Physical phone notification/Doze/battery behavior remains unverified.


Signing certificate SHA-256: `ccb3ba84ae54baeaa960c1f87f1f7a7f88c5a9604c49945dd3be8f734422d837`. R8 mapping confirms the persisted WorkManager entry-point name is retained. The source is Flutter 3.38.5 with the pinned Android toolchain. Earlier checkpoint records below retain their original hashes and results.

- `qada-tracker-v1.14.0-arm64-v8a.apk`: `44f6aae8325df40d4235703633720b03f55b5ed4c245f6c6de4776887fde5ff6`
- `qada-tracker-v1.14.0-armeabi-v7a.apk`: `d9dab0d49eaad22d406f9fef026715b6b7707b0f2c5dbcdd20a683e548f5bdf3`
- `qada-tracker-v1.14.0-x86_64.apk`: `b9f00d170d806752c96b63c05cdd933fc59e9523a6aa16cf8911230a9acfd517`
- `qada-tracker-v1.14.0.apk`: `50dede0765b6e4153ea156639961a0b96fc4cace6b7473c89ba0a72970565955`

---

# Validation record — v1.13.0

Adds a red History badge counting past days with unrecorded prayers, matching calendar date rings, and a review prompt above the calendar. Partial corrections, bulk review, long gaps, optional historical records, and midnight/resume update the markers without turning unrecorded prayers into qada.

Downloads:
- **Realme GT Master / most recent Android phones:** `qada-tracker-v1.13.0-arm64-v8a.apk` (21.2 MB).
- **Universal fallback:** `qada-tracker-v1.13.0.apk` (59.8 MB).
- Other assets target older 32-bit ARM phones and x86-64 emulators. Choose one APK, then install it over the existing app to keep the journal. Package and signing certificate are unchanged.

Validation: formatting, static analysis, **85 Flutter tests**, **29 Android JVM tests**, debug compilation, and optimized universal/per-architecture release builds passed. All four APKs have verified signatures, correct versions/architectures, and no debug flag. `SHA256SUMS` covers every download. Physical phone notification/Doze/battery behavior remains unverified.


Signing certificate SHA-256: `ccb3ba84ae54baeaa960c1f87f1f7a7f88c5a9604c49945dd3be8f734422d837`. R8 mapping confirms the persisted WorkManager entry-point name is retained. The source is Flutter 3.38.5 with the pinned Android toolchain. Earlier checkpoint records below retain their original hashes and results.

- `qada-tracker-v1.13.0-arm64-v8a.apk`: `6278eda3b46ccac3570b52508283a3ff32da98b83d8dd931d946bc514a29d606`
- `qada-tracker-v1.13.0-armeabi-v7a.apk`: `8ccc1011f232451d45cbfadc71e09981304c9a0261f638c448eb245bbf2a18ba`
- `qada-tracker-v1.13.0-x86_64.apk`: `8ee1403f6d17d194510774832be18be9ff85793a4fa4350b9d277ddd68fe029e`
- `qada-tracker-v1.13.0.apk`: `ceb52185f8784d13e0c10e271921b1a0c7416ffa930a13dec360cc41b977219c`

---

# Validation record — v1.12.0

Replaces debug distribution with optimized release APKs: Dart ahead-of-time compilation and tree shaking, R8 Android code shrinking, resource shrinking, and icon tree shaking. Includes ARM64, 32-bit ARM, x86-64, and a universal fallback. Keeps the existing app signer for in-place upgrades and preserves the WorkManager entry point across updates. No features or journal data removed.

Downloads:
- **Realme GT Master / most recent Android phones:** `qada-tracker-v1.12.0-arm64-v8a.apk` (21.1 MB).
- **Universal fallback:** `qada-tracker-v1.12.0.apk` (59.6 MB).
- Other assets target older 32-bit ARM phones and x86-64 emulators. Choose one APK, then install it over the existing app to keep the journal. Package and signing certificate are unchanged.

Validation: formatting, static analysis, **79 Flutter tests**, **29 Android JVM tests**, debug compilation, and optimized universal/per-architecture release builds passed. All four APKs have verified signatures, correct versions/architectures, and no debug flag. `SHA256SUMS` covers every download. Physical phone notification/Doze/battery behavior remains unverified.


Signing certificate SHA-256: `ccb3ba84ae54baeaa960c1f87f1f7a7f88c5a9604c49945dd3be8f734422d837`. R8 mapping confirms the persisted WorkManager entry-point name is retained. The source is Flutter 3.38.5 with the pinned Android toolchain. Earlier checkpoint records below retain their original hashes and results.

- `qada-tracker-v1.12.0-arm64-v8a.apk`: `ae801ffd1924edc5807e64a842fa3a7d7b38785f16ea91fb9c4de392a3620d23`
- `qada-tracker-v1.12.0-armeabi-v7a.apk`: `0dd35437793e767d367dc6cc8409f328eb7a64bed05f64e4d82162b3e2854013`
- `qada-tracker-v1.12.0-x86_64.apk`: `204a09a194db2074575ff2755ec0cb2a2aa1a7a09652e4c8c149877e4459e59d`
- `qada-tracker-v1.12.0.apk`: `1525650d05279741872a4ebdfba64e7f91c58b50804173fa239b5cc7df491830`

---

# Validation record — v1.11.0+12

The prayer-card edition passes `scripts/validate.sh`: formatting (34 Dart files, zero changes), static analysis (no issues), **79 Flutter tests**, **29 Android JVM tests**, and universal Android debug APK compilation. Package `com.personal.qada_tracker`; version 1.11.0 (code 12), minimum API 24, target API 36. The existing debug signing certificate is retained. APK SHA-256: `b0078eb0dabc0d1c20c0b325bcf3f2b3bd53c6ad82ac7cd2671c1d5ba2f6a715`.

Two new widget tests verify performed cards’ green borders and softer text, confirmed misses’ bold red styling, past unrecorded cards’ amber needs-review styling, repeated checkbox changes, corrections between missed/unrecorded, and exact qada effects in both themes. The eight consent tests and all earlier feature tests also pass. The final app and test sources are byte-for-byte identical to the fully tested requested changes, apart from release metadata and documentation.

Rendered previews were inspected in light/dark; narrow consent controls also passed 320 × 720 at 1.6× text, high contrast, and rotation. High-contrast completed text stays opaque. Styling applies across Today, History, and daily review without changing statuses or qada calculations. No schema, backup version, dependency, Android permission, or API source changed. Real-phone notification delivery remains unverified.

---

# Validation record — v1.10.0+11

The reminder-consent edition passes `scripts/validate.sh`: formatting (33 Dart files, no changes), static analysis (no issues), **77 Flutter tests**, **29 Android JVM tests**, and universal Android debug APK compilation. Package `com.personal.qada_tracker`; version 1.10.0 (code 11), minimum API 24, target API 36. Existing debug signing certificate retained. APK SHA-256: `9c51eb0ebbce54ecba9fd03d1d82999a894570ee5d4717f3586fb66c35d7b7a5`.

Eight new tests verify default-on reminder selection before any permission request, explicit consent and selected-place persistence, optional alarm access, disabling through Settings, restart/backup persistence, permission/app/channel denial, skip/opt-out, replay respecting opt-out, failed-save retry, both themes with large text, and rotation while an error is displayed. The remaining tests cover the earlier app features.

The eight-step tour offers prayer-time alerts to new Android users; the saved preference remains off until explicit consent and permission approval. Existing settings and opt-outs remain unchanged on replay or skip. Onboarding and Settings share permission/channel checks, transactional settings writes, and schedule refresh/cancellation. The daily 11 PM check-in reminder remains separately opt-in. No schema, backup version, permission, production dependency, or API changed. Phone delivery remains unverified; automated tests use Flutter rendering and simulated Android.

---

# Validation record — v1.9.0+10

The walkthrough edition passes formatting (32 Dart files, no changes), static analysis (no issues), **69 Flutter tests**, and **29 Android JVM tests** (no failures, errors, or skips). Its universal Android debug APK builds successfully at `build/app/outputs/flutter-apk/app-debug.apk`. SHA-256: `11870ce8b68242faa3003513c75dee623cbc0c3b8f56cc2e53d76a19f3b89153`. The APK retains the existing debug signing certificate.

Seven new tests cover automatic first launch, all seven steps and actual tab changes, blocked prayer edits, Next/Back, completed and skipped dismissal, Android Back, Settings replay, interrupted tours, file-backed SQLite restart, failed-write retry, legacy backup defaults, invalid preference rejection, and preference round trips. Light/dark captures were inspected at 390 × 844 and 320 × 720 with 1.6× text; rotation to 720 × 320, high contrast, and reduced motion also pass. A native widget regression assertion verifies that launcher toggles retain the new preference. Existing feature fixtures represent users who have already seen the guide.

New database initialization opts into the tour. Older journals and backups without the optional boolean default to seen; they can replay the tour from Settings. No database schema or backup version change is required, and no dependency, permission, or API was added. An unfinished tour is shown again after restart; completing or skipping returns to Today. This edition includes the v1.8 rounded splash icon.

Validation uses Flutter rendering and Robolectric. Physical Android launch/rotation and accessibility-service behavior have not been tested on a phone. The earlier release records and checksums below are retained for provenance.

---

# Validation record — v1.8.0+9

The rounded splash-icon edition passes `scripts/validate.sh`: formatting (30 Dart files, zero changes), static analysis (no issues), 62 Flutter tests, 29 Android JVM tests, and universal Android debug APK compilation. The application change is confined to the icon’s rounded background path. Runtime phone validation remains unavailable.

Package `com.personal.qada_tracker`; version 1.8.0 (code 9), minimum API 24, target API 36. The existing debug signing certificate is retained. APK SHA-256: `09e57ce341a33086e2a27a07f896d955061172e347eb1745d8ae07d9036c6d95`.

---

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
