# Private Android releases

The repository and its GitHub releases remain private. Release assets require GitHub sign-in with repository access. Versions through v1.11.0 use personal-installation debug APKs; v1.12.0 onward use optimized release-mode APKs. These are private installations, not Play Store publications.

Each feature edition is represented by a separate commit and annotated tag. The existing v1.0.0 commit is retained as the baseline. Flutter source snapshots for v1.1.0–v1.4.0 were recovered from the original debug APKs; native integration and tests were separated from the accumulated additions. All versions were checked and rebuilt for this publication. The v1.5.0 app code matches the completed integrated-times implementation.

| Version | Feature edition | Flutter / Android tests | Release |
| --- | --- | --- | --- |
| v1.0.0 | Initial prayer journal and qada tracker | 19 / 0 | [v1.0.0](https://github.com/zulhisyamsofi/qada-tracker/releases/tag/v1.0.0) |
| v1.1.0 | Daily check-in reminders | 24 / 7 | [v1.1.0](https://github.com/zulhisyamsofi/qada-tracker/releases/tag/v1.1.0) |
| v1.2.0 | Malaysian prayer times and alerts | 38 / 12 | [v1.2.0](https://github.com/zulhisyamsofi/qada-tracker/releases/tag/v1.2.0) |
| v1.3.0 | Dark-mode toggles and glass UI | 42 / 12 | [v1.3.0](https://github.com/zulhisyamsofi/qada-tracker/releases/tag/v1.3.0) |
| v1.4.0 | Native home-screen prayer widget | 48 / 23 | [v1.4.0](https://github.com/zulhisyamsofi/qada-tracker/releases/tag/v1.4.0) |
| v1.5.0 | Integrated times and start-time validation | 56 / 25 | [v1.5.0](https://github.com/zulhisyamsofi/qada-tracker/releases/tag/v1.5.0) |
| v1.6.0 | Compact 4 × 1 toggleable widget | 56 / 29 | [v1.6.0](https://github.com/zulhisyamsofi/qada-tracker/releases/tag/v1.6.0) |
| v1.7.0 | Consistent cards and editable history | 62 / 29 | [v1.7.0](https://github.com/zulhisyamsofi/qada-tracker/releases/tag/v1.7.0) |
| v1.8.0 | Rounded splash icon | 62 / 29 | [v1.8.0](https://github.com/zulhisyamsofi/qada-tracker/releases/tag/v1.8.0) |
| v1.9.0 | First-launch walkthrough | 69 / 29 | [v1.9.0](https://github.com/zulhisyamsofi/qada-tracker/releases/tag/v1.9.0) |
| v1.10.0 | Prayer-reminder consent | 77 / 29 | [v1.10.0](https://github.com/zulhisyamsofi/qada-tracker/releases/tag/v1.10.0) |
| v1.11.0 | Prayer-card status styling | 79 / 29 | [v1.11.0](https://github.com/zulhisyamsofi/qada-tracker/releases/tag/v1.11.0) |
| v1.12.0 | Smaller optimized APKs | 79 / 29 | [v1.12.0](https://github.com/zulhisyamsofi/qada-tracker/releases/tag/v1.12.0) |
| v1.13.0 | History review badges and calendar | 85 / 29 | [v1.13.0](https://github.com/zulhisyamsofi/qada-tracker/releases/tag/v1.13.0) |
| v1.14.0 | Focused Today checklist | 94 / 29 | [v1.14.0](https://github.com/zulhisyamsofi/qada-tracker/releases/tag/v1.14.0) |
| v1.15.0 | Unified notification settings | 98 / 49 | [v1.15.0](https://github.com/zulhisyamsofi/qada-tracker/releases/tag/v1.15.0) |
| v1.16.0 | Qada formula tooltip polish | 103 / 49 | [v1.16.0](https://github.com/zulhisyamsofi/qada-tracker/releases/tag/v1.16.0) |
| v1.17.0 | Titled and padded home-screen widget | 103 / 49 | [v1.17.0](https://github.com/zulhisyamsofi/qada-tracker/releases/tag/v1.17.0) |

Every version passed formatting, static analysis, its Flutter tests, and an Android debug APK build. Versions with native test suites also passed those checks. Native widget tests use Robolectric. Actual launcher placement, GPS, notification delivery, reboot/Doze behavior, and OEM battery restrictions remain unverified on a physical phone.

Each release contains `qada-tracker-v<version>.apk` and `SHA256SUMS`. From v1.12.0, that APK is an optimized universal fallback; additional `-arm64-v8a.apk`, `-armeabi-v7a.apk`, and `-x86_64.apk` downloads contain only their target processor libraries. ARM64 is recommended for the Realme GT Master. Optimized build command: `./scripts/build-release.sh`. All APKs retain package `com.personal.qada_tracker`, minimum API 24, target API 36, and the same debug signing certificate (`ccb3ba84ae54baeaa960c1f87f1f7a7f88c5a9604c49945dd3be8f734422d837`). Install the latest APK as an update to retain the journal, and use the same processor variant for subsequent updates (Flutter applies per-ABI version-code offsets).

No repository visibility change, Android store release, or cloud-environment publication is performed by this GitHub release process.

## Upload automation — release-tools-v1.0.0

The separately tagged publishing workflow handles the cloud credential's inability to authenticate to GitHub's dedicated asset-upload host. It uses a repository-scoped GitHub Actions token on a hosted runner to attach the already-built APKs; it does not rebuild or re-sign them. The pinned workflow verifies the annotated source tag, expected file size, local checksum, and uploaded asset digest before reporting success. It uploads into drafts; publication follows verification.

The workflow now runs manually. Supply a JSON `manifest` input for new checked draft assets; leaving it blank selects the original bootstrap manifest, which is retained for provenance. Published releases are never overwritten. Its transfer manifest uses checksum-pinned temporary HTTPS file links that expire after 72 hours. Refresh those links before a later retry. Copies attached to GitHub releases remain available through the private repository after transfer. No personal access token, signing keystore, or app records are committed or stored as workflow secrets.

## Private transfer fallback — release-tools-v1.1.0

If the temporary file host is unavailable, the workflow accepts an `assets_ref` commit SHA and manifest files with a `path` relative to its `checked-assets` checkout. Only already-built APKs are staged on a temporary private branch; no signing key or journal data is included. The same tag, filename, size, hash, draft, and uploaded-digest checks apply. The private transfer branch is deleted after verification and publication. APK binaries are not added to the application's main-branch history.

The v1.12.0–v1.15.0 upload completed successfully in [GitHub Actions](https://github.com/zulhisyamsofi/qada-tracker/actions/runs/43606169544). All APK/checksum assets were independently verified before publication, v1.15.0 is marked latest, and the temporary private transfer branch has been deleted.
