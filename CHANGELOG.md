# Changelog

Each version tag identifies one feature edition.

## v1.13.0 — History review badges and calendar

Adds a red History badge counting past days with unrecorded prayers, matching calendar date rings, and a review prompt above the calendar. Partial corrections, bulk review, long gaps, optional historical records, and midnight/resume update the markers without turning unrecorded prayers into qada.

## v1.12.0 — Smaller optimized APKs

Replaces debug distribution with optimized release APKs: Dart ahead-of-time compilation and tree shaking, R8 Android code shrinking, resource shrinking, and icon tree shaking. Includes ARM64, 32-bit ARM, x86-64, and a universal fallback. Keeps the existing app signer for in-place upgrades and preserves the WorkManager entry point across updates. No features or journal data removed.

## v1.11.0 — Prayer-card status styling

Performed prayer cards use green borders and softer text, confirmed misses use bold red styling, and past unrecorded prayers use amber styling with a needs-review label. The cues apply to Today, History, and daily review without changing prayer statuses or qada rules. High-contrast mode retains fully opaque completed text.

## v1.10.0 — Prayer-reminder consent

Adds a first-launch prayer-reminder setup step with notifications preselected for new Android users, a place selector, explicit permission consent, optional alarm access, and a way to continue without alerts. Existing opt-outs are preserved. Settings links directly to prayer-time notification controls; onboarding and Settings share permission/channel checks and scheduling/cancellation. Tour navigation adapts to narrow screens and large text.

## v1.9.0 — First-launch walkthrough

Adds a seven-step tour over the real app screens with highlighted controls, Next/Back/Skip, saved dismissal, and replay from Settings. First-time users see it automatically; existing journals retain their normal startup. Guide taps cannot change records. Light/dark, large text, reduced motion, rotation, interrupted tours, and write-failure retry are covered. The optional walkthrough preference is included in backups with a backward-compatible default.

## v1.8.0 — Rounded splash icon

Rounds the green icon background while retaining the crescent and checkmark. The icon used by Android’s splash and launcher now has transparent rounded corners.

## v1.7.0 — Consistent cards and editable history

Makes all weekly/monthly Progress cards full width and moves the outstanding-qada formula into an adjacent tappable info tooltip. History supports manual records before first launch, including confirmed misses and corrections, without moving the tracking start or creating review items for untouched gaps. Optional historical days are included in review/progress only while they contain a confirmed record. Persistence, backup validation, and negative-balance protection cover these older records.

## v1.6.0 — Compact toggleable widget

Changes the home-screen widget from 4 × 2 to 4 × 1, removes the header/footer, and opens Today when its padding or gaps are tapped. Repeated prayer taps toggle performed/unrecorded, with offline clearing and existing time/qada checks preserved. Release uploads accept a supplied checked manifest for new feature editions.

## release-tools-v1.0.1 — Draft asset addressing

Uses explicit release IDs and the official asset-upload API so the hosted runner can attach files to drafts created by the publishing integration.

## release-tools-v1.0.0 — Private release uploads

Adds a pinned GitHub workflow that transfers the already-checked APKs into draft releases, verifying the source tag, size, and SHA-256. Uses GitHub's repository-scoped runner token, with no personal token or signing key stored. App versions and application sources are unchanged.

## v1.5.0 — Integrated times and recording validation

Times beside Today prayer labels, four-tab navigation, and start-time checks in the app and widget.

## v1.4.0 — Home-screen prayer widget

Five native launcher buttons, shared SQLite records, rollover, and safe app/widget edits.

## v1.3.0 — Dark mode and glass UI

Persistent theme toggles, rounded glass panels, bordered controls, and bundled Nunito.

## v1.2.0 — Malaysian prayer times

Place/GPS selection, JAKIM zone times, offline cache, and prayer alerts.

## v1.1.0 — Daily check-in reminders

Local 11 PM reminders when no prayers have been recorded.

## v1.0.0 — Initial app

Daily tracking, review, history, qada ledger, progress, themes, and manual backups.
