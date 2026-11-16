import 'support/prayer_times.dart';
import 'package:qada_tracker/prayer_times_models.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qada_tracker/backup.dart';
import 'package:qada_tracker/controller.dart';
import 'package:qada_tracker/database.dart';
import 'package:qada_tracker/main.dart';
import 'package:qada_tracker/model.dart';

class FakeBackupFiles implements BackupFiles {
  String? contents;
  String? exported;
  @override
  Future<String?> read() async => contents;
  @override
  Future<bool> write(String filename, String contents) async {
    exported = contents;
    return true;
  }
}

void main() {
  for (final scenario in [
    'picker cancelled',
    'confirmation cancelled',
    'malformed',
    'restore',
  ]) {
    testWidgets('backup $scenario respects existing data', (tester) async {
      final now = DateTime(2026, 11, 13);
      final db = JournalDatabase(NativeDatabase.memory());
      final original =
          Journal(
            startDate: now,
            reminderMinutes: 21 * 60 + 15,
            prayerTimes: const PrayerTimeSettings(notificationMask: 17),
          ).setStatuses(now, {
            Prayer.asar: PrayerStatus.performed,
            Prayer.subuh: PrayerStatus.exempt,
          }, now);
      final replacement =
          Journal(
                startDate: now,
                reminderMinutes: 22 * 60,
                prayerTimes: const PrayerTimeSettings(notificationMask: 5),
              )
              .setStarting({for (final p in Prayer.values) p: 3})
              .addPause(
                TrackingPause(
                  id: 'restore-period',
                  from: now,
                  through: DateTime(now.year, now.month, now.day + 2),
                ),
              );
      await db.save(original);
      final files = FakeBackupFiles()
        ..contents = switch (scenario) {
          'picker cancelled' => null,
          'malformed' => '{',
          _ => replacement.export(),
        };
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fakePrayerTimes,
            databaseProvider.overrideWith((ref) async => db),
            clockProvider.overrideWithValue(() => now),
            backupFilesProvider.overrideWithValue(files),
          ],
          child: const QadaApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Export backup'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Export backup'));
      await tester.tap(find.text('Export backup'));
      await tester.pumpAndSettle();
      expect(Journal.decode(files.exported!, now).toJson(), original.toJson());
      await tester.ensureVisible(find.text('Restore backup'));
      await tester.tap(find.text('Restore backup'));
      await tester.pumpAndSettle();
      if (scenario == 'confirmation cancelled') {
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      } else if (scenario == 'restore') {
        await tester.tap(find.text('Replace and restore'));
        await tester.pumpAndSettle();
      }
      expect(
        (await db.load(now)).toJson(),
        scenario == 'restore' ? replacement.toJson() : original.toJson(),
      );
      await tester.pumpWidget(const SizedBox());
      await db.close();
    });
  }
}
