import 'dart:convert';
import 'dart:io';
import 'package:qada_tracker/prayer_times_models.dart';
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
  test(
    'legacy backups default to eleven PM and all selected prayer alerts',
    () {
      final root = Journal(startDate: start, reminderEnabled: true).toJson()
        ..remove('reminderMinutes');
      (root['prayerTimes'] as Map).remove('notificationMask');
      final j = Journal.decode(jsonEncode(root), now);
      expect(j.reminderEnabled, isTrue);
      expect(j.reminderMinutes, 1380);
      expect(j.prayerTimes.notificationMask, 31);
    },
  );
  test('reminder backups round trip and reject invalid times and masks', () {
    final j = Journal(
      startDate: start,
      reminderMinutes: 1275,
      prayerTimes: const PrayerTimeSettings(
        notifications: true,
        notificationMask: 9,
      ),
    );
    expect(Journal.decode(j.export(), now).toJson(), j.toJson());
    for (final value in [-1, 1440, '23:00', true]) {
      final root = j.toJson()..['reminderMinutes'] = value;
      expect(
        () => Journal.decode(jsonEncode(root), now),
        throwsA(anyOf(isA<FormatException>(), isA<StateError>())),
      );
    }
    for (final value in [-1, 32, '31', true]) {
      final root = j.toJson();
      (root['prayerTimes'] as Map)['notificationMask'] = value;
      expect(
        () => Journal.decode(jsonEncode(root), now),
        throwsFormatException,
      );
    }
  });
  test(
    'reminder preferences survive SQLite reopening and invalid writes roll back',
    () async {
      final dir = Directory.systemTemp.createTempSync('qada-reminder-release-');
      final file = File('${dir.path}/journal.sqlite');
      var db = JournalDatabase(NativeDatabase(file));
      try {
        final j = Journal(
          startDate: start,
          reminderMinutes: 1290,
          prayerTimes: const PrayerTimeSettings(notificationMask: 17),
        );
        await db.save(j);
        await db.close();
        db = JournalDatabase(NativeDatabase(file));
        expect((await db.load(now)).toJson(), j.toJson());
        await expectLater(
          db.change(now, (j) => j.copy(reminderMinutes: -1)),
          throwsStateError,
        );
        expect((await db.load(now)).toJson(), j.toJson());
      } finally {
        await db.close();
        dir.deleteSync(recursive: true);
      }
    },
  );
}
