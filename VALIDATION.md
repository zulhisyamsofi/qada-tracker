# Validation record

## Toolchain and reproducibility

- Flutter 3.38.5 (`f6ff1529fd6d8af5f706051d9251ac9231c83407`), Dart 3.10.4.
- Temurin JDK 17.0.17+10, verified against its official SHA-256. The image's Java 21 installation lacked `javac`; the user-owned JDK supplies it. The environment's supplied public CA is trusted without disabling TLS verification.
- Android command-line tools 19.0 verified against Google's published SHA-1; platforms 35/36, build tools 35.0.0, NDK 28.2.13676358, CMake 3.22.1.
- Gradle 8.14 wrapper from the official source tag, with distribution SHA-256 pinned; Android Gradle Plugin 8.11.1 and Kotlin 2.2.20.
- Linux SQLite FFI uses a local alias to the preinstalled `libsqlite3.so.0`; no system files were modified.
- `scripts/setup.sh` completed successfully and was rerun with the frozen dependency lockfile to verify repeatability.

## Passed

The complete `scripts/validate.sh` completed with exit status 0:

- `dart format --output=none --set-exit-if-changed lib test`: 10 files, 0 changes.
- `flutter analyze`: no issues found.
- `flutter test`: **19 passed, 0 failed**. Includes ledger corrections, negative-balance protection, unrecorded gaps, JSON validation/round trips, database reopen/rollback, serialized writes, backup cancellation/confirmation, midnight/resume, and the main review-to-replacement widget flow.
- `flutter build apk --debug`: succeeded. Universal APK: `build/app/outputs/flutter-apk/app-debug.apk`.

Initial failures were diagnosed and resolved: the SDK download policy, missing Linux SQLite soname, a test finder matching both background and dialog buttons, and the missing Java compiler. No assertions were disabled.

## Android runtime

A disposable API 35 x86-64 emulator was installed and started without hardware acceleration (`/dev/kvm` is absent). Android boot completion was confirmed. The smaller x86-64 APK installed successfully using `adb install --no-streaming`.

**Native runtime smoke test is inconclusive:** Android System UI displayed an ANR before the app was launched. Launching Qada Tracker reached its Android splash screen, but `am start -W` timed out before journal rendering could be verified. A second launch with Flutter's software-rendering extra also timed out. Native prayer entry, persistence, and the document picker are therefore **not verified** on Android; their widget/domain/database tests passed on the host. This is not classified as a confirmed application defect because the emulator itself was already unresponsive. The disposable emulator was stopped after the attempt.

The universal APK has package `com.personal.qada_tracker`, version `1.0.0` (code 1), minimum API 24, target API 36, and ARM32, ARM64, and x86-64 native libraries. Its SHA-256 is `1ec56cec399fb52eb0cf0c4c0b196618f4ad2f6878dd251c82a73d1358d29c86`.

An additional `flutter build apk --debug --split-per-abi` succeeded, producing separate ARM32, ARM64, and x86-64 APKs in the same output directory. Use the universal APK if the phone architecture is unknown.

No physical Android phone, release signing, or store publication has been tested or performed. Chrome and Linux desktop doctor warnings are outside the Android target.
