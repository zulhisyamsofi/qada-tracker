import 'dart:convert';

enum Prayer { subuh, zohor, asar, maghrib, isyak }

enum PrayerStatus { unrecorded, performed, missed }

enum AppTheme { system, light, dark }

extension PrayerLabel on Prayer {
  String get label =>
      const ['Subuh', 'Zohor', 'Asar', 'Maghrib', 'Isyak'][index];
}

String dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
DateTime dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);
DateTime nextDay(DateTime date) =>
    DateTime(date.year, date.month, date.day + 1);
DateTime parseDay(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null ||
      !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
      dateKey(parsed) != value) {
    throw const FormatException('Invalid calendar date.');
  }
  return dayOnly(parsed);
}

class QadaEntry {
  const QadaEntry({
    required this.id,
    required this.prayer,
    required this.quantity,
    required this.completedAt,
  });
  final String id;
  final Prayer prayer;
  final int quantity;
  final DateTime completedAt;
  Map<String, dynamic> toJson() => {
    'id': id,
    'prayer': prayer.name,
    'quantity': quantity,
    'completedAt': completedAt.toIso8601String(),
  };
}

class Journal {
  Journal({
    required this.startDate,
    Map<String, Map<Prayer, PrayerStatus>>? records,
    Map<Prayer, int>? starting,
    List<QadaEntry>? replacements,
    this.theme = AppTheme.system,
  }) : records = Map.unmodifiable(
         (records ?? {}).map(
           (key, value) =>
               MapEntry(key, Map<Prayer, PrayerStatus>.unmodifiable(value)),
         ),
       ),
       starting = Map.unmodifiable(
         starting ?? {for (final p in Prayer.values) p: 0},
       ),
       replacements = List.unmodifiable(replacements ?? []);
  final DateTime startDate;
  final Map<String, Map<Prayer, PrayerStatus>> records;
  final Map<Prayer, int> starting;
  final List<QadaEntry> replacements;
  final AppTheme theme;

  PrayerStatus status(DateTime day, Prayer p) =>
      records[dateKey(day)]?[p] ?? PrayerStatus.unrecorded;
  int balance(Prayer p) =>
      (starting[p] ?? 0) +
      records.values.where((day) => day[p] == PrayerStatus.missed).length -
      replacements
          .where((e) => e.prayer == p)
          .fold(0, (sum, e) => sum + e.quantity);
  int get outstanding => Prayer.values.fold(0, (sum, p) => sum + balance(p));
  Journal copy({
    Map<String, Map<Prayer, PrayerStatus>>? records,
    Map<Prayer, int>? starting,
    List<QadaEntry>? replacements,
    AppTheme? theme,
  }) => Journal(
    startDate: startDate,
    records: records ?? this.records,
    starting: starting ?? this.starting,
    replacements: replacements ?? this.replacements,
    theme: theme ?? this.theme,
  );

  Journal checked() {
    for (final p in Prayer.values) {
      if (balance(p) < 0) {
        throw StateError(
          'This change would make ${p.label} negative. Undo the corresponding qada replacement first.',
        );
      }
    }
    return this;
  }

  Journal setStatuses(
    DateTime day,
    Map<Prayer, PrayerStatus> changes,
    DateTime now,
  ) {
    final target = dayOnly(day);
    if (target.isBefore(startDate) || target.isAfter(dayOnly(now))) {
      throw StateError('Choose a date between your tracking start and today.');
    }
    final updated = {
      for (final e in records.entries)
        e.key: Map<Prayer, PrayerStatus>.of(e.value),
    };
    updated[dateKey(day)] = {...?updated[dateKey(day)], ...changes};
    return copy(records: updated).checked();
  }

  Journal setStarting(Map<Prayer, int> values) {
    if (values.length != Prayer.values.length ||
        values.values.any((n) => n < 0 || n > 1000000000)) {
      throw StateError(
        'Enter a nonnegative whole count for each prayer (maximum 1 billion).',
      );
    }
    return copy(starting: values).checked();
  }

