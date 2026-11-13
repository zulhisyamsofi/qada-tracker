import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'prayer_times_models.dart';

class PrayerTimesApi {
  PrayerTimesApi(this.client);
  final http.Client client;
  Future<PrayerCalendar> fetch(PrayerPlace place, DateTime now) async {
    final anchor = DateTime.utc(now.toUtc().year, now.toUtc().month);
    final current = await _get(
      Uri.https(
        'api.waktusolat.app',
        '/v2/solat/gps/${place.latitude}/${place.longitude}',
        {'year': '${anchor.year}', 'month': '${anchor.month}'},
      ),
    );
    final zone = current['zone'] as String;
    if (!RegExp(r'^[A-Z]{3}\d{2}$').hasMatch(zone)) {
      throw const FormatException('Unknown Malaysian prayer zone.');
    }
    final adjacent = await Future.wait([
      for (final offset in [-1, 1])
        _month(zone, DateTime.utc(anchor.year, anchor.month + offset)),
    ]);
    return parseMonths([current, ...adjacent], place, now);
  }

  Future<Map<String, dynamic>> _get(Uri uri) async {
    final response = await client.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw const FormatException(
        'Prayer time service is unavailable for this place.',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _month(String zone, DateTime month) => _get(
    Uri.https('api.waktusolat.app', '/v2/solat/$zone', {
      'year': '${month.year}',
      'month': '${month.month}',
    }),
  );

  static PrayerCalendar parseMonths(
    List<Map<String, dynamic>> months,
    PrayerPlace place,
    DateTime now,
  ) {
    final entries = <Map<String, dynamic>>[];
    String? zone;
    for (final month in months) {
      final rowZone = month['zone'] as String;
      if (!RegExp(r'^[A-Z]{3}\d{2}$').hasMatch(rowZone) ||
          (zone != null && zone != rowZone)) {
        throw const FormatException('Inconsistent prayer zone.');
      }
      zone = rowZone;
      final year = month['year'] as int;
      final number = month['month_number'] as int;
      if (year < 2000 || year > 2200 || number < 1 || number > 12) {
        throw const FormatException('Invalid calendar month.');
      }
      final rows = month['prayers'] as List;
      if (rows.isEmpty) throw const FormatException('Empty prayer calendar.');
      for (final raw in rows) {
        final row = raw as Map<String, dynamic>;
        final day = row['day'] as int;
        final date = DateTime.utc(year, number, day);
        if (date.year != year || date.month != number || date.day != day) {
          throw const FormatException('Invalid prayer date.');
        }
        final key =
            '${year.toString().padLeft(4, '0')}-${number.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
        for (final prayer in prayerApiNames.entries) {
          final seconds = row[prayer.value];
          if (seconds is! int || seconds <= 0 || seconds >= 10000000000) {
            throw const FormatException('Invalid prayer timestamp.');
          }
          final at = DateTime.fromMillisecondsSinceEpoch(
            seconds * 1000,
            isUtc: true,
          );
          final local = at.add(const Duration(hours: 8));
          if (local.year != year || local.month != number || local.day != day) {
            throw const FormatException('Timestamp outside prayer date.');
          }
          entries.add({
            'prayer': prayer.key,
            'at': at.millisecondsSinceEpoch,
            'date': key,
            'time':
                '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}',
          });
        }
      }
    }
    final calendar = PrayerCalendar.fromJson({
      'version': 1,
      'sourceKey': place.key,
      'zone': zone,
      'timezone': 'Asia/Kuala_Lumpur',
      'fetchedAt': now.millisecondsSinceEpoch,
      'entries': entries,
    });
    if (!calendar.fresh(now)) {
      throw const FormatException(
        'API calendar does not cover current and upcoming prayers.',
      );
    }
    return calendar;
  }
}

class PrayerLocation {
  Future<PrayerPlace> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const FormatException(
        'Turn on device location or choose a place from the list.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const FormatException(
        'Location access was not granted. You can still choose a place from the list.',
      );
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 20),
      ),
    );
    // About 100 m precision is enough for city prayer times; do not retain a track.
    return PrayerPlace(
      'device',
      'Saved device location',
      double.parse(position.latitude.toStringAsFixed(3)),
      double.parse(position.longitude.toStringAsFixed(3)),
      device: true,
    );
  }
}
