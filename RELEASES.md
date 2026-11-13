# Private Android releases

The repository and its GitHub releases remain private. Release assets require GitHub sign-in with repository access. These are personal-installation Android debug APKs, not Play Store publications.

Each feature edition is represented by a separate commit and annotated tag. The existing v1.0.0 commit is retained as the baseline. Flutter source snapshots for v1.1.0–v1.4.0 were recovered from the original debug APKs; native integration and tests were separated from the accumulated additions. All versions were checked and rebuilt for this publication. The v1.5.0 app code matches the completed integrated-times implementation.

| Version | Feature edition | Flutter / Android tests | Release |
| --- | --- | --- | --- |
| v1.0.0 | Initial prayer journal and qada tracker | 19 / 0 | [v1.0.0](https://github.com/zulhisyamsofi/qada-tracker/releases/tag/v1.0.0) |
| v1.1.0 | Daily check-in reminders | 24 / 7 | [v1.1.0](https://github.com/zulhisyamsofi/qada-tracker/releases/tag/v1.1.0) |
| v1.2.0 | Malaysian prayer times and alerts | 38 / 12 | [v1.2.0](https://github.com/zulhisyamsofi/qada-tracker/releases/tag/v1.2.0) |
| v1.3.0 | Dark-mode toggles and glass UI | 42 / 12 | [v1.3.0](https://github.com/zulhisyamsofi/qada-tracker/releases/tag/v1.3.0) |
| v1.4.0 | Native home-screen prayer widget | 48 / 23 | [v1.4.0](https://github.com/zulhisyamsofi/qada-tracker/releases/tag/v1.4.0) |
| v1.5.0 | Integrated times and start-time validation | 56 / 25 | [v1.5.0](https://github.com/zulhisyamsofi/qada-tracker/releases/tag/v1.5.0) |

Every version passed formatting, static analysis, its Flutter tests, and an Android debug APK build. Versions with native test suites also passed those checks. Native widget tests use Robolectric. Actual launcher placement, GPS, notification delivery, reboot/Doze behavior, and OEM battery restrictions remain unverified on a physical phone.

Each release contains `qada-tracker-v<version>.apk` and `SHA256SUMS`. All APKs retain package `com.personal.qada_tracker`, minimum API 24, target API 36, and the same debug signing certificate (`ccb3ba84ae54baeaa960c1f87f1f7a7f88c5a9604c49945dd3be8f734422d837`). Install the latest APK as an update to retain the journal.

No repository visibility change, Android store release, or cloud-environment publication is performed by this GitHub release process.
