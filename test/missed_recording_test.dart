import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qada_tracker/controller.dart';
import 'package:qada_tracker/database.dart';
import 'package:qada_tracker/main.dart';
import 'package:qada_tracker/model.dart';
import 'package:qada_tracker/prayer_times_controller.dart';
import 'prayer_times_controller_test.dart' show FakeTimesApi;
import 'support/prayer_actions.dart';
import 'support/prayer_times.dart';
import 'theme_ui_test.dart' show fonts;
import 'ui_refinements_test.dart' show phone, tap;

void main() {
  setUpAll(fonts);
  for (final language in AppLanguage.values) {
    testWidgets(
      'Missed is blocked early, saved at start, and can be cleared offline ${language.name}',
      (t) async {
        phone(t);
        var now = DateTime.utc(2026, 11, 13, 2);
        final day = dayOnly(now);
        final db = JournalDatabase(NativeDatabase.memory());
        final api = FakeTimesApi()..fail = true;
        final original = Journal(startDate: day, language: language);
        await db.save(original);
        await seedPrayerCalendar(db, now);
        try {
          await t.pumpWidget(
            ProviderScope(
              overrides: [
                databaseProvider.overrideWith((ref) async => db),
                clockProvider.overrideWithValue(() => now),
                prayerTimesApiProvider.overrideWithValue(api),
              ],
              child: const QadaApp(),
            ),
          );
          await t.pumpAndSettle();
          final missed = missedButton(Prayer.zohor, day);
          await tap(t, missed);
          expect((await db.load(now)).toJson(), original.toJson());
          expect(actionSelected(t, missed), isFalse);
          expect(find.textContaining('1:00 PM'), findsWidgets);
          expect(
            find.textContaining(
              language == AppLanguage.en
                  ? 'mark it missed then'
                  : 'menandakan tertinggal',
            ),
            findsOneWidget,
          );
          await t.pump(const Duration(seconds: 5));
          await t.pumpAndSettle();
          expect(find.byType(SnackBar), findsNothing);
          // The write must read the fresh clock, even without a resume/reopen.
          now = DateTime.utc(2026, 11, 13, 5);
          await tap(t, missed);
          expect(
            (await db.load(now)).status(day, Prayer.zohor),
            PrayerStatus.missed,
          );
          expect((await db.load(now)).balance(Prayer.zohor), 1);
          expect(actionSelected(t, missed), isTrue);
          // Clock corrections and loss of the cache must not prevent clearing a mark.
          now = DateTime.utc(2026, 11, 13, 2);
          await db.customStatement('DELETE FROM prayer_calendar');
          await tap(t, missed);
          expect(
            (await db.load(now)).status(day, Prayer.zohor),
            PrayerStatus.unrecorded,
          );
          expect((await db.load(now)).balance(Prayer.zohor), 0);
          expect(actionSelected(t, missed), isFalse);
          await tap(t, missed);
          expect(
            (await db.load(now)).status(day, Prayer.zohor),
            PrayerStatus.unrecorded,
          );
          expect(
            find.textContaining(
              language == AppLanguage.en
                  ? 'before marking Zohor missed'
                  : 'sebelum menandakan Zohor tertinggal',
            ),
            findsOneWidget,
          );
          expect(t.takeException(), isNull);
        } finally {
          await t.pumpWidget(const SizedBox());
          await db.close();
          api.client.close();
        }
      },
    );
  }
}
