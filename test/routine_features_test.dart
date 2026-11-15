import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qada_tracker/controller.dart';
import 'package:qada_tracker/database.dart';
import 'package:qada_tracker/model.dart';
import 'package:qada_tracker/prayer_times_models.dart';

final now = DateTime(2026, 11, 18, 22);
final start = DateTime(2026, 11, 14);
TrackingPause period({
  String id = 'period',
  int from = 14,
  int? through = 17,
  int fromPrayer = 0,
  int throughPrayer = 4,
}) => TrackingPause(
  id: id,
  from: DateTime(2026, 11, from),
  through: through == null ? null : DateTime(2026, 11, through),
  fromPrayer: fromPrayer,
  throughPrayer: throughPrayer,
);
void main() {
  test(
    'version 1 journals migrate with existing choices and eleven PM/all-prayer defaults',
    () {
      final legacy = Journal(startDate: start, reminderEnabled: true).toJson()
        ..['version'] = 1
        ..remove('reminderMinutes')
        ..remove('trackingPauses')
        ..remove('mutePrayerAlertsWhenExempt');
      (legacy['prayerTimes'] as Map).remove('notificationMask');
      final j = Journal.decode(jsonEncode(legacy), now);
      expect(j.reminderEnabled, isTrue);
      expect(j.reminderMinutes, 1380);
      expect(j.prayerTimes.notificationMask, 31);
      expect(j.trackingPauses, isEmpty);
      expect(j.toJson()['version'], 2);
    },
  );
  test(
    'full backup validates new times, prayer choices, and exemption boundaries',
    () {
      final original =
          Journal(
            startDate: start,
            reminderMinutes: 1275,
            prayerTimes: const PrayerTimeSettings(
              notifications: true,
              notificationMask: 9,
            ),
          ).addPause(period(fromPrayer: 3, throughPrayer: 1)).setStatuses(now, {
            Prayer.subuh: PrayerStatus.exempt,
          }, now);
      expect(
        Journal.decode(original.export(), now).toJson(),
        original.toJson(),
      );
      void invalid(void Function(Map<String, dynamic>) change) {
        final root = jsonDecode(original.export()) as Map<String, dynamic>;
        change(root);
        expect(
          () => Journal.decode(jsonEncode(root), now),
          throwsA(anyOf(isA<FormatException>(), isA<StateError>())),
        );
      }

      for (final value in [-1, 1440, '23:00', true]) {
        invalid((r) => r['reminderMinutes'] = value);
      }
      for (final value in [-1, 32, '31', true]) {
        invalid((r) => (r['prayerTimes'] as Map)['notificationMask'] = value);
      }
      invalid(
        (r) => (r['trackingPauses'] as List).first['through'] = '2026-11-13',
      );
      invalid((r) => (r['trackingPauses'] as List).first['fromPrayer'] = 5);
      invalid(
        (r) => (r['trackingPauses'] as List).first['from'] = '2026-02-30',
      );
      invalid(
        (r) => (r['trackingPauses'] as List).add(
          (r['trackingPauses'] as List).first,
        ),
      );
      invalid((r) => r['version'] = 1);
      invalid((r) => r['version'] = 99);
    },
  );
  test(
    'exempt ranges preserve performed/missed records and only replace unrecorded placeholders',
    () {
      var j = Journal(startDate: start).setStatuses(start, {
        Prayer.subuh: PrayerStatus.performed,
        Prayer.zohor: PrayerStatus.missed,
        Prayer.asar: PrayerStatus.unrecorded,
      }, now);
      j = j.addPause(period());
      expect(j.status(start, Prayer.subuh), PrayerStatus.performed);
      expect(j.status(start, Prayer.zohor), PrayerStatus.missed);
      expect(j.status(start, Prayer.asar), PrayerStatus.exempt);
      expect(j.records[dateKey(start)]!.containsKey(Prayer.asar), isFalse);
      expect(j.outstanding, 1);
      expect(j.unresolvedDays(now), isEmpty);
      expect(j.requiredPrayers(start), [Prayer.subuh, Prayer.zohor]);
      expect(j.fullyExempt(DateTime(2026, 11, 15)), isTrue);
      expect(j.fullyPerformed(DateTime(2026, 11, 15)), isFalse);
      expect(j.fullyPerformed(start), isFalse);
      expect(j.status(now, Prayer.asar), PrayerStatus.unrecorded);
    },
  );
  test(
    'individual exemptions change required totals and never erase a replacement obligation silently',
    () {
      var j = Journal(startDate: start)
          .setStatuses(start, {
            for (final p in Prayer.values)
              p: p == Prayer.subuh ? PrayerStatus.missed : PrayerStatus.exempt,
          }, now)
          .complete(Prayer.subuh, 1, now, 'replacement');
      expect(
        () => j.setStatuses(start, {Prayer.subuh: PrayerStatus.exempt}, now),
        throwsStateError,
      );
      j = j.undo('replacement').setStatuses(start, {
        Prayer.subuh: PrayerStatus.exempt,
      }, now);
      expect(j.requiredPrayers(start), isEmpty);
      expect(j.outstanding, 0);
      expect(j.fullyPerformed(start), isFalse);
      j = j.setStatuses(start, {Prayer.subuh: PrayerStatus.performed}, now);
      expect(j.fullyPerformed(start), isTrue);
    },
  );
  test(
    'ongoing pause and explicit partial-day resume preserve the full exempt interval',
    () {
      var j = Journal(
        startDate: start,
      ).addPause(period(through: null, fromPrayer: 3));
      expect(j.status(start, Prayer.asar), PrayerStatus.unrecorded);
      expect(j.status(start, Prayer.maghrib), PrayerStatus.exempt);
      expect(j.fullyExempt(DateTime(2026, 11, 15)), isTrue);
      j = j.resumePause('period', now, Prayer.asar.index);
      expect(j.status(now, Prayer.subuh), PrayerStatus.exempt);
      expect(j.status(now, Prayer.zohor), PrayerStatus.exempt);
      expect(j.status(now, Prayer.asar), PrayerStatus.unrecorded);
      expect(
        j.status(DateTime(2026, 11, 19), Prayer.subuh),
        PrayerStatus.unrecorded,
      );
      expect(j.trackingPauses.single.through, dayOnly(now));
      expect(j.records, isEmpty);
    },
  );
  test(
    'resume tomorrow and cancel a same-day pause do not create guessed records',
    () {
      final j = Journal(startDate: start).addPause(period(through: null));
      final resumed = j.resumePause('period', now, 5);
      expect(resumed.fullyExempt(now), isTrue);
      expect(
        resumed.status(DateTime(2026, 11, 19), Prayer.subuh),
        PrayerStatus.unrecorded,
      );
      final sameDay = Journal(
        startDate: dayOnly(now),
      ).addPause(TrackingPause(id: 'now', from: now));
      expect(sameDay.resumePause('now', now, 0).trackingPauses, isEmpty);
    },
  );
  test(
    'removing a period restores unresolved dates; explicit exemptions and overlapping periods survive',
    () {
      var j = Journal(startDate: start)
          .addPause(period())
          .addPause(period(id: 'second', from: 16, through: 18))
          .setStatuses(start, {Prayer.subuh: PrayerStatus.exempt}, now);
      j = j.removePause('period');
      expect(j.status(start, Prayer.subuh), PrayerStatus.exempt);
      expect(j.status(start, Prayer.zohor), PrayerStatus.unrecorded);
      expect(j.fullyExempt(DateTime(2026, 11, 16)), isTrue);
      expect(j.unresolvedDays(now), [DateTime(2026, 11, 15), start]);
    },
  );
  test(
    'planned periods do not write future records and malformed/duplicate ongoing pauses reject atomically',
    () {
      final j = Journal(
        startDate: start,
      ).addPause(period(from: 20, through: 23));
      expect(j.records, isEmpty);
      expect(j.status(now, Prayer.subuh), PrayerStatus.unrecorded);
      expect(
        Journal.decode(j.export(), now).trackingPauses.single.from,
        DateTime(2026, 11, 20),
      );
      final ongoing = j.addPause(period(id: 'ongoing', through: null));
      expect(
        () => ongoing.addPause(period(id: 'other', through: null)),
        throwsFormatException,
      );
      expect(ongoing.trackingPauses.length, 2);
    },
  );
  test(
    'version 2 preferences and periods survive SQLite reopening and rejected writes leave the saved document intact',
    () async {
      final dir = Directory.systemTemp.createTempSync('qada-routine-');
      final file = File('${dir.path}/journal.sqlite');
      var db = JournalDatabase(NativeDatabase(file));
      try {
        final j = Journal(
          startDate: start,
          reminderMinutes: 1290,
          prayerTimes: const PrayerTimeSettings(notificationMask: 17),
        ).addPause(period(through: null));
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
