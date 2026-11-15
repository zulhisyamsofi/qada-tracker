import 'dart:convert';
import 'prayer_times_models.dart';

enum Prayer { subuh, zohor, asar, maghrib, isyak }

enum PrayerStatus { unrecorded, performed, missed, exempt }

enum AppTheme { system, light, dark }

extension PrayerLabel on Prayer {
  String get label =>
      const ['Subuh', 'Zohor', 'Asar', 'Maghrib', 'Isyak'][index];
}

String dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
DateTime dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);
DateTime get earliestJournalDay => DateTime(1900);
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

/// Explicit calendar-date boundaries, with optional partial first/last days.
/// A null end is an ongoing pause; it does not materialize future records.
class TrackingPause {
  TrackingPause({
    required this.id,
    required DateTime from,
    DateTime? through,
    this.fromPrayer = 0,
    this.throughPrayer = 4,
  }) : from = dayOnly(from),
       through = through == null ? null : dayOnly(through);
  final String id;
  final DateTime from;
  final DateTime? through;
  final int fromPrayer, throughPrayer;
  bool contains(DateTime day, Prayer prayer) {
    final key = dateKey(day),
        first = dateKey(from),
        last = through == null ? null : dateKey(through!);
    return key.compareTo(first) >= 0 &&
        (last == null || key.compareTo(last) <= 0) &&
        (key != first || prayer.index >= fromPrayer) &&
        (key != last || prayer.index <= throughPrayer);
  }

  TrackingPause checked() {
    if (id.isEmpty ||
        id.length > 100 ||
        from.isBefore(earliestJournalDay) ||
        from.year > 2200 ||
        fromPrayer < 0 ||
        fromPrayer > 4 ||
        throughPrayer < 0 ||
        throughPrayer > 4 ||
        (through != null &&
            (through!.isBefore(from) ||
                through!.year > 2200 ||
                (through == from && throughPrayer < fromPrayer)))) {
      throw const FormatException('Invalid exempt date range.');
    }
    return this;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'from': dateKey(from),
    'through': through == null ? null : dateKey(through!),
    'fromPrayer': fromPrayer,
    'throughPrayer': throughPrayer,
  };
  static TrackingPause fromJson(Map<String, dynamic> value) => TrackingPause(
    id: value['id'] as String,
    from: parseDay(value['from'] as String),
    through: value['through'] == null
        ? null
        : parseDay(value['through'] as String),
    fromPrayer: (value['fromPrayer'] ?? 0) as int,
    throughPrayer: (value['throughPrayer'] ?? 4) as int,
  ).checked();
}

