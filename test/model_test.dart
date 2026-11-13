import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:qada_tracker/model.dart';

void main() {
  final start = DateTime(2026, 11, 10);
  final today = DateTime(2026, 11, 13, 12);
  Journal fresh() => Journal(startDate: start);

  test('unrecorded elapsed days require review but never create debt', () {
    final j = fresh();
    expect(j.outstanding, 0);
    expect(j.unresolvedDays(today).map(dateKey), [
      '2026-11-12',
      '2026-11-11',
      '2026-11-10',
    ]);
    expect(j.status(today, Prayer.subuh), PrayerStatus.unrecorded);
  });
  test('performed records survive midnight and multiple closed days', () {
    final j = fresh().setStatuses(start, {
      Prayer.subuh: PrayerStatus.performed,
    }, start);
    expect(j.status(start, Prayer.subuh), PrayerStatus.performed);
    expect(j.status(nextDay(start), Prayer.subuh), PrayerStatus.unrecorded);
    final restored = Journal.decode(j.export(), today);
    expect(restored.status(start, Prayer.subuh), PrayerStatus.performed);
    expect(restored.unresolvedDays(today).length, 3);
    expect(nextDay(DateTime(2026, 12, 31)), DateTime(2027, 1, 1));
  });
  test('confirmed miss, replacement and undo keep original history', () {
    var j = fresh().setStatuses(start, {
      Prayer.subuh: PrayerStatus.missed,
    }, today);
    expect(j.balance(Prayer.subuh), 1);
    j = j.complete(Prayer.subuh, 1, today, 'replacement-1');
    expect(j.outstanding, 0);
    expect(j.status(start, Prayer.subuh), PrayerStatus.missed);
    expect(j.status(today, Prayer.subuh), PrayerStatus.unrecorded);
    expect(j.undo('replacement-1').balance(Prayer.subuh), 1);
  });
  test('starting balances combine with confirmed misses', () {
    final balances = {
      for (final p in Prayer.values) p: p == Prayer.subuh ? 10 : 0,
    };
    final j = fresh()
        .setStarting(balances)
        .setStatuses(start, {Prayer.subuh: PrayerStatus.missed}, today)
        .complete(Prayer.subuh, 3, today, 'one');
    expect(j.balance(Prayer.subuh), 8);
    expect(j.outstanding, 8);
    expect(
      () => j.setStarting({for (final p in Prayer.values) p: 0}),
      throwsStateError,
    );
  });
  test('history correction must not erase already replaced debt', () {
    var j = fresh()
        .setStatuses(start, {Prayer.asar: PrayerStatus.missed}, today)
        .complete(Prayer.asar, 1, today, 'one');
    expect(
      () => j.setStatuses(start, {Prayer.asar: PrayerStatus.performed}, today),
      throwsStateError,
    );
    j = j.undo('one').setStatuses(start, {
      Prayer.asar: PrayerStatus.performed,
    }, today);
    expect(j.outstanding, 0);
  });
  test('bulk confirmation is all or nothing when one balance conflicts', () {
    final j = fresh()
        .setStatuses(start, {
          for (final p in Prayer.values) p: PrayerStatus.missed,
        }, today)
        .complete(Prayer.maghrib, 1, today, 'one');
    expect(
      () => j.setStatuses(start, {
        for (final p in Prayer.values) p: PrayerStatus.performed,
      }, today),
      throwsStateError,
    );
    expect(
      Prayer.values.every((p) => j.status(start, p) == PrayerStatus.missed),
      isTrue,
    );
    expect(j.balance(Prayer.subuh), 1);
  });
  test('reject invalid counts, duplicate ids, and dates outside tracking', () {
    final j = fresh().setStarting({for (final p in Prayer.values) p: 2});
    for (final n in [-1, 0, 3]) {
      expect(() => j.complete(Prayer.isyak, n, today, 'one'), throwsStateError);
    }
    final completed = j.complete(Prayer.isyak, 1, today, 'one');
    expect(
      () => completed.complete(Prayer.isyak, 1, today, 'one'),
      throwsStateError,
    );
    expect(
      () => j.setStatuses(DateTime(2026, 11, 9), {
        Prayer.asar: PrayerStatus.missed,
      }, today),
      throwsStateError,
    );
    expect(
      () => j.setStatuses(DateTime(2026, 11, 14), {
        Prayer.asar: PrayerStatus.missed,
      }, today),
      throwsStateError,
    );
    expect(
      () => j.setStarting({for (final p in Prayer.values) p: -1}),
      throwsStateError,
    );
  });
  test('backup round trip preserves every setting and record', () {
    final j = fresh()
        .setStarting({for (final p in Prayer.values) p: p.index})
        .setStatuses(start, {
          Prayer.isyak: PrayerStatus.missed,
          Prayer.subuh: PrayerStatus.performed,
        }, today)
        .complete(Prayer.isyak, 2, today, 'one')
        .copy(theme: AppTheme.dark);
    expect(Journal.decode(j.export(), today).toJson(), j.toJson());
  });
  test(
    'backup rejects invalid version, malformed data and negative balances',
    () {
      expect(() => Journal.decode('{', today), throwsFormatException);
      void invalid(void Function(Map<String, dynamic>) mutate) {
        final json = jsonDecode(fresh().export()) as Map<String, dynamic>;
        mutate(json);
        expect(
          () => Journal.decode(jsonEncode(json), today),
          throwsFormatException,
        );
      }

      invalid((j) => j['version'] = 2);
      invalid((j) => j['startDate'] = '2026-02-30');
      invalid((j) => j['startDate'] = '2027-01-01');
      invalid((j) => j['theme'] = 'unknown');
      invalid((j) => j['starting']['subuh'] = 1.5);
      invalid(
        (j) => j['records'] = {
          '2026-11-10': {'unknown': 'performed'},
        },
      );
      invalid(
        (j) => j['records'] = {
          '2026-11-10': {'subuh': 'unknown'},
        },
      );
      invalid(
        (j) => j['records'] = {
          '2026-11-09': {'subuh': 'missed'},
        },
      );
      invalid(
        (j) => j['records'] = {
          '2026-11-14': {'subuh': 'missed'},
        },
      );
      final entry = {
        'id': 'one',
        'prayer': 'subuh',
        'quantity': 1,
        'completedAt': today.toIso8601String(),
      };
      invalid((j) => j['replacements'] = [entry]);
      invalid((j) {
        j['starting']['subuh'] = 3;
        j['replacements'] = [entry, entry];
      });
    },
  );
}
