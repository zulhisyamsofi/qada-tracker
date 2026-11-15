import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qada_tracker/controller.dart';
import 'package:qada_tracker/database.dart';
import 'package:qada_tracker/main.dart';
import 'package:qada_tracker/model.dart';
import 'package:qada_tracker/prayer_times_api.dart';
import 'package:qada_tracker/prayer_times_controller.dart';
import 'package:qada_tracker/prayer_times_models.dart';
import 'package:qada_tracker/ui/history_calendar.dart';
import 'support/prayer_times.dart';
import 'theme_ui_test.dart' show fonts, capture, captureKey;
import 'prayer_times_controller_test.dart' show FakeTimesApi;

final now = DateTime(2026, 11, 14, 23);
Widget app(JournalDatabase db, {PrayerLocation? location, FakeTimesApi? api}) =>
    ProviderScope(
      overrides: [
        databaseProvider.overrideWith((ref) async => db),
        clockProvider.overrideWithValue(() => now),
        if (api != null)
          prayerTimesApiProvider.overrideWithValue(api)
        else
          fakePrayerTimes,
        if (location != null)
          prayerLocationProvider.overrideWithValue(location),
      ],
      child: RepaintBoundary(key: captureKey, child: const QadaApp()),
    );
void viewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.view.resetViewPadding);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Finder prayerCheckbox(Prayer p) => find.byWidgetPredicate(
  (w) => w is Checkbox && w.semanticLabel == '${p.label} performed',
);
void visibleCheckboxes(WidgetTester tester) {
  final bounds = tester.getRect(find.byKey(const ValueKey('today-prayers')));
  for (final p in Prayer.values) {
    final target = prayerCheckbox(p);
    final rect = tester.getRect(target);
    expect(rect.top, greaterThanOrEqualTo(bounds.top), reason: p.label);
    expect(rect.bottom, lessThanOrEqualTo(bounds.bottom), reason: p.label);
    expect(target.hitTestable(), findsOneWidget, reason: p.label);
    expect(tester.getSize(target).shortestSide, greaterThanOrEqualTo(48));
  }
}

class RecordingLocation extends PrayerLocation {
  int requests = 0;
  @override
  Future<PrayerPlace> current() async {
    requests++;
    return const PrayerPlace(
      'gps',
      'Saved device location',
      3.139,
      101.6869,
      device: true,
    );
  }
}

