import 'support/prayer_actions.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qada_tracker/controller.dart';
import 'package:qada_tracker/database.dart';
import 'package:qada_tracker/main.dart';
import 'package:qada_tracker/model.dart';
import 'package:qada_tracker/ui/app_theme.dart';
import 'package:qada_tracker/ui/history_calendar.dart';
import 'support/prayer_times.dart';
import 'theme_ui_test.dart' show fonts, capture, captureKey;
import 'walkthrough_test.dart' show phone;

final now = DateTime(2026, 11, 14, 12);
Widget app(JournalDatabase db, {DateTime Function()? clock}) => ProviderScope(
  overrides: [
    databaseProvider.overrideWith((ref) async => db),
    clockProvider.overrideWithValue(clock ?? () => now),
    fakePrayerTimes,
  ],
  child: RepaintBoundary(key: captureKey, child: const QadaApp()),
);
Badge badge(WidgetTester tester) =>
    tester.widget<Badge>(find.byKey(const ValueKey('history-review-badge')));
void expectCount(WidgetTester tester, int count) {
  expect(badge(tester).isLabelVisible, count > 0);
  expect((badge(tester).label! as Text).data, '$count');
}

BoxDecoration day(WidgetTester tester, String key) =>
    tester
            .widget<DecoratedBox>(find.byKey(ValueKey('history-day-$key')))
            .decoration
        as BoxDecoration;
