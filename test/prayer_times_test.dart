import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show MigrationStrategy;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qada_tracker/database.dart';
import 'package:qada_tracker/model.dart';
import 'package:qada_tracker/prayer_times_api.dart';
import 'package:qada_tracker/prayer_times_models.dart';

Map<String, dynamic> fixture() =>
    jsonDecode(
          File('test/fixtures/waktusolat_calendar.json').readAsStringSync(),
        )
        as Map<String, dynamic>;
PrayerCalendar calendar(DateTime now, {PrayerPlace? place}) =>
    PrayerTimesApi.parseMonths([fixture()], place ?? malaysiaPlaces.first, now);
void main() {
  final now = DateTime.utc(2026, 11, 13, 2);
  test(
    'real API fixture maps five prayers and Malaysia timezone correctly',
    () {
      final result = calendar(now);
      expect(result.entries.length, 150);
      expect(result.today(now).map((e) => e.prayer), prayerApiNames.keys);
      expect(result.entries.first.time, '05:48');
      expect(result.entries.first.at, DateTime.utc(2026, 10, 31, 21, 48));
      expect(result.dateAt(DateTime.utc(2026, 11, 12, 18)), '2026-11-13');
      expect(result.zone, 'WLY01');
      expect(
        PrayerCalendar.fromJson(result.toJson()).toJson(),
        result.toJson(),
      );
    },
  );
  test(
    'API uses GPS-to-zone lookup before fetching adjacent zone months',
    () async {
      final requests = <Uri>[];
      final api = PrayerTimesApi(
        MockClient((request) async {
          requests.add(request.url);
          if (request.url.path.contains('/gps/')) {
            return http.Response(jsonEncode(fixture()), 200);
          }
          return http.Response('service unavailable', 503);
        }),
      );
      await expectLater(
        api.fetch(malaysiaPlaces.first, now),
        throwsFormatException,
      );
      expect(requests.first.path, '/v2/solat/gps/3.139/101.6869');
      expect(
        requests
            .where((u) => !u.path.contains('/gps/'))
            .map((u) => u.queryParameters['month'])
            .toSet(),
        {'10', '12'},
      );
      expect(
        requests.every(
          (u) =>
              u.scheme == 'https' &&
              u.host == 'api.waktusolat.app' &&
              u.queryParameters['year'] == '2026',
        ),
        isTrue,
      );
    },
  );
  test('rejects missing, duplicate, malformed or mismatched-date API data', () {
    void bad(void Function(Map<String, dynamic>) edit) {
      final response = fixture();
      edit(response);
      expect(
        () => PrayerTimesApi.parseMonths([response], malaysiaPlaces.first, now),
        throwsA(anything),
      );
    }

    bad((j) => j['zone'] = 'unknown');
    bad((j) => j['prayers'][0]['fajr'] = '05:48');
    bad((j) => j['prayers'][0]['fajr'] = -1);
    bad((j) => j['prayers'][0]['fajr'] = 1793483280000);
    bad((j) => j['prayers'][0]['day'] = 32);
    bad((j) => (j['prayers'] as List).add(j['prayers'][0]));
    bad((j) => j['prayers'][0].remove('isha'));
  });
  test('all downloaded times match the official e-Solat sample', () {
    final official =
        jsonDecode(
              File('test/fixtures/jakim_esolat_wly01.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final result = calendar(now);
    final days = official['prayerTime'] as List;
    for (var day = 0; day < days.length; day++) {
      for (final entry in result.entries.sublist(day * 5, day * 5 + 5)) {
        expect('${entry.time}:00', days[day][prayerApiNames[entry.prayer]]);
      }
    }
  });
  test('backup defaults and selection/notifications round trip', () {
    final old = Journal(startDate: dayOnly(now)).toJson()
      ..remove('prayerTimes');
    expect(
      Journal.decode(jsonEncode(old), now).prayerTimes.place.id,
      'kuala_lumpur',
    );
    expect(
      Journal.decode(jsonEncode(old), now).prayerTimes.notifications,
      isFalse,
    );
    final journal = Journal(startDate: dayOnly(now)).copy(
      prayerTimes: PrayerTimeSettings(
        place: malaysiaPlaces.last,
        notifications: true,
      ),
    );
    expect(Journal.decode(journal.export(), now).toJson(), journal.toJson());
    old['prayerTimes'] = {
      'place': {
        'id': 'bad',
        'label': 'bad',
        'latitude': 100,
        'longitude': 0,
        'device': false,
      },
      'notifications': true,
    };
    expect(() => Journal.decode(jsonEncode(old), now), throwsFormatException);
  });
  test(
    'calendar persistence refuses a response from a previous place',
    () async {
      final db = JournalDatabase(NativeDatabase.memory());
      try {
        await db.load(now);
        final saved = calendar(now);
        expect(await db.saveCalendar(saved, now), isTrue);
        expect((await db.loadCalendar())!.sourceKey, saved.sourceKey);
        final journal = await db.load(now);
        await db.save(
          journal.copy(
            prayerTimes: PrayerTimeSettings(place: malaysiaPlaces.last),
          ),
        );
        expect(await db.saveCalendar(saved, now), isFalse);
      } finally {
        await db.close();
      }
    },
  );
  test('schema 1 migrates without altering existing prayer records', () async {
    final directory = await Directory.systemTemp.createTemp('qada-migration-');
    final file = File('${directory.path}/journal.sqlite');
    final old = _SchemaOne(NativeDatabase(file));
    final original = Journal(
      startDate: dayOnly(now),
    ).setStatuses(now, {Prayer.subuh: PrayerStatus.performed}, now);
    await old.save(original);
    await old.close();
    final db = JournalDatabase(NativeDatabase(file));
    try {
      expect((await db.load(now)).toJson(), original.toJson());
      expect(await db.loadCalendar(), isNull);
      expect(await db.saveCalendar(calendar(now), now), isTrue);
    } finally {
      await db.close();
      await directory.delete(recursive: true);
    }
  });
}

class _SchemaOne extends JournalDatabase {
  _SchemaOne(super.executor);
  @override
  int get schemaVersion => 1;
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      await customStatement(
        'CREATE TABLE journal (id INTEGER PRIMARY KEY CHECK (id = 1), document TEXT NOT NULL)',
      );
    },
  );
}
