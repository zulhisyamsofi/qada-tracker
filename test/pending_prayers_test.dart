import 'package:flutter_test/flutter_test.dart';
import 'package:qada_tracker/model.dart';

void main() {
  final today = DateTime(2026, 11, 16), past = DateTime(2026, 11, 15);
  test(
    'badges include only misses, excluding linked qada, performed and exempt prayers',
    () {
      var j = Journal(startDate: past).setStatuses(past, {
        Prayer.subuh: PrayerStatus.missed,
        Prayer.zohor: PrayerStatus.missed,
        Prayer.maghrib: PrayerStatus.performed,
        Prayer.isyak: PrayerStatus.exempt,
      }, today);
      expect(j.pendingPrayerCounts(today), {past: 2});
      j = j.completeMiss(past, Prayer.subuh, today, 'one');
      expect(j.pendingPrayerCounts(today), {past: 1});
      expect(j.undo('one').pendingPrayerCounts(today), {past: 2});
      expect(j.balance(Prayer.subuh), 0);
      expect(j.status(past, Prayer.subuh), PrayerStatus.missed);
    },
  );
  test(
    'today and untouched pre-tracking dates add no pending count; elapsed unrecorded dates do not',
    () {
      final j = Journal(
        startDate: past,
      ).setStatuses(today, {Prayer.subuh: PrayerStatus.missed}, today);
      expect(j.pendingPrayerCounts(today), <DateTime, int>{});
      final next = DateTime(2026, 11, 17);
      expect(j.pendingPrayerCounts(next), {today: 1});
      expect(j.outstanding, 1);
      expect(
        j.pendingPrayerCounts(today).containsKey(DateTime(2026, 11, 14)),
        isFalse,
      );
    },
  );
  test(
    'tracking pauses exclude exempt prayers and performed optional older records add no badges',
    () {
      final older = DateTime(2026, 10, 1);
      final j = Journal(startDate: past)
          .addPause(TrackingPause(id: 'period', from: past, through: past))
          .setStatuses(older, {Prayer.subuh: PrayerStatus.performed}, today);
      expect(j.pendingPrayerCounts(today), <DateTime, int>{});
      expect(j.outstanding, 0);
      expect(
        Journal.decode(j.export(), today).pendingPrayerCounts(today),
        j.pendingPrayerCounts(today),
      );
    },
  );
}
