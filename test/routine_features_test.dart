import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qada_tracker/controller.dart';
import 'package:qada_tracker/database.dart';
import 'package:qada_tracker/model.dart';

final now = DateTime(2026, 11, 18, 22);
final start = DateTime(2026, 11, 14);
void main() {
  test(
    'rapid +1 completion stays nonnegative and Undo identifies only its original entry at a frozen clock',
    () async {
      final db = JournalDatabase(NativeDatabase.memory());
      await db.save(
        Journal(startDate: start).setStarting({
          for (final p in Prayer.values) p: p == Prayer.subuh ? 2 : 0,
        }),
      );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith((ref) async => db),
          clockProvider.overrideWithValue(() => now),
        ],
      );
      final listener = container.listen(journalProvider, (_, _) {});
      try {
        await container.read(journalProvider.future);
        final c = container.read(journalProvider.notifier);
        final ids = await Future.wait([
          c.complete(Prayer.subuh, 1),
          c.complete(Prayer.subuh, 1),
        ]);
        expect(ids.toSet().length, 2);
        expect((await db.load(now)).balance(Prayer.subuh), 0);
        await expectLater(c.complete(Prayer.subuh, 1), throwsStateError);
        await c.change((j) => j.undo(ids.last));
        expect((await db.load(now)).replacements.single.id, ids.first);
        final newId = await c.complete(Prayer.subuh, 1);
        expect(ids, isNot(contains(newId)));
        await c.change((j) => j.undo(ids.last));
        expect((await db.load(now)).replacements.map((e) => e.id), [
          ids.first,
          newId,
        ]);
        expect(
          (await db.load(now)).status(now, Prayer.subuh),
          PrayerStatus.unrecorded,
        );
      } finally {
        listener.close();
        container.dispose();
        await db.close();
      }
    },
  );
}
