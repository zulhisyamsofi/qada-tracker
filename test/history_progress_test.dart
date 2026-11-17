import 'support/prayer_actions.dart';
import 'dart:io';
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
import 'theme_ui_test.dart' show fonts;

final now = DateTime(2026, 11, 14, 12);
Widget journalApp(JournalDatabase db) => ProviderScope(
  overrides: [
    databaseProvider.overrideWith((ref) async => db),
    clockProvider.overrideWithValue(() => now),
    fakePrayerTimes,
  ],
  child: const QadaApp(),
);

void phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUpAll(fonts);
  testWidgets('weekly and monthly Progress cards use the full content width', (
    tester,
  ) async {
    phoneSize(tester);
    final db = JournalDatabase(NativeDatabase.memory());
    await db.save(Journal(startDate: dayOnly(now)));
    await tester.pumpWidget(journalApp(db));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Qada').last);
    await tester.pumpAndSettle();
    void fullWidthMetrics({required bool last}) {
      for (final label in [
        'Prayers performed',
        'Qada replacements completed',
        'Unrecorded prayers',
      ]) {
        final text = last ? find.text(label).last : find.text(label).first;
        final card = find
            .ancestor(of: text, matching: find.byType(GlassCard))
            .first;
        final rect = tester.getRect(card);
        expect(rect.left, closeTo(20, .1));
        expect(rect.width, closeTo(350, .1));
      }
    }

    fullWidthMetrics(last: false);
    await tester.scrollUntilVisible(find.text('November 2026'), 200);
    await tester.pumpAndSettle();
    fullWidthMetrics(last: true);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await db.close();
  });

  testWidgets(
    'past calendar dates can be maintained and survive a restart without filling gaps',
    (tester) async {
      phoneSize(tester);
      final directory = Directory.systemTemp.createTempSync('qada-backfill-');
      final file = File('${directory.path}/journal.sqlite');
      var db = JournalDatabase(NativeDatabase(file));
      final old = DateTime(2026, 11, 12);
      await db.save(Journal(startDate: dayOnly(now)));
      try {
        await tester.pumpWidget(journalApp(db));
        await tester.pumpAndSettle();
        await tester.tap(find.text('History').last);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('history-date-2026-11-12')),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('history-date-2026-11-12')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('history-date-2026-11-12')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<HistoryCalendar>(find.byType(HistoryCalendar))
              .selectedDate,
          old,
        );
        final subuh = doneButton(Prayer.subuh);
        final historyScroll = find.byType(Scrollable).first;
        await tester.scrollUntilVisible(subuh, 150, scrollable: historyScroll);
        await tester.pumpAndSettle();
        await tester.tap(subuh);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          missedButton(Prayer.zohor),
          150,
          scrollable: historyScroll,
        );
        await tester.ensureVisible(missedButton(Prayer.zohor));
        await tester.pumpAndSettle();
        await tester.tap(missedButton(Prayer.zohor));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        var j = await db.load(now);
        expect(j.startDate, dayOnly(now));
        expect(j.status(old, Prayer.subuh), PrayerStatus.performed);
        expect(j.status(old, Prayer.zohor), PrayerStatus.missed);
        expect(j.outstanding, 1);
        expect(j.days(now).map(dateKey), ['2026-11-12', '2026-11-14']);
        expect(j.records.containsKey('2026-11-13'), isFalse);
        await tester.pumpWidget(const SizedBox());
        await db.close();
        db = JournalDatabase(NativeDatabase(file));
        await tester.pumpWidget(journalApp(db));
        await tester.pumpAndSettle();
        expect(find.text('1 day needs review'), findsNothing);
        j = await db.load(now);
        expect(j.status(old, Prayer.subuh), PrayerStatus.performed);
        expect(j.status(old, Prayer.zohor), PrayerStatus.missed);
        expect(Journal.decode(j.export(), now).toJson(), j.toJson());
        await tester.tap(find.text('History').last);
        await tester.pumpAndSettle();
        expect(find.text('1 day needs review'), findsNothing);
        expect(
          (tester
                      .widget<Badge>(
                        find.byKey(const ValueKey('history-review-badge')),
                      )
                      .label!
                  as Text)
              .data,
          '1',
        );
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('history-date-2026-11-12')),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('history-date-2026-11-12')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('history-date-2026-11-12')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<HistoryCalendar>(find.byType(HistoryCalendar))
              .selectedDate,
          old,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await db.close();
        directory.deleteSync(recursive: true);
      }
    },
  );
}
