import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:qada_tracker/controller.dart';
import 'package:qada_tracker/database.dart';
import 'package:qada_tracker/model.dart';
import 'package:qada_tracker/prayer_times_api.dart';
import 'package:qada_tracker/prayer_times_controller.dart';
import 'package:qada_tracker/prayer_times_models.dart';

class FakeTimesApi extends PrayerTimesApi {
  FakeTimesApi() : super(MockClient((_) async => http.Response('', 500)));
  int requests = 0;
  bool fail = false;
  @override
  Future<PrayerCalendar> fetch(PrayerPlace place, DateTime now) async {
    requests++;
    if (fail) throw const FormatException('offline');
    return PrayerTimesApi.parseMonths(
      [
        jsonDecode(
              File('test/fixtures/waktusolat_calendar.json').readAsStringSync(),
            )
            as Map<String, dynamic>,
      ],
      place,
      now,
    );
  }
}

void main() {
  final now = DateTime.utc(2026, 11, 13, 2);
  late JournalDatabase db;
  late ProviderContainer container;
  late FakeTimesApi api;
  late ProviderSubscription<AsyncValue<PrayerTimesData>> subscription;
  setUp(() async {
    db = JournalDatabase(NativeDatabase.memory());
    api = FakeTimesApi();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((ref) async => db),
        clockProvider.overrideWithValue(() => now),
        prayerTimesApiProvider.overrideWithValue(api),
      ],
    );
    subscription = container.listen(prayerTimesProvider, (_, _) {});
  });
  tearDown(() async {
    subscription.close();
    container.dispose();
    api.client.close();
    await db.close();
  });
  test(
    'new calendar persists and forced refresh preserves saved times offline',
    () async {
      final initial = await container.read(prayerTimesProvider.future);
      expect(api.requests, 1);
      expect((await db.loadCalendar())!.sourceKey, initial.calendar.sourceKey);
      api.fail = true;
      final refresh = container.read(prayerTimesProvider.notifier).refresh();
      expect(
        container.read(prayerTimesProvider).requireValue.refreshing,
        isTrue,
      );
      expect(
        container.read(prayerTimesProvider).requireValue.calendar,
        initial.calendar,
      );
      await refresh;
      final fallback = container.read(prayerTimesProvider).requireValue;
      expect(fallback.warning, isNotNull);
      expect(fallback.calendar.toJson(), initial.calendar.toJson());
    },
  );
  test(
    'journal saves and reminder preferences preserve the loaded timetable without loading states',
    () async {
      final initial = await container.read(prayerTimesProvider.future);
      final states = <AsyncValue<PrayerTimesData>>[];
      final observer = container.listen(
        prayerTimesProvider,
        (_, next) => states.add(next),
      );
      try {
        final journal = container.read(journalProvider.notifier);
        await journal.statuses(now, {Prayer.subuh: PrayerStatus.performed});
        await container.pump();
        await journal.statuses(now, {Prayer.subuh: PrayerStatus.unrecorded});
        await container.pump();
        await journal.statuses(now, {Prayer.subuh: PrayerStatus.missed});
        await container.pump();
        await journal.completeMiss(now, Prayer.subuh);
        await container.pump();
        await journal.change(
          (j) => j.copy(
            theme: AppTheme.dark,
            language: AppLanguage.ms,
            prayerTimes: j.prayerTimes.copy(
              notifications: true,
              notificationMask: 17,
            ),
          ),
        );
        await container.pump();
        await journal.reload();
        await container.pump();
        await journal.restore(container.read(journalProvider).requireValue);
        await container.pump();
        expect(states, isEmpty);
        expect(container.read(prayerTimesProvider).requireValue, same(initial));
        expect(api.requests, 1);
      } finally {
        observer.close();
      }
    },
  );
  test('fresh cache avoids another API request', () async {
    await container.read(prayerTimesProvider.future);
    container.invalidate(prayerTimesProvider);
    await container.read(prayerTimesProvider.future);
    expect(api.requests, 1);
  });
  test(
    'changing place offline never shows the previous place as current',
    () async {
      await container.read(prayerTimesProvider.future);
      api.fail = true;
      await container
          .read(journalProvider.notifier)
          .change(
            (j) => j.copy(
              prayerTimes: j.prayerTimes.copy(place: malaysiaPlaces.last),
            ),
          );
      await container.pump();
      await expectLater(
        container.read(prayerTimesProvider.future),
        throwsFormatException,
      );
      expect(container.read(prayerTimesProvider).hasError, isTrue);
      expect((await db.loadCalendar())!.sourceKey, malaysiaPlaces.first.key);
    },
  );
  test(
    'changing place online replaces the calendar for the selected source',
    () async {
      await container.read(prayerTimesProvider.future);
      await container
          .read(journalProvider.notifier)
          .change(
            (j) => j.copy(
              prayerTimes: j.prayerTimes.copy(place: malaysiaPlaces.last),
            ),
          );
      await container.pump();
      final next = await container.read(prayerTimesProvider.future);
      expect(next.calendar.sourceKey, malaysiaPlaces.last.key);
      expect((await db.loadCalendar())!.sourceKey, malaysiaPlaces.last.key);
    },
  );
}
