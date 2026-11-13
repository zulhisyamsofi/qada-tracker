import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

const prayerApiNames = {
  'subuh': 'fajr',
  'zohor': 'dhuhr',
  'asar': 'asr',
  'maghrib': 'maghrib',
  'isyak': 'isha',
};

class PrayerPlace {
  const PrayerPlace(
    this.id,
    this.label,
    this.latitude,
    this.longitude, {
    this.device = false,
  });
  final String id, label;
  final double latitude, longitude;
  final bool device;
  String get key =>
      'waktusolat-v2:$id:${latitude.toStringAsFixed(4)}:${longitude.toStringAsFixed(4)}';
  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'latitude': latitude,
    'longitude': longitude,
    'device': device,
    'key': key,
  };
  static PrayerPlace fromJson(Map<String, dynamic> json) {
    final lat = (json['latitude'] as num).toDouble();
    final lon = (json['longitude'] as num).toDouble();
    final label = json['label'] as String;
    final id = json['id'] as String;
    if (!lat.isFinite ||
        !lon.isFinite ||
        lat.abs() > 90 ||
        lon.abs() > 180 ||
        label.isEmpty ||
        label.length > 100 ||
        id.isEmpty ||
        id.length > 100) {
      throw const FormatException('Invalid prayer place.');
    }
    return PrayerPlace(id, label, lat, lon, device: json['device'] as bool);
  }
}

const malaysiaPlaces = [
  PrayerPlace('kuala_lumpur', 'Kuala Lumpur', 3.139, 101.6869),
  PrayerPlace('putrajaya', 'Putrajaya', 2.9264, 101.6964),
  PrayerPlace('shah_alam', 'Shah Alam', 3.0738, 101.5183),
  PrayerPlace('george_town', 'George Town', 5.4141, 100.3288),
  PrayerPlace('ipoh', 'Ipoh', 4.5975, 101.0901),
  PrayerPlace('johor_bahru', 'Johor Bahru', 1.4927, 103.7414),
  PrayerPlace('melaka', 'Melaka', 2.1896, 102.2501),
  PrayerPlace('seremban', 'Seremban', 2.7297, 101.9381),
  PrayerPlace('kuantan', 'Kuantan', 3.8077, 103.326),
  PrayerPlace('kota_bharu', 'Kota Bharu', 6.1254, 102.2381),
  PrayerPlace('kuala_terengganu', 'Kuala Terengganu', 5.3302, 103.1408),
  PrayerPlace('alor_setar', 'Alor Setar', 6.1248, 100.3678),
  PrayerPlace('kangar', 'Kangar', 6.4414, 100.1986),
  PrayerPlace('kuching', 'Kuching', 1.5535, 110.3593),
  PrayerPlace('miri', 'Miri', 4.3995, 113.9914),
  PrayerPlace('kota_kinabalu', 'Kota Kinabalu', 5.9804, 116.0735),
  PrayerPlace('sandakan', 'Sandakan', 5.8394, 118.1172),
  PrayerPlace('tawau', 'Tawau', 4.2447, 117.8911),
  PrayerPlace('labuan', 'Labuan', 5.2831, 115.2308),
];

class PrayerTimeSettings {
  const PrayerTimeSettings({
    this.place = const PrayerPlace(
      'kuala_lumpur',
      'Kuala Lumpur',
      3.139,
      101.6869,
    ),
    this.notifications = false,
  });
  final PrayerPlace place;
  final bool notifications;
  PrayerTimeSettings copy({PrayerPlace? place, bool? notifications}) =>
      PrayerTimeSettings(
        place: place ?? this.place,
        notifications: notifications ?? this.notifications,
      );
  Map<String, dynamic> toJson() => {
    'place': place.toJson(),
    'notifications': notifications,
  };
  static PrayerTimeSettings fromJson(Map<String, dynamic> json) =>
      PrayerTimeSettings(
        place: PrayerPlace.fromJson(json['place'] as Map<String, dynamic>),
        notifications: json['notifications'] as bool,
      );
}

class PrayerTime {
  const PrayerTime({
    required this.prayer,
    required this.at,
    required this.date,
    required this.time,
  });
  final String prayer, date, time;
  final DateTime at;
  Map<String, dynamic> toJson() => {
    'prayer': prayer,
    'at': at.millisecondsSinceEpoch,
    'date': date,
    'time': time,
  };
}

class PrayerCalendar {
  PrayerCalendar({
    required this.sourceKey,
    required this.timezone,
    this.zone = '',
    required this.fetchedAt,
    required List<PrayerTime> entries,
  }) : entries = List.unmodifiable(entries) {
    _ensureZones();
    tz.getLocation(timezone);
    if (entries.isEmpty) throw const FormatException('Empty prayer calendar.');
  }
  final String sourceKey, timezone;
  final String zone;
  final DateTime fetchedAt;
  final List<PrayerTime> entries;
  static bool _zonesReady = false;
  static void _ensureZones() {
    if (!_zonesReady) {
      tzdata.initializeTimeZones();
      _zonesReady = true;
    }
  }

  DateTime localNow(DateTime now) =>
      tz.TZDateTime.from(now, tz.getLocation(timezone));
  String dateAt(DateTime now) {
    final local = localNow(now);
    return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  List<PrayerTime> today(DateTime now) =>
      entries.where((e) => e.date == dateAt(now)).toList();
  DateTime get until => entries.last.at;
  bool fresh(DateTime now) =>
      today(now).length == 5 &&
      until.isAfter(now.add(const Duration(days: 14)));
  Map<String, dynamic> toJson() => {
    'version': 1,
    'sourceKey': sourceKey,
    'timezone': timezone,
    'zone': zone,
    'fetchedAt': fetchedAt.millisecondsSinceEpoch,
    'entries': entries.map((e) => e.toJson()).toList(),
  };
  static PrayerCalendar fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Invalid calendar version.');
    }
    final seen = <String>{};
    final entries = (json['entries'] as List).map((raw) {
      final e = raw as Map<String, dynamic>;
      final prayer = e['prayer'] as String;
      final date = e['date'] as String;
      final time = e['time'] as String;
      if (!prayerApiNames.containsKey(prayer) ||
          !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
          !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(time) ||
          !seen.add('$date/$prayer')) {
        throw const FormatException('Invalid prayer time.');
      }
      return PrayerTime(
        prayer: prayer,
        at: DateTime.fromMillisecondsSinceEpoch(e['at'] as int, isUtc: true),
        date: date,
        time: time,
      );
    }).toList()..sort((a, b) => a.at.compareTo(b.at));
    final calendar = PrayerCalendar(
      sourceKey: json['sourceKey'] as String,
      timezone: json['timezone'] as String,
      zone: json['zone'] as String? ?? '',
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(
        json['fetchedAt'] as int,
        isUtc: true,
      ),
      entries: entries,
    );
    for (final e in entries) {
      final local = calendar.localNow(e.at);
      final localTime =
          '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
      if (calendar.dateAt(e.at) != e.date || localTime != e.time) {
        throw const FormatException('Inconsistent prayer timezone.');
      }
    }
    final counts = <String, int>{};
    for (final e in entries) {
      counts[e.date] = (counts[e.date] ?? 0) + 1;
    }
    if (counts.values.any((count) => count != 5)) {
      throw const FormatException('Incomplete prayer day.');
    }
    return calendar;
  }
}
