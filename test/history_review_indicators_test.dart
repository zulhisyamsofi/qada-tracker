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
Future<void> checkbox(WidgetTester tester, Prayer prayer) async {
  final target = find.byWidgetPredicate(
    (w) => w is Checkbox && w.semanticLabel == '${prayer.label} performed',
  );
  await tester.scrollUntilVisible(
    target,
    140,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(fonts);
  testWidgets(
    'badge counts days rather than prayers; red markers and count follow partial and complete corrections',
    (tester) async {
      phone(tester);
      final db = JournalDatabase(NativeDatabase.memory());
      final yesterday = DateTime(2026, 11, 13);
      final previous = DateTime(2026, 11, 12);
      final oneDay = Journal(startDate: yesterday).setStatuses(yesterday, {
        for (final p in Prayer.values)
          p: [Prayer.subuh, Prayer.zohor].contains(p)
              ? PrayerStatus.unrecorded
              : PrayerStatus.performed,
      }, now);
      await db.save(oneDay);
      try {
        await tester.pumpWidget(app(db));
        await tester.pumpAndSettle();
        expectCount(tester, 1); // Two unrecorded prayers, one past day.
        final twoDays = Journal(startDate: previous, records: oneDay.records)
            .setStatuses(previous, {
              for (final p in Prayer.values)
                p: p == Prayer.asar
                    ? PrayerStatus.unrecorded
                    : PrayerStatus.performed,
            }, now);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(QadaApp)),
        );
        await container.read(journalProvider.notifier).restore(twoDays);
        await tester.pumpAndSettle();
        expectCount(tester, 2);
        await tester.tap(find.text('Records').last);
        await tester.pumpAndSettle();
        await capture(tester, 'history-calendar-standard');
        final red = badge(tester).backgroundColor;
        expect(day(tester, '2026-11-13').border!.top.color, red);
        expect(day(tester, '2026-11-12').border!.top.color, red);
        expect(
          day(tester, '2026-11-14').border!.top.color,
          isNot(red),
        ); // Today opens the checklist; no review ring.
        expect(
          day(tester, '2026-11-10').border,
          isNull,
        ); // Untouched pre-start date.
        expect(tester.widget<InkWell>(date('2026-11-15')).onTap, isNull);
        await tester.scrollUntilVisible(
          date('2026-11-13'),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(date('2026-11-13'));
        await tester.pumpAndSettle();
        await tester.tap(date('2026-11-13'));
        await tester.pumpAndSettle();
        expect(
          day(tester, '2026-11-13').border!.top.color,
          red,
        ); // Selection retains red ring.
        await capture(tester, 'history-calendar-selected-review');
        await checkbox(tester, Prayer.subuh);
        expectCount(tester, 2); // One unresolved prayer remains on yesterday.
        await tester.ensureVisible(find.byTooltip('Update Zohor'));
        await tester.tap(find.byTooltip('Update Zohor'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mark missed'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
        await tester.pumpAndSettle();
        expectCount(tester, 1);
        await tester.scrollUntilVisible(
          date('2026-11-13'),
          -180,
          scrollable: find.byType(Scrollable).first,
        );
        expect(day(tester, '2026-11-13').border, isNull);
        expect(day(tester, '2026-11-12').border!.top.color, red);
        expect((await db.load(now)).outstanding, 1);
        await checkbox(
          tester,
          Prayer.subuh,
        ); // Clearing a completed prayer reopens the day.
        expectCount(tester, 2);
        await tester.scrollUntilVisible(
          date('2026-11-13'),
          -180,
          scrollable: find.byType(Scrollable).first,
        );
        expect(day(tester, '2026-11-13').border!.top.color, red);
        expect((await db.load(now)).outstanding, 1);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await db.close();
      }
    },
  );

  testWidgets(
    'explicit historical backfill joins the badge; bulk review removes resolved markers and zero hides the badge',
    (tester) async {
      phone(tester);
      final db = JournalDatabase(NativeDatabase.memory());
      final old = DateTime(2026, 11, 5);
      final j = Journal(startDate: DateTime(2026, 11, 12))
          .setStatuses(old, {Prayer.subuh: PrayerStatus.performed}, now)
          .setStatuses(DateTime(2026, 11, 12), {
            for (final p in Prayer.values) p: PrayerStatus.performed,
          }, now);
      await db.save(
        j,
      ); // Nov 5 and Nov 13 are unresolved; the pre-start gap is untouched.
      try {
        await tester.pumpWidget(app(db));
        await tester.pumpAndSettle();
        expectCount(tester, 2);
        await tester.tap(find.text('Records').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('2 days need review'));
        await tester.pumpAndSettle();
        final bulk = find.text('Remaining missed').last;
        await tester.scrollUntilVisible(
          bulk,
          200,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(bulk);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
        await tester.pumpAndSettle();
        expectCount(tester, 1);
        expect((await db.load(now)).outstanding, 4);
        Navigator.of(tester.element(find.text('A moment to review'))).pop();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Records').last);
        await tester.pumpAndSettle();
        expect(day(tester, '2026-11-05').border, isNull);
        expect(day(tester, '2026-11-10').border, isNull);
        expect(day(tester, '2026-11-13').border, isNotNull);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(QadaApp)),
        );
        await container.read(journalProvider.notifier).statuses(
          DateTime(2026, 11, 13),
          {for (final p in Prayer.values) p: PrayerStatus.performed},
        );
        await tester.pumpAndSettle();
        expectCount(tester, 0);
        expect(day(tester, '2026-11-13').border, isNull);
        expect(
          (await db.load(now)).outstanding,
          4,
        ); // Confirmed misses remain, but have no unrecorded marker.
      } finally {
        await tester.pumpWidget(const SizedBox());
        await db.close();
      }
    },
  );

  testWidgets(
    'open midnight, resume gaps, and reopening derive the badge across month boundaries without creating misses',
    (tester) async {
      phone(tester);
      var time = DateTime(2026, 1, 31, 23, 59, 59);
      final db = JournalDatabase(NativeDatabase.memory());
      await db.save(Journal(startDate: dayOnly(time)));
      try {
        await tester.pumpWidget(app(db, clock: () => time));
        await tester.pumpAndSettle();
        expectCount(tester, 0);
        time = DateTime(2026, 2, 1);
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expectCount(tester, 1);
        await tester.tap(find.text('Records').last);
        await tester.pumpAndSettle();
        expect(find.text('January 2026'), findsOneWidget);
        expect(
          day(tester, '2026-01-31').border!.top.color,
          badge(tester).backgroundColor,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        time = DateTime(2026, 2, 3);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expectCount(tester, 3);
        await tester.pumpWidget(const SizedBox());
        time = DateTime(2026, 2, 5);
        await tester.pumpWidget(app(db, clock: () => time));
        await tester.pumpAndSettle();
        expectCount(tester, 5);
        expect((await db.load(time)).outstanding, 0);
        expect((await db.load(time)).records, isEmpty);
      } finally {
        await tester.pumpWidget(const SizedBox());
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
                unrecordedDays: {DateTime(2024, 2, 28)},
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
        await db.save(Journal(startDate: start, theme: mode));
        try {
          await tester.pumpWidget(app(db));
          await tester.pumpAndSettle();
          final expected = (await db.load(now)).unresolvedDays(now).length;
          expectCount(tester, expected);
          expect(expected, greaterThan(999));
          expect(
            find.bySemanticsLabel(
              'Records, $expected past days with unrecorded prayers',
            ),
            findsOneWidget,
          );
          await capture(tester, 'history-badge-narrow-${mode.name}');
          await tester.tap(find.text('Records').last);
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
              RegExp('November 13, 2026.*has unrecorded prayers'),
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
