import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qada_tracker/database.dart';
import 'package:qada_tracker/model.dart';

void main() {
  final now = DateTime(2026, 11, 13);
  test(
    'SQLite survives close/reopen and restores the full journal atomically',
    () async {
      final directory = await Directory.systemTemp.createTemp('qada-test-');
      final file = File('${directory.path}/journal.sqlite');
      var db = JournalDatabase(NativeDatabase(file));
      try {
        final first = await db.load(now);
        final updated = first
            .setStatuses(now, {Prayer.subuh: PrayerStatus.missed}, now)
            .complete(Prayer.subuh, 1, now, 'one')
            .copy(theme: AppTheme.dark);
        await db.save(updated);
        await db.close();
        db = JournalDatabase(NativeDatabase(file));
        expect(
          (await db.load(now.add(const Duration(days: 4)))).toJson(),
          updated.toJson(),
        );
        final replacement = Journal(
          startDate: now.subtract(const Duration(days: 1)),
        );
        await db.save(replacement);
        expect((await db.load(now)).toJson(), replacement.toJson());
      } finally {
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );
  test(
    'a failed transactional replacement leaves the previous journal intact',
    () async {
      final db = JournalDatabase(NativeDatabase.memory());
      try {
        final original = await db.load(now);
        await db.customStatement(
          "CREATE TRIGGER reject_write BEFORE UPDATE ON journal BEGIN SELECT RAISE(ABORT, 'simulated write failure'); END",
        );
        await expectLater(
          db.save(original.copy(theme: AppTheme.dark)),
          throwsA(anything),
        );
        expect((await db.load(now)).toJson(), original.toJson());
      } finally {
        await db.close();
      }
    },
  );
  test('invalid backup does not modify stored data', () async {
    final db = JournalDatabase(NativeDatabase.memory());
    try {
      final j = await db.load(now);
      expect(
        () => Journal.decode('{"version":999}', now),
        throwsFormatException,
      );
      expect((await db.load(now)).toJson(), j.toJson());
    } finally {
      await db.close();
    }
  });
}
