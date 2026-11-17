import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qada_tracker/controller.dart';
import 'package:qada_tracker/database.dart';
import 'package:qada_tracker/model.dart';
import 'package:qada_tracker/prayer_recording_policy.dart';
import 'package:qada_tracker/prayer_times_models.dart';
import 'package:timezone/timezone.dart' as tz;

PrayerCalendar sampleCalendar() => PrayerCalendar(
  sourceKey: malaysiaPlaces.first.key,
  timezone: 'UTC',
  fetchedAt: DateTime.utc(2026, 11, 13),
  entries: [
    for (final day in [12, 13, 14])
      for (final p in Prayer.values)
        PrayerTime(
          prayer: p.name,
          at: DateTime.utc(2026, 11, day, [5, 13, 16, 19, 20][p.index]),
          date: '2026-11-$day',
          time: '${[5, 13, 16, 19, 20][p.index].toString().padLeft(2, '0')}:00',
        ),
  ],
);

void main() {
  final day = DateTime(2026, 11, 13);
  final journal = Journal(startDate: DateTime(2026, 11, 12));
  final calendar = sampleCalendar();
  final performed = journal.setStatuses(day, {
    Prayer.asar: PrayerStatus.performed,
  }, day);
  test(
    'performed is blocked before start, allowed exactly at start and after',
    () {
      expect(
        () => PrayerRecordingPolicy.validate(
          journal,
          performed,
          calendar,
          DateTime.utc(2026, 11, 13, 15, 59, 59, 999),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Asar starts at 4:00 PM'),
          ),
        ),
      );
      PrayerRecordingPolicy.validate(
        journal,
        performed,
        calendar,
        DateTime.utc(2026, 11, 13, 16),
      );
      PrayerRecordingPolicy.validate(
        journal,
        performed,
        calendar,
        DateTime.utc(2026, 11, 13, 16, 0, 1),
      );
    },
  );
  test(
    'missing, wrong-place and wrong-date timetables cannot permit a mark',
    () {
      final wrong = PrayerCalendar(
        sourceKey: malaysiaPlaces.last.key,
        timezone: 'UTC',
        fetchedAt: day,
        entries: calendar.entries,
      );
      final old = PrayerCalendar(
        sourceKey: calendar.sourceKey,
        timezone: 'UTC',
        fetchedAt: day,
        entries: calendar.entries.where((e) => e.date != dateKey(day)).toList(),
      );
      for (final saved in [null, wrong, old]) {
        expect(
          () => PrayerRecordingPolicy.validate(
            journal,
            performed,
            saved,
            DateTime.utc(2026, 11, 13, 23),
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Refresh today’s prayer times'),
            ),
          ),
        );
      }
    },
  );
  test(
    'past records, missed/unrecorded changes and existing performed records remain editable',
    () {
      PrayerRecordingPolicy.validate(
        journal,
        journal.setStatuses(DateTime(2026, 11, 12), {
          Prayer.isyak: PrayerStatus.performed,
        }, day),
        null,
        day,
      );
      PrayerRecordingPolicy.validate(
        journal,
        journal.setStatuses(day, {Prayer.asar: PrayerStatus.missed}, day),
        null,
        day,
      );
      PrayerRecordingPolicy.validate(
        performed,
        performed.copy(theme: AppTheme.dark),
        null,
        day,
      );
      PrayerRecordingPolicy.validate(
        performed,
        performed.setStatuses(day, {Prayer.asar: PrayerStatus.unrecorded}, day),
        null,
        day,
      );
    },
  );
  test(
    'journal date, rather than the timetable current date, selects the slot',
    () {
      final phoneNow = tz.TZDateTime(
        tz.getLocation('America/New_York'),
        2026,
        11,
        12,
        23,
        30,
      );
      expect(calendar.dateAt(phoneNow), '2026-11-13');
      final target = PrayerRecordingPolicy.timeFor(
        calendar,
        calendar.sourceKey,
        phoneNow,
        Prayer.isyak,
      )!;
      expect(target.date, '2026-11-12');
      PrayerRecordingPolicy.validate(
        journal,
        journal.setStatuses(dayOnly(phoneNow), {
          Prayer.isyak: PrayerStatus.performed,
        }, phoneNow),
        calendar,
        phoneNow,
      );
    },
  );
  test(
    'queued controller writes are atomic, recheck the clock, and respect cache source',
    () async {
      var now = DateTime.utc(2026, 11, 13, 15);
      final db = JournalDatabase(NativeDatabase.memory());
      await db.save(journal);
      await db.saveCalendar(calendar, now);
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
        await expectLater(
          c.statuses(day, {
            Prayer.subuh: PrayerStatus.performed,
            Prayer.asar: PrayerStatus.performed,
          }),
          throwsStateError,
        );
        expect(
          (await db.load(now)).status(day, Prayer.subuh),
          PrayerStatus.unrecorded,
        );
        now = DateTime.utc(2026, 11, 13, 16);
        await c.statuses(day, {Prayer.asar: PrayerStatus.performed});
        await c.change(
          (j) => j.copy(
            prayerTimes: j.prayerTimes.copy(place: malaysiaPlaces.last),
          ),
        );
        await expectLater(
          c.statuses(day, {Prayer.subuh: PrayerStatus.performed}),
          throwsStateError,
        );
        await c.statuses(DateTime(2026, 11, 12), {
          Prayer.isyak: PrayerStatus.performed,
        });
        await db.customStatement('DELETE FROM prayer_calendar');
        await expectLater(
          c.statuses(day, {Prayer.zohor: PrayerStatus.performed}),
          throwsStateError,
        );
        // Explicitly confirmed restore keeps historical confirmations intact.
        final restore = journal.setStatuses(day, {
          Prayer.isyak: PrayerStatus.performed,
        }, day);
        await c.restore(restore);
        expect(
          (await db.load(now)).status(day, Prayer.isyak),
          PrayerStatus.performed,
        );
      } finally {
        listener.close();
        container.dispose();
        await db.close();
      }
    },
  );

  test(
    'a concurrent calendar refresh retries validation against the new time',
    () async {
      final now = DateTime.utc(2026, 11, 13, 16);
      final db = JournalDatabase(NativeDatabase.memory());
      await db.save(journal);
      await db.saveCalendar(calendar, now);
      final refreshed = PrayerCalendar(
        sourceKey: calendar.sourceKey,
        timezone: 'UTC',
        fetchedAt: now,
        entries: calendar.entries
            .map(
              (e) => e.date == dateKey(day) && e.prayer == 'asar'
                  ? PrayerTime(
                      prayer: e.prayer,
                      at: DateTime.utc(2026, 11, 13, 17),
                      date: e.date,
                      time: '17:00',
                    )
                  : e,
            )
            .toList(),
      );
      final encoded = jsonEncode(refreshed.toJson()).replaceAll("'", "''");
      await db.customStatement(
        '''CREATE TRIGGER refresh_calendar BEFORE UPDATE ON journal
      WHEN json_extract((SELECT document FROM prayer_calendar WHERE id = 1), '\$.fetchedAt') = ${calendar.fetchedAt.millisecondsSinceEpoch}
      BEGIN UPDATE prayer_calendar SET document = '$encoded' WHERE id = 1; SELECT RAISE(IGNORE); END''',
      );
      try {
        await expectLater(
          db.change(
            now,
            (j) =>
                j.setStatuses(day, {Prayer.asar: PrayerStatus.performed}, now),
            validate: (before, after, saved) =>
                PrayerRecordingPolicy.validate(before, after, saved, now),
          ),
          throwsStateError,
        );
        expect(
          (await db.load(now)).status(day, Prayer.asar),
          PrayerStatus.unrecorded,
        );
        expect(
          PrayerRecordingPolicy.timeFor(
            await db.loadCalendar(),
            calendar.sourceKey,
            day,
            Prayer.asar,
          )!.time,
          '17:00',
        );
      } finally {
        await db.close();
      }
    },
  );
}
