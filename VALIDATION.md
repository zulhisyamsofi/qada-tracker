# Validation record — v1.2.0

The tagged source passed `scripts/validate.sh` during release packaging:

- Dart formatting check: no changes required.
- Flutter analysis: no issues found.
- Flutter tests: **38 passed**.
- Android JVM tests: **12 passed**, with no failures, errors, or skips.
- Android universal debug APK build: successful.
- Package: `com.personal.qada_tracker`; version **1.2.0**; minimum API 24; target API 36.
- APK SHA-256: `186d801ba6912098efe3ca2435a8939c0c5f82019cc6181e497fa40a16fd1fcb`.
- Debug signing certificate SHA-256: `ccb3ba84ae54baeaa960c1f87f1f7a7f88c5a9604c49945dd3be8f734422d837`, matching the previous builds for in-place updates.

Flutter 3.38.5, Dart 3.10.4, JDK 17, and the repository's pinned Android tooling were used. The private GitHub release contains the APK and `SHA256SUMS`.

Flutter libraries for this historical feature edition were recovered from the original debug APK. Android integration and version-specific tests were separated from the accumulated changes, then checked and rebuilt before tagging.

No connected phone or usable accelerated emulator was available. Actual launcher placement, physical GPS, real notification delivery, reboot/Doze behavior, and OEM battery restrictions remain outside these automated checks.