  Journal complete(Prayer p, int quantity, DateTime now, String id) {
    if (quantity <= 0 || quantity > balance(p)) {
      throw StateError('Choose a quantity between 1 and ${balance(p)}.');
    }
    if (replacements.any((e) => e.id == id)) {
      throw StateError('Duplicate replacement entry.');
    }
    return copy(
      replacements: [
        ...replacements,
        QadaEntry(id: id, prayer: p, quantity: quantity, completedAt: now),
      ],
    ).checked();
  }

  Journal undo(String id) =>
      copy(replacements: replacements.where((e) => e.id != id).toList());
  Iterable<DateTime> days(DateTime now) sync* {
    for (var day = startDate; !day.isAfter(dayOnly(now)); day = nextDay(day)) {
      yield day;
    }
  }

  List<DateTime> unresolvedDays(DateTime now) => days(now)
      .where(
        (day) =>
            day.isBefore(dayOnly(now)) &&
            Prayer.values.any((p) => status(day, p) == PrayerStatus.unrecorded),
      )
      .toList()
      .reversed
      .toList();

  Map<String, dynamic> toJson() => {
    'version': 1,
    'startDate': dateKey(startDate),
    'theme': theme.name,
    'starting': {for (final p in Prayer.values) p.name: starting[p] ?? 0},
    'records': {
      for (final e in records.entries)
        e.key: {for (final r in e.value.entries) r.key.name: r.value.name},
    },
    'replacements': replacements.map((e) => e.toJson()).toList(),
  };
  String export() => const JsonEncoder.withIndent('  ').convert(toJson());

  static Journal decode(String source, DateTime now) {
    try {
      final root = jsonDecode(source);
      if (root is! Map<String, dynamic> ||
          root['version'] is! int ||
          root['version'] != 1) {
        throw const FormatException('Unsupported backup version.');
      }
      final start = parseDay(root['startDate'] as String);
      if (start.isBefore(DateTime(1900)) || start.isAfter(dayOnly(now))) {
        throw const FormatException('Invalid tracking start date.');
      }
      final rawStarting = root['starting'] as Map<String, dynamic>;
      if (rawStarting.length != 5) {
        throw const FormatException('Missing starting balances.');
      }
      final starting = <Prayer, int>{};
      for (final p in Prayer.values) {
        final n = rawStarting[p.name];
        if (n is! int || n < 0 || n > 1000000000) {
          throw const FormatException('Invalid starting balance.');
        }
        starting[p] = n;
      }
      final records = <String, Map<Prayer, PrayerStatus>>{};
      for (final e in (root['records'] as Map<String, dynamic>).entries) {
        final day = parseDay(e.key);
        if (day.isBefore(start) || day.isAfter(dayOnly(now))) {
          throw const FormatException('Record date outside tracking period.');
        }
        final row = e.value as Map<String, dynamic>;
        records[e.key] = {
          for (final r in row.entries)
            Prayer.values.byName(r.key): PrayerStatus.values.byName(
              r.value as String,
            ),
        };
      }
      final ids = <String>{};
      final replacements = <QadaEntry>[];
      for (final value in root['replacements'] as List) {
        final e = value as Map<String, dynamic>;
        final id = e['id'] as String;
        final n = e['quantity'];
        final timestamp = e['completedAt'] as String;
        if (timestamp.length < 19) {
          throw const FormatException('Invalid replacement timestamp.');
        }
        parseDay(timestamp.substring(0, 10));
        final time = DateTime.parse(timestamp);
        if (id.isEmpty ||
            !ids.add(id) ||
            n is! int ||
            n <= 0 ||
            n > 1000000000 ||
            dayOnly(time.toLocal()).isBefore(start) ||
            dayOnly(time.toLocal()).isAfter(dayOnly(now))) {
          throw const FormatException('Invalid replacement entry.');
        }
        replacements.add(
          QadaEntry(
            id: id,
            prayer: Prayer.values.byName(e['prayer'] as String),
            quantity: n,
            completedAt: time,
          ),
        );
      }
      return Journal(
        startDate: start,
        records: records,
        starting: starting,
        replacements: replacements,
        theme: AppTheme.values.byName(root['theme'] as String),
      ).checked();
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'Invalid backup contents. No data was changed.',
      );
    }
  }
}