class Journal {
  Journal({
    required this.startDate,
    Map<String, Map<Prayer, PrayerStatus>>? records,
    Map<Prayer, int>? starting,
    List<QadaEntry>? replacements,
    this.theme = AppTheme.system,
    this.reminderEnabled = false,
    this.reminderMinutes = 23 * 60,
    List<TrackingPause>? trackingPauses,
    this.mutePrayerAlertsWhenExempt = true,
    // Legacy journals are treated as seen; new databases explicitly opt in.
    this.walkthroughSeen = true,
    this.prayerTimes = const PrayerTimeSettings(),
  }) : trackingPauses = List.unmodifiable(trackingPauses ?? []),
       records = Map.unmodifiable(
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
  final bool reminderEnabled;

  /// Minute of the phone's local calendar day for the daily check-in.
  final int reminderMinutes;
  final List<TrackingPause> trackingPauses;
  final bool mutePrayerAlertsWhenExempt;
  final bool walkthroughSeen;
  final PrayerTimeSettings prayerTimes;

  PrayerStatus status(DateTime day, Prayer p) =>
      records[dateKey(day)]?[p] ??
      (trackingPauses.any((pause) => pause.contains(day, p))
          ? PrayerStatus.exempt
          : PrayerStatus.unrecorded);
  List<Prayer> requiredPrayers(DateTime day) => Prayer.values
      .where((p) => status(day, p) != PrayerStatus.exempt)
      .toList();
  bool fullyExempt(DateTime day) => requiredPrayers(day).isEmpty;
  bool fullyPerformed(DateTime day) {
    final required = requiredPrayers(day);
    return required.isNotEmpty &&
        required.every((p) => status(day, p) == PrayerStatus.performed);
  }

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
    bool? reminderEnabled,
    int? reminderMinutes,
    List<TrackingPause>? trackingPauses,
    bool? mutePrayerAlertsWhenExempt,
    bool? walkthroughSeen,
    PrayerTimeSettings? prayerTimes,
  }) => Journal(
    startDate: startDate,
    records: records ?? this.records,
    starting: starting ?? this.starting,
    replacements: replacements ?? this.replacements,
    theme: theme ?? this.theme,
    reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    reminderMinutes: reminderMinutes ?? this.reminderMinutes,
    trackingPauses: trackingPauses ?? this.trackingPauses,
    mutePrayerAlertsWhenExempt:
        mutePrayerAlertsWhenExempt ?? this.mutePrayerAlertsWhenExempt,
    walkthroughSeen: walkthroughSeen ?? this.walkthroughSeen,
    prayerTimes: prayerTimes ?? this.prayerTimes,
  );

  Journal checked() {
    final pauseIds = <String>{};
    var ongoing = 0;
    for (final pause in trackingPauses) {
      pause.checked();
      if (!pauseIds.add(pause.id) || (pause.through == null && ++ongoing > 1)) {
        throw const FormatException(
          'Duplicate or overlapping ongoing tracking pauses.',
        );
      }
    }
    if (prayerTimes.notificationMask < 0 || prayerTimes.notificationMask > 31) {
      throw const FormatException('Invalid prayer notification preferences.');
    }
    if (reminderMinutes < 0 || reminderMinutes >= 24 * 60) {
      throw StateError('Choose a valid daily reminder time.');
    }
    for (final p in Prayer.values) {
      if (balance(p) < 0) {
        throw StateError(
          'This change would make ${p.label} negative. Undo the corresponding qada replacement first.',
        );
      }
    }
    return this;
  }

  Journal addPause(TrackingPause pause) {
    pause.checked();
    final updated = {
      for (final e in records.entries)
        e.key: Map<Prayer, PrayerStatus>.of(e.value),
    };
    // Explicit confirmations survive. Clear only old unrecorded placeholders
    // so the selected interval can supply their exempt state.
    for (final e in updated.entries) {
      final day = parseDay(e.key);
      e.value.removeWhere(
        (p, s) => s == PrayerStatus.unrecorded && pause.contains(day, p),
      );
    }
    return copy(
      records: updated,
      trackingPauses: [...trackingPauses, pause],
    ).checked();
  }

  Journal removePause(String id) => copy(
    trackingPauses: trackingPauses.where((p) => p.id != id).toList(),
  ).checked();

  Journal resumePause(String id, DateTime now, int firstRequiredPrayer) {
    if (firstRequiredPrayer < 0 || firstRequiredPrayer > 5) {
      throw StateError('Choose the first prayer to track.');
    }
    final pause = trackingPauses.firstWhere((p) => p.id == id);
    if (pause.through != null) {
      throw StateError('This pause has already ended.');
    }
    final through = firstRequiredPrayer == 0
        ? DateTime(now.year, now.month, now.day - 1)
        : dayOnly(now);
    final lastPrayer = firstRequiredPrayer == 0 || firstRequiredPrayer == 5
        ? 4
        : firstRequiredPrayer - 1;
    if (through.isBefore(pause.from) ||
        (through == pause.from && lastPrayer < pause.fromPrayer)) {
      return removePause(id);
    }
    final ended = TrackingPause(
      id: id,
      from: pause.from,
      fromPrayer: pause.fromPrayer,
      through: through,
      throughPrayer: lastPrayer,
    );
    return copy(
      trackingPauses: [
        for (final p in trackingPauses)
          if (p.id == id) ended else p,
      ],
    ).checked();
  }

  Journal setStatuses(
    DateTime day,
    Map<Prayer, PrayerStatus> changes,
    DateTime now,
  ) {
    final target = dayOnly(day);
    if (target.isBefore(earliestJournalDay) || target.isAfter(dayOnly(now))) {
      throw StateError('Choose a date between 1 January 1900 and today.');
    }
    final updated = {
      for (final e in records.entries)
        e.key: Map<Prayer, PrayerStatus>.of(e.value),
    };
    updated[dateKey(day)] = {...?updated[dateKey(day)], ...changes};
    // Optional backfilled days leave the journal again when their last
    // confirmed record is cleared. Untouched gaps never become tracked days.
    if (target.isBefore(startDate) &&
        updated[dateKey(day)]!.values.every(
          (s) => s == PrayerStatus.unrecorded,
        )) {
      updated.remove(dateKey(day));
    }
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
    final historical =
        records.entries
            .where(
              (e) =>
                  e.key.compareTo(dateKey(startDate)) < 0 &&
                  e.value.values.any((s) => s != PrayerStatus.unrecorded),
            )
            .map((e) => parseDay(e.key))
            .where((day) => !day.isAfter(dayOnly(now)))
            .toList()
          ..sort();
    yield* historical;
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
    'version': 2,
    'startDate': dateKey(startDate),
    'theme': theme.name,
    'reminderEnabled': reminderEnabled,
    'reminderMinutes': reminderMinutes,
    'trackingPauses': trackingPauses.map((p) => p.toJson()).toList(),
    'mutePrayerAlertsWhenExempt': mutePrayerAlertsWhenExempt,
    'walkthroughSeen': walkthroughSeen,
    'prayerTimes': prayerTimes.toJson(),
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
          (root['version'] != 1 && root['version'] != 2)) {
        throw const FormatException('Unsupported backup version.');
      }
      final start = parseDay(root['startDate'] as String);
      if (root['version'] == 1 &&
          ((root['trackingPauses'] ?? []) as List).isNotEmpty) {
        throw const FormatException(
          'Tracking pauses require backup version 2.',
        );
      }
      if (start.isBefore(earliestJournalDay) || start.isAfter(dayOnly(now))) {
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
        if (day.isBefore(earliestJournalDay) || day.isAfter(dayOnly(now))) {
          throw const FormatException('Record date outside supported period.');
        }
        final row = e.value as Map<String, dynamic>;
        if (root['version'] == 1 && row.values.contains('exempt')) {
          throw const FormatException(
            'Exempt records require backup version 2.',
          );
        }
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
        reminderEnabled: (root['reminderEnabled'] ?? false) as bool,
        reminderMinutes: (root['reminderMinutes'] ?? 23 * 60) as int,
        trackingPauses: [
          for (final p in (root['trackingPauses'] ?? []) as List)
            TrackingPause.fromJson(p as Map<String, dynamic>),
        ],
        mutePrayerAlertsWhenExempt:
            (root['mutePrayerAlertsWhenExempt'] ?? true) as bool,
        walkthroughSeen: (root['walkthroughSeen'] ?? true) as bool,
        prayerTimes: root['prayerTimes'] == null
            ? const PrayerTimeSettings()
            : PrayerTimeSettings.fromJson(
                root['prayerTimes'] as Map<String, dynamic>,
              ),
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
