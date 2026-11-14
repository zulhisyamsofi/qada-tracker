# Changelog

Each version tag identifies one feature edition.

## v1.20.0 — Cleaner notification settings

Removes the notification testing/diagnostics expander and unused test-alert interfaces. Both reminder switches remain together. Android notification/alarm settings links appear only when an enabled reminder needs access; daily and prayer-channel permission checks remain independent. Includes the v1.16–v1.19 qada tooltip polish, titled/padded 4 × 1 widget, restored Today cards/circular progress panel, and simpler Dark mode settings. Existing widgets may need a small vertical resize or re-adding to accommodate the title.

## v1.19.0 — Simpler dark-mode settings

Removes the redundant Appearance dropdown. The Settings Dark mode switch and app-bar shortcut remain, with persistent theme changes and backup compatibility. Existing system-following preferences remain supported until a manual light/dark selection is made.

## v1.18.0 — Restored roomy Today cards

Restores Today’s original prayer-card padding, spacing, and rounded progress panel with a circular completion counter. Location controls stay in Settings and reviews stay in History. The tested 390 × 844 layout shows all five prayers without scrolling; shorter screens and enlarged text scroll without shrinking controls.

## v1.17.0 — Titled and padded home-screen widget

Adds a compact Qada Tracker title above the five padded prayer boxes while retaining the 4 × 1 target. Title, background, and gaps open Today; prayer boxes keep toggling performed/unrecorded with the existing recording rules. Minimum content size is 280 × 80 dp. Existing launcher placements may need a small vertical resize or re-adding.

## v1.16.0 — Qada formula tooltip polish

Removes the oversized circular border from the qada info button while keeping its accessible tap area. The formula popup now has a bounded width, screen-edge clearance, internal padding, rounded corners, and readable theme-aware text. Six popup checks cover light/dark, narrow screens, and enlarged text.

## v1.15.0 — Unified notification settings

Groups Prayer-time notifications and Daily check-in reminder in Settings → Notifications, preserving their independent choices. Location settings contain only place/timetable controls. Adds shared permission checks, a same-channel test alert, rescheduling, and Android alarm/notification/battery settings links. The 11 PM check-in now triggers when any prayer is unrecorded, and stays until all five are confirmed. Repairs cached prayer alarms on startup/resume, separates channel checks, and retains the existing 15-minute stale-delivery cutoff. Removes repeated Qada Tracker screen subtitles.

## release-tools-v1.1.0 — Private APK transfer fallback

Lets the existing checked-release workflow read APKs from a temporary private GitHub transfer commit when the external 72-hour host is unavailable. Source tags, filenames, file sizes, SHA-256 hashes, draft status, and uploaded digests remain verified. No signing keys or personal data are transferred. The temporary branch is removed after successful publication; APKs are attached to private releases.

## v1.14.0 — Focused Today checklist

Opens Today directly to all five prayer cards without scrolling at normal font sizes on the tested phone layouts. Moves saved location controls to Settings → Prayer times & location, keeps review above History’s calendar, and updates the walkthrough. Large text remains scrollable with full touch targets.

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
