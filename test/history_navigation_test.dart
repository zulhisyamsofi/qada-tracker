import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qada_tracker/controller.dart';
import 'package:qada_tracker/database.dart';
import 'package:qada_tracker/main.dart';
import 'package:qada_tracker/model.dart';
import 'package:qada_tracker/ui/history_calendar.dart';
import 'support/prayer_times.dart';
import 'theme_ui_test.dart' show fonts, capture, captureKey;

final now = DateTime(2026, 11, 14, 23);
final yesterday = DateTime(2026, 11, 13);
Widget app(JournalDatabase db, DateTime Function() clock) => ProviderScope(
  overrides: [
    databaseProvider.overrideWith((ref) async => db),
    clockProvider.overrideWithValue(clock),
    fakePrayerTimes,
  ],
  child: RepaintBoundary(key: captureKey, child: const QadaApp()),
);
void phone(WidgetTester tester, {bool narrow = false}) {
  tester.view.physicalSize = Size(narrow ? 320 : 390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Finder card(DateTime date, Prayer p) =>
    find.byKey(ValueKey('prayer-card-${dateKey(date)}-${p.name}'));
Finder cell(DateTime date) =>
    find.byKey(ValueKey('history-date-${dateKey(date)}'));
Future<void> tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

HistoryCalendar calendar(WidgetTester tester) =>
    tester.widget<HistoryCalendar>(find.byType(HistoryCalendar));

void main() {
  setUpAll(fonts);
  for (final mode in [AppTheme.light, AppTheme.dark]) {
    testWidgets(
      'History defaults to yesterday and today opens Today without changing records ${mode.name}',
      (tester) async {
        phone(tester);
        final db = JournalDatabase(NativeDatabase.memory());
        final original = Journal(
          startDate: yesterday,
          theme: mode,
        ).setStatuses(now, {Prayer.subuh: PrayerStatus.performed}, now);
        await db.save(original);
        try {
          await tester.pumpWidget(app(db, () => now));
          await tester.pumpAndSettle();
          await tap(tester, find.text('History').last);
          expect(calendar(tester).selectedDate, yesterday);
          expect(card(dayOnly(now), Prayer.subuh), findsNothing);
          expect(card(yesterday, Prayer.subuh), findsOneWidget);
          expect(find.byKey(const ValueKey('history-first-day')), findsNothing);
          await capture(tester, 'history-yesterday-${mode.name}');
          final checkbox = find.descendant(
            of: card(yesterday, Prayer.subuh),
            matching: find.byType(Checkbox),
          );
          await tap(tester, checkbox);
          var saved = await db.load(now);
          expect(saved.status(yesterday, Prayer.subuh), PrayerStatus.performed);
          expect(saved.status(now, Prayer.subuh), PrayerStatus.performed);
          expect(saved.outstanding, 0);
          await tester.scrollUntilVisible(
            cell(dayOnly(now)),
            -180,
            scrollable: find.byType(Scrollable).first,
          );
          await tap(tester, cell(dayOnly(now)));
          expect(find.byType(HistoryCalendar), findsNothing);
          expect(card(dayOnly(now), Prayer.subuh), findsOneWidget);
          saved = await db.load(now);
          expect(saved.records.length, 2);
          await tap(tester, find.text('History').last);
          expect(calendar(tester).selectedDate, yesterday);
          expect(card(dayOnly(now), Prayer.subuh), findsNothing);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await db.close();
        }
      },
    );
  }
  testWidgets(
    'first-day History explains tomorrow, permits optional backfill, and routes its helper to Today',
    (tester) async {
      phone(tester, narrow: true);
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final db = JournalDatabase(NativeDatabase.memory());
      final original = Journal(startDate: dayOnly(now), theme: AppTheme.dark);
      await db.save(original);
      try {
        await tester.pumpWidget(app(db, () => now));
        await tester.pumpAndSettle();
        await tap(tester, find.text('History').last);
        expect(
          find.text('Your prayer history will appear here tomorrow.'),
          findsOneWidget,
        );
        expect(find.byType(Checkbox), findsNothing);
        expect((await db.load(now)).toJson(), original.toJson());
        await tester.scrollUntilVisible(
          find.text('Go to Today'),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await capture(tester, 'history-first-day-dark-large-text');
        await tap(tester, find.text('Go to Today'));
        expect(card(dayOnly(now), Prayer.subuh), findsOneWidget);
        await tap(tester, find.text('History').last);
        await tester.scrollUntilVisible(
          cell(yesterday),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        expect(calendar(tester).showSelection, isFalse);
        await tap(tester, cell(yesterday));
        expect(find.byKey(const ValueKey('history-first-day')), findsNothing);
        final checkbox = find.descendant(
          of: card(yesterday, Prayer.subuh),
          matching: find.byType(Checkbox),
        );
        await tap(tester, checkbox);
        expect(
          (await db.load(now)).status(yesterday, Prayer.subuh),
          PrayerStatus.performed,
        );
        expect((await db.load(now)).startDate, dayOnly(now));
        expect(
          (await db.load(now)).status(now, Prayer.subuh),
          PrayerStatus.unrecorded,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await db.close();
      }
    },
  );
  testWidgets(
    'date picker cancellation preserves History and choosing today routes without editing it',
    (tester) async {
      phone(tester);
      final db = JournalDatabase(NativeDatabase.memory());
      final original = Journal(startDate: yesterday);
      await db.save(original);
      try {
        await tester.pumpWidget(app(db, () => now));
        await tester.pumpAndSettle();
        await tap(tester, find.text('History').last);
        await tap(tester, find.byKey(const ValueKey('history-choose-date')));
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(calendar(tester).selectedDate, yesterday);
        await tap(tester, find.byKey(const ValueKey('history-choose-date')));
        await tester.tap(find.byTooltip('Switch to input'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '11/14/2026');
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        expect(find.byType(HistoryCalendar), findsNothing);
        expect(card(dayOnly(now), Prayer.subuh), findsOneWidget);
        expect((await db.load(now)).toJson(), original.toJson());
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await db.close();
      }
    },
  );
  testWidgets(
    'History first-day view becomes yesterday at midnight across a month boundary',
    (tester) async {
      phone(tester);
      var clock = DateTime(2026, 1, 31, 23, 59, 59);
      final db = JournalDatabase(NativeDatabase.memory());
      await db.save(Journal(startDate: dayOnly(clock)));
      try {
        await tester.pumpWidget(app(db, () => clock));
        await tester.pumpAndSettle();
        await tap(tester, find.text('History').last);
        expect(find.byKey(const ValueKey('history-first-day')), findsOneWidget);
        clock = DateTime(2026, 2, 1);
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(calendar(tester).selectedDate, DateTime(2026, 1, 31));
        expect(find.text('January 2026'), findsOneWidget);
        expect(find.byKey(const ValueKey('history-first-day')), findsNothing);
        expect(card(clock, Prayer.subuh), findsNothing);
        expect(card(DateTime(2026, 1, 31), Prayer.subuh), findsOneWidget);
        expect((await db.load(clock)).records, isEmpty);
        expect((await db.load(clock)).outstanding, 0);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await db.close();
      }
    },
  );
  testWidgets(
    'reopening after a multi-day gap selects yesterday and resume keeps selection in the past',
    (tester) async {
      phone(tester);
      var clock = DateTime(2026, 11, 14, 12);
      final db = JournalDatabase(NativeDatabase.memory());
      await db.save(Journal(startDate: dayOnly(clock)));
      try {
        await tester.pumpWidget(app(db, () => clock));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
        clock = DateTime(2026, 11, 17, 12);
        await tester.pumpWidget(app(db, () => clock));
        await tester.pumpAndSettle();
        await tap(tester, find.text('History').last);
        expect(calendar(tester).selectedDate, DateTime(2026, 11, 16));
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        clock = DateTime(2026, 11, 18, 12);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(calendar(tester).selectedDate, DateTime(2026, 11, 17));
        expect(card(dayOnly(clock), Prayer.subuh), findsNothing);
        expect((await db.load(clock)).records, isEmpty);
        expect((await db.load(clock)).unresolvedDays(clock).length, 4);
        expect((await db.load(clock)).outstanding, 0);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await db.close();
      }
    },
  );
}
