# Glass UI direction — v1.3

Reference: [light and dark Today concept](glass-reference.png). This is a Flutter Android application; the concept is implemented with native widgets and compared to Flutter-rendered screenshots rather than an HTML/browser imitation.

## Design system

- Light: pale mint ambient background; nearly white translucent surfaces; deep emerald text; forest-green primary; visible mint/green outlines.
- Dark: deep emerald background; translucent dark-green surfaces; near-white text; bright mint primary; green/white edge highlights.
- Type: bundled static Nunito weights 400/600/700/800 (OFL), headers 27/800, page titles 22–23/800, prayer titles 18/800, body 14–15/500–600, supporting text 12/500, controls 14/800. Respect system text scaling.
- Geometry: 20 px page gutters, 10 px row gaps, 24 px repeated panels and 30 px summary panels, 36 px pill navigation, circular outlined icon controls, outlined pill buttons. Minimum control targets remain 48 px where practical.
- Glass: translucent diagonal surface gradients, thin edge highlights, gentle shadows; real clipped backdrop blur only on the summary and bottom navigation. Repeated rows use unblurred translucent fills to keep scrolling economical. High-contrast mode uses solid surfaces and stronger borders.
- Motion: short theme and state transitions; no looping decorative animation. Honor reduced-motion/high-contrast preferences.

## Inventory and copy

Preserve Today, History, Qada, Progress, Times; the existing prayer actions, review workflow, history calendar, qada ledger, statistics, location selection, and notifications. Header copy: current tab title and `Qada Tracker`. Main Today copy: `One prayer at a time.`, the current date, the actual `N of 5 prayers recorded today` count, `A small moment to reflect and keep track.`, and the five Malay prayer names with existing status labels. No invented metrics or extra product features.

The main summary pairs the existing count with a circular progress indicator. Prayer rows keep a checkbox, prayer/status text, and a clearly outlined overflow button. The selected navigation item uses a mint capsule. Add a working theme toggle beside Settings and an explicit Dark mode switch within Settings; retain System/Light/Dark selection and persist through the existing journal setting.

Shared surfaces and tokens apply to History, Qada, Progress, Times, review sheets, settings, and dialogs. Controls remain code-native. The ambient background needs no raster asset; Material rounded icons retain the existing metaphors. The generated concept is a design reference, not shipped as an interactive UI image.

## Intentional extensions

- The reference is a primary-screen pair; existing downstream screens inherit its surfaces, typography, outlines, and spacing.
- Dynamic review prompts remain when relevant. Midnight help copy is shortened to `A fresh page at midnight. Your history stays saved.` Smaller screens and large text scroll instead of hiding content. Fixed navigation labels scale down only when needed to fit their destination names; full labels are also available to assistive technology and long-press tooltips.
- Native Material rounded glyphs are used; their precise strokes may differ from the concept rendering.
- Screenshot comparisons and any necessary repairs are recorded after implementation below.

## Render comparison and repair ledger

The generated reference was inspected before implementation, then compared with actual Flutter raster captures in both themes at 390 × 844 logical pixels. All five tabs and Settings were rendered with real app widgets and deterministic journal/API fixtures. The narrow-screen check uses 320 × 720, 1.6× system text, high contrast, and reduced motion. No Browser/IAB tool is available, and this native Dart IO application is not a web target; Flutter widget rendering is the appropriate fallback. This does not verify Android system UI, GPU frame pacing, or a physical phone.

| Reference anchor | Implemented comparison and repair |
| --- | --- |
| Rounded, strong typography | The first variable-font render looked too thin. Static Nunito instances now give the headers, prayer names, and controls distinct weights matching the concept's hierarchy. |
| Mint light palette / emerald dark palette | Both rendered Today screens retain the reference's deep text / pale text contrast. Body text was strengthened after the first comparison; supporting text and status icons remain distinct. |
| Glass panel edges and depth | Shared translucent gradients and fine borders recreate the rounded panels. Shadows were reduced after the first render. Blur is clipped and limited to hero/navigation; form sheets use opaque surfaces to prevent underlying text showing through. |
| Today composition | The title, date, count with progress ring, and five rows follow the reference's order and spacing. At the standard viewport all five prayers, the shortened footer, and the navigation fit. Existing review prompts add height when there are unresolved past days. |
| Selected navigation capsule | Replaced the default icon-only highlight with a full icon-and-label mint capsule. Full names fit rather than truncate on narrow/large-text layouts; tab semantics expose selected state. |
| Outlined controls | Circular header/overflow buttons, larger rounded checkboxes, and bordered pill actions match the concept's geometry. The same treatment carries into backup, qada, location, calendar, and dialog controls. |
| Downstream consistency | Visually inspected History light, Qada dark, Progress light, Times dark, and Settings dark in addition to both Today themes. All tabs render without widget exceptions in both themes. Calendar, statistics, and forms retain their existing native arrangements. |
| Accessibility | High contrast removes blur and decorative glows, strengthens borders, and retains solid panels. The enlarged-text screenshot is scrollable; theme controls remain reachable. Native Material glyph strokes differ slightly from the illustration. |

Theme switching is exercised through the header and Settings, SQLite persistence, app remount, and Follow system mode. Existing journal behavior is covered by the full regression suite.

Regenerate the temporary visual captures locally with:

```bash
source scripts/env.sh
QADA_CAPTURE_UI=1 flutter test test/theme_ui_test.dart
```

Captures are written to ignored `build/visual-qa`; temporary QA captures are removed after inspection. The permanent design reference is retained here for review.
