import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qada_tracker/controller.dart';
import 'package:qada_tracker/database.dart';
import 'package:qada_tracker/model.dart';

void main() {
  test(
    'rapid changes serialize and failed changes do not poison the queue',
    () async {
      final db = JournalDatabase(NativeDatabase.memory());
      final now = DateTime(2026, 11, 13);
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith((ref) async => db),
          clockProvider.overrideWithValue(() => now),
        ],
      );
      final subscription = container.listen(journalProvider, (_, _) {});
      try {
        await container.read(journalProvider.future);
        final c = container.read(journalProvider.notifier);
        await Future.wait([
          c.statuses(now, {Prayer.subuh: PrayerStatus.performed}),
          c.statuses(now, {Prayer.zohor: PrayerStatus.missed}),
        ]);
        await c.complete(Prayer.zohor, 1);
        await expectLater(
          c.statuses(now, {Prayer.zohor: PrayerStatus.performed}),
          throwsStateError,
        );
        await c.statuses(now, {Prayer.asar: PrayerStatus.performed});
        final j = container.read(journalProvider).requireValue;
        expect(j.status(now, Prayer.subuh), PrayerStatus.performed);
        expect(j.status(now, Prayer.asar), PrayerStatus.performed);
        expect(j.status(now, Prayer.zohor), PrayerStatus.missed);
        expect(j.outstanding, 0);
        expect((await db.load(now)).toJson(), j.toJson());
      } finally {
        subscription.close();
        container.dispose();
        await db.close();
      }
    },
  );
}
