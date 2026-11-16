import 'package:intl/intl.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qada_tracker/database.dart';
import 'package:qada_tracker/model.dart';
import 'package:qada_tracker/ui/history_calendar.dart';
import 'package:qada_tracker/ui/settings_group.dart';
import 'support/prayer_actions.dart';
import 'ui_refinements_test.dart' show app, now, phone, scrollTo, tap;
import 'theme_ui_test.dart' show fonts, capture;

void main() {
  setUpAll(fonts);
  testWidgets(
    'large Malay text keeps the missed-date dialog and navigation usable',
    (t) async {
      phone(t);
      t.view.physicalSize = const Size(320, 568);
      t.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      final db = JournalDatabase(NativeDatabase.memory());
      final missed = DateTime(2026, 11, 15);
      await db.save(
        Journal(
          startDate: missed,
          language: AppLanguage.ms,
        ).setStatuses(missed, {Prayer.subuh: PrayerStatus.missed}, now),
      );
      try {
        await t.pumpWidget(app(db));
        await t.pumpAndSettle();
        await tap(t, find.text('Qada').last);
        await tap(t, find.byKey(const ValueKey('qada-balance-subuh')));
        expect(find.text('Subuh · baki qada'), findsOneWidget);
        final dateLabel = find.text(DateFormat.yMMMd('ms').format(missed));
        expect(t.getSize(dateLabel).width, greaterThan(130));
        expect(t.getSize(dateLabel).height, lessThan(70));
        expect(
          find
              .byKey(const ValueKey('open-miss-2026-11-15-subuh'))
              .hitTestable(),
          findsOneWidget,
        );
        await capture(t, 'qada-dialog-narrow-malay');
        await tap(t, find.byKey(const ValueKey('open-miss-2026-11-15-subuh')));
        expect(
          t.widget<HistoryCalendar>(find.byType(HistoryCalendar)).selectedDate,
          missed,
        );
        expect(find.text('Sejarah'), findsWidgets);
        expect(t.takeException(), isNull);
      } finally {
        await t.pumpWidget(const SizedBox());
        await db.close();
      }
    },
  );
  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets(
      'Done and Missed toggle immediately and keep linked qada coherent ${theme.name}',
      (t) async {
        phone(t);
        final db = JournalDatabase(NativeDatabase.memory());
        await db.save(Journal(startDate: dayOnly(now), theme: theme));
        try {
          await t.pumpWidget(app(db));
          await t.pumpAndSettle();
          expect(find.byType(Checkbox), findsNothing);
          expect(find.byType(PopupMenuButton<PrayerStatus>), findsNothing);
          final done = doneButton(Prayer.subuh),
              missed = missedButton(Prayer.subuh);
          await tap(t, done);
          expect(
            (await db.load(now)).status(now, Prayer.subuh),
            PrayerStatus.performed,
          );
          expect(actionSelected(t, done), isTrue);
          await tap(t, done);
          expect(
            (await db.load(now)).status(now, Prayer.subuh),
            PrayerStatus.unrecorded,
          );
          await tap(t, missed);
          expect(find.byType(AlertDialog), findsNothing);
          expect((await db.load(now)).balance(Prayer.subuh), 1);
          expect(actionSelected(t, missed), isTrue);
          await capture(t, 'today-missed-buttons-${theme.name}');
          await tap(t, missed);
          expect(
            (await db.load(now)).status(now, Prayer.subuh),
            PrayerStatus.unrecorded,
          );
          await tap(t, missed);
          await tap(t, done);
          var saved = await db.load(now);
          expect(saved.status(now, Prayer.subuh), PrayerStatus.missed);
          expect(saved.replacements.length, 1);
          expect(saved.balance(Prayer.subuh), 0);
          expect(actionSelected(t, done), isTrue);
          expect(actionSelected(t, missed), isFalse);
          await capture(t, 'today-qada-buttons-${theme.name}');
          await tap(
            t,
            missed,
          ); // Reopens the miss by undoing its exact replacement.
          expect((await db.load(now)).balance(Prayer.subuh), 1);
          await tap(t, done);
          await tap(t, done); // Qada, then clear to Unrecorded.
          saved = await db.load(now);
          expect(saved.status(now, Prayer.subuh), PrayerStatus.unrecorded);
          expect(saved.replacements, isEmpty);
          expect(saved.balance(Prayer.subuh), 0);
          expect(t.takeException(), isNull);
        } finally {
          await t.pumpWidget(const SizedBox());
          await db.close();
        }
      },
    );
    testWidgets(
      'Qada balance lists newest dates first and opens exact History month ${theme.name}',
      (t) async {
        phone(t);
        final db = JournalDatabase(NativeDatabase.memory());
        final dates = [
          DateTime(2026, 11, 15),
          DateTime(2026, 11, 13),
          DateTime(2026, 10, 29),
        ];
        var j = Journal(startDate: dates.first, theme: theme);
        for (final d in dates) {
          j = j.setStatuses(d, {
            for (final p in Prayer.values)
              p: p == Prayer.subuh
                  ? PrayerStatus.missed
                  : PrayerStatus.performed,
          }, now);
        }
        await db.save(j);
        try {
          await t.pumpWidget(app(db));
          await t.pumpAndSettle();
          await tap(t, find.text('Qada').last);
          await tap(t, find.byKey(const ValueKey('qada-balance-subuh')));
          final entries = find.byWidgetPredicate(
            (w) =>
                w is TextButton &&
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith('open-miss-'),
          );
          expect(
            entries
                .evaluate()
                .map((e) => (e.widget.key! as ValueKey<String>).value)
                .toList(),
            [for (final d in dates) 'open-miss-${dateKey(d)}-subuh'],
          );
          await capture(t, 'qada-dates-${theme.name}');
          await tap(
            t,
            find.byKey(const ValueKey('open-miss-2026-10-29-subuh')),
          );
          final calendar = t.widget<HistoryCalendar>(
            find.byType(HistoryCalendar),
          );
          expect(calendar.selectedDate, dates.last);
          expect(find.text('October 2026'), findsOneWidget);
          expect(find.text('Missed prayer records'), findsNothing);
          expect(find.text('Review unrecorded days'), findsNothing);
          await scrollTo(t, doneButton(Prayer.subuh, dates.last));
          await tap(t, doneButton(Prayer.subuh, dates.last));
          expect((await db.load(now)).balance(Prayer.subuh), 2);
          expect(
            (await db.load(now)).replacementFor(dates.last, Prayer.subuh),
            isNotNull,
          );
          await tap(t, find.text('Qada').last);
          await scrollTo(t, find.text('Progress'));
          expect(find.byKey(const ValueKey('history-page')), findsNothing);
          await capture(t, 'qada-progress-${theme.name}');
          expect(t.takeException(), isNull);
        } finally {
          await t.pumpWidget(const SizedBox());
          await db.close();
        }
      },
    );
    testWidgets(
      'Settings is a navigation destination with consistent grouped icon rows ${theme.name}',
      (t) async {
        phone(t);
        final db = JournalDatabase(NativeDatabase.memory());
        await db.save(Journal(startDate: dayOnly(now), theme: theme));
        try {
          await t.pumpWidget(app(db));
          await t.pumpAndSettle();
          expect(
            find.descendant(
              of: find.byType(AppBar),
              matching: find.byIcon(Icons.settings_outlined),
            ),
            findsNothing,
          );
          await tap(t, find.text('Settings').last);
          expect(find.byKey(const ValueKey('settings-page')), findsOneWidget);
          await capture(t, 'settings-organized-${theme.name}');
          for (final title in [
            'Language / Bahasa',
            'Dark mode',
            'Prayer times & location',
            'Menstrual period & tracking pause',
            'Daily check-in reminder',
            'Export backup',
            'Restore backup',
            'App walkthrough',
          ]) {
            await scrollTo(t, find.text(title));
            final row = find
                .ancestor(of: find.text(title), matching: find.byType(ListTile))
                .first;
            final icon = find.descendant(
              of: row,
              matching: find.byType(SettingsIcon),
            );
            expect(icon, findsOneWidget, reason: title);
            expect(t.getRect(icon).left, closeTo(36, .1), reason: title);
            expect(
              DefaultTextStyle.of(t.element(find.text(title))).style.fontSize,
              16,
              reason: title,
            );
          }
          expect(t.takeException(), isNull);
        } finally {
          await t.pumpWidget(const SizedBox());
          await db.close();
        }
      },
    );
  }
}
