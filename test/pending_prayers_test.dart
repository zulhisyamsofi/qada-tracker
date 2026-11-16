import 'package:flutter_test/flutter_test.dart';
import 'package:qada_tracker/model.dart';

void main() {
  final today = DateTime(2026, 11, 16), past = DateTime(2026, 11, 15);
  test(
    'pending counts include misses and gaps, excluding linked qada, performed and exempt prayers',
    () {
      var j = Journal(startDate: past).setStatuses(past, {
        Prayer.subuh: PrayerStatus.missed,
        Prayer.zohor: PrayerStatus.missed,
        Prayer.maghrib: PrayerStatus.performed,
        Prayer.isyak: PrayerStatus.exempt,
      }, today);
      expect(j.pendingPrayerCounts(today), {past: 3});
      j = j.completeMiss(past, Prayer.subuh, today, 'one');
      expect(j.pendingPrayerCounts(today), {past: 2});
      expect(j.undo('one').pendingPrayerCounts(today), {past: 3});
      expect(j.balance(Prayer.subuh), 0);
      expect(j.status(past, Prayer.subuh), PrayerStatus.missed);
    },
  );
  test(
    'today and untouched pre-tracking dates add no pending count; elapsed dates do',
    () {
      final j = Journal(
        startDate: past,
      ).setStatuses(today, {Prayer.subuh: PrayerStatus.missed}, today);
      expect(j.pendingPrayerCounts(today), {past: 5});
      final next = DateTime(2026, 11, 17);
      expect(j.pendingPrayerCounts(next), {past: 5, today: 5});
      expect(j.outstanding, 1);
      expect(
        j.pendingPrayerCounts(today).containsKey(DateTime(2026, 11, 14)),
        isFalse,
      );
    },
  );
  test(
    'tracking pauses exclude exempt prayers and optional older records add only their exact dates',
    () {
      final older = DateTime(2026, 10, 1);
      final j = Journal(startDate: past)
          .addPause(TrackingPause(id: 'period', from: past, through: past))
          .setStatuses(older, {Prayer.subuh: PrayerStatus.performed}, today);
      expect(j.pendingPrayerCounts(today), {older: 4});
      expect(j.outstanding, 0);
      expect(
        Journal.decode(j.export(), today).pendingPrayerCounts(today),
        j.pendingPrayerCounts(today),
      );
    },
  );
}
