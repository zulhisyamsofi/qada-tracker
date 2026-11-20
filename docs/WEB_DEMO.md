# Recruiter web demo

The Flutter web entry point is `lib/demo_main.dart`. It reuses the Android application's screens, Riverpod controller, domain rules, and transactional Drift schema. Android still launches `lib/main.dart` and uses its original SQLite file; the web demo uses a separate IndexedDB database named `qada-portfolio-demo` with SQLite WebAssembly.

## Demonstration behavior

- A fixed sample day, **13 November 2026**, is shown after all five sample prayer start times. The banner labels sample times explicitly; these are not live prayer times.
- Initial records include one performed prayer today, a completed earlier day, and two missed prayers yesterday. Try Today → Done/Missed, Qada → count → Open date → Done, then inspect the changed balance and History.
- Changes stay in the current browser/origin. Reload preserves them. **Reset demo** restores the synthetic journal, preferences, and balances. No connection to the owner's Android records exists.
- The prayer-time API is replaced with a deterministic sample calendar. Every selected place uses sample times; real device location is disabled. The demo sends no location or journal data to a prayer-time provider.
- Android notifications and launcher widgets are unavailable in a browser. Notification controls are disabled; widget actions explain platform availability. The banner makes this limitation visible. No browser notification permission is requested.
- Language, theme, history, qada, progress, and walkthrough are shared with Android. Manual backups use the browser's file-picker implementation where supported. Never import real sensitive data into this public demo.
- Storage requires IndexedDB and WebAssembly; restrictive iframe/private-browsing settings can block it. Data is browser-local, unencrypted, and may be cleared by the browser. Use one active demo tab; this simple IndexedDB backend is not intended for concurrent multi-tab editing.

## Build and run

```bash
source scripts/env.sh
./scripts/build-web-demo.sh
python3 -m http.server 8080 --directory build/web
```

Open `http://localhost:8080`. Use `flutter run -d chrome --target lib/demo_main.dart` for development if Chrome is configured. The archive `build/qada-tracker-web-demo.zip` contains the static site with `index.html` at its root. The web build vendors CanvasKit locally instead of loading the renderer from Google's CDN. Roboto and Noto Sans Symbols fallback fonts are bundled locally with notices in `web/fallback_fonts` (including Apache-2.0 and OFL notices for Roboto). No backend, API keys, authentication, Node server, or custom isolation headers are required for this IndexedDB implementation.

`web/sqlite3.wasm` comes from the pinned sqlite3.dart **2.9.4** release at `https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-2.9.4/sqlite3.wasm`. Its accompanying package license is retained in `web/sqlite3.LICENSE`. Nunito and package license notices remain available through Flutter's license registry.

## Hosting and ChatGPT Sites

Deploy the **contents** of `build/web` to an HTTPS static host; keep `sqlite3.wasm`, `main.dart.js`, `flutter_bootstrap.js`, assets, and CanvasKit files together. Do not upload Flutter source as though it were the built site. A subdirectory deployment needs Flutter's `--base-href /your-path/` option (leading/trailing slashes).

No ChatGPT Sites publishing tool is available in the current session. If its interface supports importing a prebuilt static site, use the zip; if it only supports its own generated app projects, it cannot be assumed to accept a Flutter bundle. In that case host this bundle on a static provider and link/embed it where Sites supports that. Do not claim a live URL until the actual hosting platform accepts and serves the bundle.

The application has not been deployed by this change. Publishing to a particular service needs its deployment capability and an actual successful upload. This work does not change repository visibility, create a GitHub release, or publish on Google Play.

## Validation evidence

The complete Flutter suite passed **158 tests** after introducing the demo/frame; targeted controller/linked-record tests also passed after fixing JavaScript ID generation. Static analysis and an Android debug APK build passed. The web release build and static ZIP packaging passed.

Browser plugin was unavailable, so validation used headless Playwright with Chromium at `http://localhost:8080`, at 1280 × 900 and 390 × 844. The checked flow was Today → Done → reload/persist → Qada → a count → Open date → Done → reduced balance → Reset demo → restored sample counts → Settings platform notice → mobile dark mode and Done. Page identity, meaningful rendered content, and screenshots were checked; no framework error overlay, application exception, failed request, or external network request occurred in that flow. Chromium software rendering emitted `GPU stall due to ReadPixels` performance warnings during captures; these are not evidence of physical-device performance.

Safari/iPhone, Firefox, multi-tab editing, browser backup-picker behavior, and ChatGPT Sites hosting were not runtime-validated. Flutter's tree shaker reports an optional Cupertino icon-family warning; the tested Chromium UI uses bundled Material icons and rendered correctly. The domain's random ID bounds now use the literal `0x100000000`, because JavaScript compiles `1 << 32` as zero. This is exercised by actual web qada completion, not just a native Dart test.