Finder date(String key) => find.byKey(ValueKey('history-date-$key'));
Future<void> tapMark(WidgetTester t, Prayer p, {bool done = true}) async {
  final f = done ? doneButton(p) : missedButton(p);
  await t.scrollUntilVisible(f, 160, scrollable: find.byType(Scrollable).first);
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> openDate(WidgetTester t, DateTime d) async {
  final f = date(dateKey(d));
  await t.scrollUntilVisible(
    f,
    -160,
    scrollable: find.byType(Scrollable).first,
  );
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

void main() {
  setUpAll(fonts);
  testWidgets(
    'calendar counts two misses and one unrecorded; navigation sums prayers and settles qada',
    (t) async {
      phone(t);
      final db = JournalDatabase(NativeDatabase.memory());
      final yesterday = DateTime(2026, 11, 13),
          previous = DateTime(2026, 11, 12);
      var j = Journal(startDate: previous);
      for (final d in [yesterday, previous]) {
        j = j.setStatuses(d, {
          for (final p in Prayer.values) p: PrayerStatus.performed,
        }, now);
      }
      j = j
          .setStatuses(yesterday, {
            Prayer.subuh: PrayerStatus.missed,
            Prayer.zohor: PrayerStatus.missed,
            Prayer.asar: PrayerStatus.unrecorded,
          }, now)
          .setStatuses(previous, {Prayer.isyak: PrayerStatus.unrecorded}, now);
      await db.save(j);
      try {
        await t.pumpWidget(app(db));
        await t.pumpAndSettle();
        expectCount(t, 2);
        await t.tap(find.text('History').last);
        await t.pumpAndSettle();
        final pending = find.byKey(
          const ValueKey('history-pending-2026-11-13'),
        );
        expect(
          find.descendant(of: pending, matching: find.text('2')),
          findsOneWidget,
        );
        expect(
          day(t, '2026-11-13').border!.top.color,
          badge(t).backgroundColor,
        );
        expect(find.text('Missed prayer records'), findsNothing);
        expect(find.text('Review unrecorded days'), findsNothing);
        await capture(t, 'history-pending-prayer-counts');
        await tapMark(t, Prayer.asar);
        expectCount(t, 2);
        await tapMark(t, Prayer.subuh);
        expectCount(t, 1);
        await tapMark(t, Prayer.zohor);
        expectCount(t, 0);
        expect((await db.load(now)).outstanding, 0);
        await openDate(t, yesterday);
        expect(
          find.byKey(const ValueKey('history-completed-2026-11-13')),
          findsOneWidget,
        );
        expect(pending, findsNothing);
        await capture(t, 'history-prayer-counts');
        await tapMark(
          t,
          Prayer.zohor,
        ); // Selected Done clears both the miss and replacement.
        expectCount(t, 0);
        expect(
          (await db.load(now)).status(yesterday, Prayer.zohor),
          PrayerStatus.unrecorded,
        );
        expect((await db.load(now)).balance(Prayer.zohor), 0);
        await openDate(t, previous);
        await tapMark(t, Prayer.isyak);
        expectCount(t, 0);
        await openDate(t, yesterday);
        await tapMark(t, Prayer.zohor);
        expectCount(t, 0);
        expect(t.takeException(), isNull);
      } finally {
        await t.pumpWidget(const SizedBox());
        await db.close();
      }
    },
  );
  testWidgets(
    'optional historical backfill counts unresolved prayers without creating intervening dates',
    (t) async {
      phone(t);
      final db = JournalDatabase(NativeDatabase.memory());
      await db.save(Journal(startDate: dayOnly(now)));
      final earlier = DateTime(2026, 11, 10);
      try {
        await t.pumpWidget(app(db));
        await t.pumpAndSettle();
        expectCount(t, 0);
        await t.tap(find.text('History').last);
        await t.pumpAndSettle();
        await openDate(t, earlier);
        await tapMark(t, Prayer.subuh);
        expectCount(t, 0);
        for (final p in Prayer.values.skip(1)) {
          await tapMark(t, p);
        }
        expectCount(t, 0);
        final saved = await db.load(now);
        expect(saved.startDate, dayOnly(now));
        expect(saved.records.keys, [dateKey(earlier)]);
        expect(saved.outstanding, 0);
        expect(find.text('Review unrecorded days'), findsNothing);
      } finally {
        await t.pumpWidget(const SizedBox());
        await db.close();
      }
    },
  );
  testWidgets(
    'midnight, resume gaps and restart derive prayer counts across months without creating misses',
    (t) async {
      phone(t);
      var clock = DateTime(2026, 11, 30, 23, 59, 59);
      final db = JournalDatabase(NativeDatabase.memory());
      await db.save(
        Journal(
          startDate: dayOnly(clock),
        ).setStatuses(clock, {Prayer.subuh: PrayerStatus.performed}, clock),
      );
      try {
        await t.pumpWidget(app(db, clock: () => clock));
        await t.pumpAndSettle();
        expectCount(t, 0);
        clock = DateTime(2026, 12, 1);
        await t.pump(const Duration(seconds: 2));
        await t.pumpAndSettle();
        expectCount(t, 0);
        clock = DateTime(2026, 12, 4);
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await t.pumpAndSettle();
        expectCount(t, 0);
        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(app(db, clock: () => clock));
        await t.pumpAndSettle();
        expectCount(t, 0);
        expect((await db.load(clock)).outstanding, 0);
        await t.tap(find.text('History').last);
        await t.pumpAndSettle();
        expect(
          t.widget<HistoryCalendar>(find.byType(HistoryCalendar)).selectedDate,
          DateTime(2026, 12, 3),
        );
        expect(
          find.byKey(const ValueKey('history-pending-2026-12-03')),
          findsNothing,
        );
        expect(t.takeException(), isNull);
      } finally {
        await t.pumpWidget(const SizedBox());
        await db.close();
      }
    },
  );
  testWidgets(
    'calendar retains leap years, year boundaries, date jumping and supported bounds',
    (tester) async {
      phone(tester);
      var selected = DateTime(2024, 2, 29);
      final today = DateTime(2024, 3, 1);
      await tester.pumpWidget(
        MaterialApp(
          theme: QadaTheme.build(Brightness.light),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => HistoryCalendar(
                selectedDate: selected,
                today: today,
                pendingPrayerCounts: {DateTime(2024, 2, 28): 5},
                onDateChanged: (value) => setState(() => selected = value),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(date('2024-02-29'), findsOneWidget);
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      expect(find.text('December 2023'), findsOneWidget);
      Future<void> jump(String value) async {
        await tester.tap(find.byKey(const ValueKey('history-choose-date')));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Switch to input'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), value);
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
      }

      await jump('01/01/1900');
      expect(selected, earliestJournalDay);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Previous month',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      expect(date('1900-02-29'), findsNothing);
      expect(date('1900-02-28'), findsOneWidget);
      await jump('03/01/2024');
      expect(selected, today);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Next month',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(tester.widget<InkWell>(date('2024-03-02')).onTap, isNull);
      await tester.tap(find.byKey(const ValueKey('history-choose-date')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(selected, today);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final mode in [AppTheme.light, AppTheme.dark]) {
    testWidgets(
      'exact large badge and calendar remain usable with large text in ${mode.name}',
      (tester) async {
        phone(tester, narrow: true);
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(
              highContrast: true,
              disableAnimations: true,
            );
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final semantics = tester.ensureSemantics();

        final db = JournalDatabase(NativeDatabase.memory());
        final start = DateTime(2020, 1, 1);
        var journal = Journal(startDate: start, theme: mode);
        for (var i = 1; i <= 201; i++) {
          final day = DateTime(now.year, now.month, now.day - i);
          journal = journal.setStatuses(day, {
            for (final p in Prayer.values) p: PrayerStatus.missed,
          }, now);
        }
        await db.save(journal);
        try {
          await tester.pumpWidget(app(db));
          await tester.pumpAndSettle();
          final expected = (await db.load(
            now,
          )).pendingPrayerCounts(now).values.fold<int>(0, (sum, n) => sum + n);
          expectCount(tester, expected);
          expect(expected, greaterThan(999));
          expect(
            find.bySemanticsLabel(
              'History, $expected missed prayers awaiting qada',
            ),
            findsOneWidget,
          );
          await capture(tester, 'history-badge-narrow-${mode.name}');
          await tester.tap(find.text('History').last);
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            date('2026-11-13'),
            180,
            scrollable: find.byType(Scrollable).first,
          );
          expect(
            day(tester, '2026-11-13').border!.top.color,
            badge(tester).backgroundColor,
          );
          expect(
            find.bySemanticsLabel(
              RegExp('November 13, 2026.*5 missed prayers awaiting qada'),
            ),
            findsOneWidget,
          );
          await capture(tester, 'history-calendar-narrow-${mode.name}');
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
          await tester.pumpWidget(const SizedBox());
          await db.close();
        }
      },
    );
  }
}
