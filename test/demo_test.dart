import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qada_tracker/controller.dart';
import 'package:qada_tracker/database.dart';
import 'package:qada_tracker/main.dart' show QadaApp;
import 'package:qada_tracker/prayer_times_controller.dart';
import 'support/prayer_actions.dart';
import 'theme_ui_test.dart' show fonts;
import 'package:flutter_test/flutter_test.dart';
import 'package:qada_tracker/demo_main.dart';
import 'package:qada_tracker/model.dart';
import 'package:qada_tracker/prayer_times_models.dart';

void main() {
  setUpAll(fonts);
  testWidgets('demo frame resets edited prayers and sample balances', (
    t,
  ) async {
    final db = JournalDatabase(NativeDatabase.memory());
    final api = DemoTimesApi();
    await db.save(demoJournal());
    try {
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWith((ref) async => db),
            clockProvider.overrideWithValue(() => demoNow),
            prayerTimesApiProvider.overrideWithValue(api),
          ],
          child: QadaApp(frame: (_, child) => DemoFrame(child: child)),
        ),
      );
      await t.pumpAndSettle();
      final done = doneButton(Prayer.zohor, demoNow);
      await t.ensureVisible(done);
      await t.tap(done);
      await t.pumpAndSettle();
      expect(
        (await db.load(demoNow)).status(demoNow, Prayer.zohor),
        PrayerStatus.performed,
      );
      await t.tap(find.text('Reset demo'));
      await t.pumpAndSettle();
      final restored = await db.load(demoNow);
      expect(restored.status(demoNow, Prayer.zohor), PrayerStatus.unrecorded);
      expect(restored.balance(Prayer.subuh), 1);
      expect(restored.balance(Prayer.asar), 1);
      expect(t.takeException(), isNull);
    } finally {
      await t.pumpWidget(const SizedBox());
      api.client.close();
      await db.close();
    }
  });
  test('fresh demo has dated obligations but never counts unknown prayers', () {
    final journal = demoJournal();
    expect(journal.balance(Prayer.subuh), 1);
    expect(journal.balance(Prayer.asar), 1);
    expect(journal.balance(Prayer.zohor), 0);
    expect(journal.status(demoNow, Prayer.subuh), PrayerStatus.performed);
    expect(journal.status(demoNow, Prayer.zohor), PrayerStatus.unrecorded);
    expect(journal.walkthroughSeen, isTrue);
    expect(journal.reminderEnabled, isFalse);
    expect(journal.prayerTimes.notifications, isFalse);
  });

  test(
    'sample calendar covers demo with reached starts and matching source',
    () async {
      final api = DemoTimesApi();
      try {
        for (final place in [malaysiaPlaces.first, malaysiaPlaces.last]) {
          final calendar = await api.fetch(place, demoNow);
          expect(calendar.sourceKey, place.key);
          expect(calendar.fresh(demoNow), isTrue);
          final today = calendar.today(demoNow);
          expect(today, hasLength(5));
          expect(today.every((p) => !p.at.isAfter(demoNow)), isTrue);
        }
      } finally {
        api.client.close();
      }
    },
  );
}