void main() {
  setUpAll(fonts);
  for (final size in [
    const Size(390, 844),
    const Size(320, 640),
    const Size(320, 568),
  ]) {
    for (final mode in [AppTheme.light, AppTheme.dark]) {
      testWidgets(
        'restored prayer cards remain usable on ${size.width.toInt()}x${size.height.toInt()} ${mode.name}',
        (tester) async {
          viewport(tester, size);
          final db = JournalDatabase(NativeDatabase.memory());
          await db.save(
            Journal(startDate: DateTime(2026, 11, 11), theme: mode),
          );
          try {
            await tester.pumpWidget(app(db));
            await tester.pumpAndSettle();
            expect(find.text('3 days need review'), findsNothing);
            expect(
              find.byKey(const ValueKey('history-review-prompt')),
              findsNothing,
            );
            expect(find.text('Kuala Lumpur'), findsNothing);
            expect(find.byTooltip('Prayer times & location'), findsNothing);
            if (size.width == 390) visibleCheckboxes(tester);
            final scroll = tester.state<ScrollableState>(
              find.descendant(
                of: find.byKey(const ValueKey('today-prayers')),
                matching: find.byType(Scrollable),
              ),
            );
            if (size.width == 390) {
              expect(scroll.position.maxScrollExtent, 0);
            } else {
              expect(scroll.position.maxScrollExtent, greaterThan(0));
            }
            expect(find.byType(CircularProgressIndicator), findsOneWidget);
            expect(find.byType(LinearProgressIndicator), findsNothing);
            await capture(
              tester,
              'today-restored-${size.width.toInt()}x${size.height.toInt()}-${mode.name}',
            );
            for (final p in Prayer.values) {
              await tester.ensureVisible(prayerCheckbox(p));
              await tester.pumpAndSettle();
              await tester.tap(prayerCheckbox(p));
              await tester.pumpAndSettle();
              expect(
                (await db.load(now)).status(now, p),
                PrayerStatus.performed,
                reason: p.label,
              );
            }
            scroll.position.jumpTo(0);
            await tester.pumpAndSettle();
            expect(find.text('5/5'), findsOneWidget);
            if (size.width == 390) visibleCheckboxes(tester);
            expect((await db.load(now)).outstanding, 0);
            await tester.tap(find.text('History').last);
            await tester.pumpAndSettle();
            expect(find.text('3 days need review'), findsOneWidget);
            expect(
              tester
                  .getRect(find.byKey(const ValueKey('history-review-prompt')))
                  .bottom,
              lessThanOrEqualTo(
                tester.getRect(find.byType(HistoryCalendar)).top,
              ),
            );
            expect(tester.takeException(), isNull);
          } finally {
            await tester.pumpWidget(const SizedBox());
            await db.close();
          }
        },
      );
    }
  }

  testWidgets(
    'saved device location is shown in Settings and survives opening its controls and an app restart',
    (tester) async {
      viewport(tester, const Size(390, 844));
      final location = RecordingLocation();
      final db = JournalDatabase(NativeDatabase.memory());
      const place = PrayerPlace(
        'gps',
        'Saved device location',
        3.139,
        101.6869,
        device: true,
      );
      await db.save(
        Journal(
          startDate: dayOnly(now),
          prayerTimes: const PrayerTimeSettings(place: place),
        ),
      );
      try {
        await tester.pumpWidget(app(db, location: location));
        await tester.pumpAndSettle();
        expect(find.textContaining('Saved device location'), findsNothing);
        visibleCheckboxes(tester);
        await tester.tap(find.byTooltip('Settings'));
        await tester.pumpAndSettle();
        expect(find.text('Saved device location'), findsOneWidget);
        await capture(tester, 'settings-saved-prayer-location');
        await tester.ensureVisible(find.text('Prayer times & location'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Prayer times & location'));
        await tester.pumpAndSettle();
        expect(find.text('Saved device location'), findsOneWidget);
        expect(
          find.text('Zone WLY01 · Times shown in Asia/Kuala_Lumpur'),
          findsOneWidget,
        );
        expect(location.requests, 0);
        Navigator.of(
          tester.element(find.text('Prayer times & location')),
        ).pop();
        await tester.pumpAndSettle();
        visibleCheckboxes(tester);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(app(db, location: location));
        await tester.pumpAndSettle();
        expect((await db.load(now)).prayerTimes.place.key, place.key);
        expect(location.requests, 0);
        visibleCheckboxes(tester);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await db.close();
      }
    },
  );

  testWidgets(
    'offline retry remains available and missing times still block prayer marking',
    (tester) async {
      viewport(tester, const Size(320, 640));
      final db = JournalDatabase(NativeDatabase.memory());
      final api = FakeTimesApi()..fail = true;
      await db.save(Journal(startDate: dayOnly(now)));
      try {
        await tester.pumpWidget(app(db, api: api));
        await tester.pumpAndSettle();
        expect(
          find.text('Times unavailable · pull down to retry'),
          findsOneWidget,
        );
        await tester.ensureVisible(prayerCheckbox(Prayer.subuh));
        await tester.pumpAndSettle();
        await tester.tap(prayerCheckbox(Prayer.subuh));
        await tester.pumpAndSettle();
        expect(
          (await db.load(now)).status(now, Prayer.subuh),
          PrayerStatus.unrecorded,
        );
        expect(find.byType(SnackBar), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await db.close();
        api.client.close();
      }
    },
  );

  testWidgets(
    'large text keeps every prayer reachable through scrolling without shrinking touch targets',
    (tester) async {
      viewport(tester, const Size(320, 568));
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final db = JournalDatabase(NativeDatabase.memory());
      await db.save(Journal(startDate: dayOnly(now)));
      try {
        await tester.pumpWidget(app(db));
        await tester.pumpAndSettle();
        for (final p in Prayer.values) {
          await tester.scrollUntilVisible(prayerCheckbox(p), 120);
          expect(
            tester.getSize(prayerCheckbox(p)).shortestSide,
            greaterThanOrEqualTo(48),
          );
          await tester.tap(prayerCheckbox(p));
          await tester.pumpAndSettle();
        }
        expect(
          (await db.load(now)).records[dateKey(now)]!.values.every(
            (s) => s == PrayerStatus.performed,
          ),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await db.close();
      }
    },
  );
}
