import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qada_tracker/controller.dart';
import 'package:qada_tracker/database.dart';
import 'package:qada_tracker/main.dart';
import 'package:qada_tracker/model.dart';
import 'package:qada_tracker/ui/glass.dart';
import 'package:qada_tracker/ui/history_calendar.dart';
import 'support/prayer_times.dart';
import 'theme_ui_test.dart' show fonts, capture, captureKey;

final now = DateTime(2026, 11, 16, 10);
Widget app(JournalDatabase db) => ProviderScope(
  overrides: [
    databaseProvider.overrideWith((ref) async => db),
    clockProvider.overrideWithValue(() => now),
    fakePrayerTimes,
  ],
  child: RepaintBoundary(key: captureKey, child: const QadaApp()),
);
Future<void> tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> scrollTo(WidgetTester t, Finder f) async {
  await t.scrollUntilVisible(f, 180, scrollable: find.byType(Scrollable).first);
  await t.ensureVisible(f);
  await t.pumpAndSettle();
}

void phone(WidgetTester t) {
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

void main() {
  setUpAll(fonts);
  testWidgets(
    'Today missed checkbox respects prayer start and dismisses its error',
    (t) async {
      phone(t);
      final db = JournalDatabase(NativeDatabase.memory());
      await db.save(
        Journal(
          startDate: dayOnly(now),
        ).setStatuses(now, {Prayer.isyak: PrayerStatus.missed}, now),
      );
      final card = find.byKey(const ValueKey('prayer-card-2026-11-16-isyak'));
      final checkbox = find.descendant(
        of: card,
        matching: find.byType(Checkbox),
      );
      try {
        await t.pumpWidget(app(db));
        await t.pumpAndSettle();
        await tap(t, checkbox);
        expect((await db.load(now)).replacements, isEmpty);
        expect((await db.load(now)).balance(Prayer.isyak), 1);
        expect(t.widget<Checkbox>(checkbox).value, isFalse);
        expect(find.textContaining('Isyak starts at'), findsOneWidget);
        await t.pump(const Duration(seconds: 5));
        await t.pumpAndSettle();
        expect(find.byType(SnackBar), findsNothing);
        expect(t.takeException(), isNull);
      } finally {
        await t.pumpWidget(const SizedBox());
        await db.close();
      }
    },
  );
  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets(
      'Today missed checkbox completes dated qada and message expires ${theme.name}',
      (t) async {
        phone(t);
        final db = JournalDatabase(NativeDatabase.memory());
        await db.save(
          Journal(
            startDate: dayOnly(now),
            theme: theme,
          ).setStatuses(now, {Prayer.subuh: PrayerStatus.missed}, now),
        );
        final card = find.byKey(const ValueKey('prayer-card-2026-11-16-subuh'));
        Finder checkbox() =>
            find.descendant(of: card, matching: find.byType(Checkbox));
        try {
          await t.pumpWidget(app(db));
          await t.pumpAndSettle();
          expect(find.text('Complete qada'), findsNothing);
          await tap(t, checkbox());
          final saved = await db.load(now);
          expect(saved.status(now, Prayer.subuh), PrayerStatus.missed);
          expect(
            saved.balance(Prayer.subuh),
            0,
            reason: find
                .byType(SnackBar)
                .evaluate()
                .map((e) => ((e.widget as SnackBar).content as Text).data)
                .join(' / '),
          );
          expect(saved.replacements.single.missedDate, dayOnly(now));
          expect(t.widget<Checkbox>(checkbox()).value, isTrue);
          expect(
            find.descendant(of: card, matching: find.text('Qada completed')),
            findsOneWidget,
          );
          expect(find.text('Undo qada'), findsNothing);
          final bar = t.widget<SnackBar>(find.byType(SnackBar));
          expect(bar.persist, isFalse);
          expect(bar.action, isNotNull);
          await t.pump(const Duration(seconds: 5));
          await t.pumpAndSettle();
          expect(find.byType(SnackBar), findsNothing);
          await capture(t, 'today-checkbox-qada-${theme.name}');
          await t.pumpWidget(const SizedBox());
          await t.pumpWidget(app(db));
          await t.pumpAndSettle();
          expect(t.widget<Checkbox>(checkbox()).value, isTrue);
          expect((await db.load(now)).replacements.length, 1);
          expect(find.text('Complete qada'), findsNothing);
          expect(find.text('Undo qada'), findsNothing);
          expect(t.takeException(), isNull);
        } finally {
          await t.pumpWidget(const SizedBox());
          await db.close();
        }
      },
    );
    testWidgets(
      'Records has plain balances, review spacing and exact five-prayer checkmarks ${theme.name}',
      (t) async {
        phone(t);
        final db = JournalDatabase(NativeDatabase.memory());
        final completed = DateTime(2026, 11, 15);
        final exempt = DateTime(2026, 11, 14);
        final pending = DateTime(2026, 11, 13);
        var journal = Journal(startDate: pending, theme: theme);
        for (final day in [now, completed, exempt, pending]) {
          journal = journal.setStatuses(day, {
            for (final p in Prayer.values) p: PrayerStatus.performed,
          }, now);
        }
        journal = journal
            .setStatuses(completed, {Prayer.subuh: PrayerStatus.missed}, now)
            .completeMiss(completed, Prayer.subuh, now, 'linked')
            .setStatuses(exempt, {Prayer.subuh: PrayerStatus.exempt}, now)
            .setStatuses(pending, {Prayer.subuh: PrayerStatus.missed}, now);
        await db.save(journal);
        try {
          await t.pumpWidget(app(db));
          await t.pumpAndSettle();
          await tap(t, find.text('Records').last);
          final title = find.text('Outstanding qada');
          expect(title, findsOneWidget);
          expect(
            find.ancestor(of: title, matching: find.byType(ExpansionTile)),
            findsNothing,
          );
          expect(
            find.ancestor(of: title, matching: find.byType(GlassCard)),
            findsNothing,
          );
          for (final p in Prayer.values) {
            final box = find.byKey(ValueKey('qada-balance-${p.name}'));
            expect(box, findsOneWidget);
            expect(t.getSize(box).width, lessThan(80));
            expect(
              find.descendant(of: box, matching: find.text(p.label)),
              findsNothing,
            );
            expect(
              find.descendant(
                of: box,
                matching: find.text('${journal.balance(p)}'),
              ),
              findsOneWidget,
            );
          }
          await capture(t, 'records-balances-${theme.name}');
          final calendar = find.byType(HistoryCalendar);
          await scrollTo(t, calendar);
          expect(
            find.byKey(const ValueKey('history-completed-2026-11-15')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('history-completed-2026-11-16')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('history-completed-2026-11-14')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('history-completed-2026-11-13')),
            findsNothing,
          );
          await capture(t, 'calendar-completions-${theme.name}');
          final container = ProviderScope.containerOf(
            t.element(find.byType(QadaApp)),
          );
          await container
              .read(journalProvider.notifier)
              .change((j) => j.undo('linked'));
          await t.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('history-completed-2026-11-15')),
            findsNothing,
          );
          final review = find.widgetWithText(
            OutlinedButton,
            'Review unrecorded days',
          );
          await scrollTo(t, review);
          final history = find
              .ancestor(
                of: find.text('Replacement history'),
                matching: find.byType(GlassCard),
              )
              .first;
          expect(
            t.getRect(history).top - t.getRect(review).bottom,
            greaterThanOrEqualTo(20),
          );
          expect(t.takeException(), isNull);
        } finally {
          await t.pumpWidget(const SizedBox());
          await db.close();
        }
      },
    );
  }
}
