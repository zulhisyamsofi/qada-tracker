import 'model.dart';
import 'prayer_time_format.dart';
import 'prayer_times_models.dart';

/// A dated journal uses the phone's calendar day. Timetable entries use that
/// same date key, and their absolute instants are compared with the clock.
abstract final class PrayerRecordingPolicy {
  static PrayerTime? timeFor(
    PrayerCalendar? calendar,
    String sourceKey,
    DateTime day,
    Prayer prayer,
  ) {
    if (calendar == null || calendar.sourceKey != sourceKey) return null;
    final entries = calendar.entries.where((e) => e.date == dateKey(day));
    if (entries.length != 5 ||
        entries.map((e) => e.prayer).toSet().length != 5) {
      return null;
    }
    return entries.where((e) => e.prayer == prayer.name).firstOrNull;
  }

  static void validate(
    Journal before,
    Journal after,
    PrayerCalendar? calendar,
    DateTime now,
  ) {
    for (final prayer in Prayer.values) {
      final newLinkedCompletion =
          after.replacementFor(now, prayer) != null &&
          before.replacementFor(now, prayer) == null;
      final newPerformed =
          after.status(now, prayer) == PrayerStatus.performed &&
          before.status(now, prayer) != PrayerStatus.performed;
      final newMissed =
          after.status(now, prayer) == PrayerStatus.missed &&
          after.replacementFor(now, prayer) == null &&
          (before.status(now, prayer) != PrayerStatus.missed ||
              before.replacementFor(now, prayer) != null);
      if (!newLinkedCompletion && !newPerformed && !newMissed) continue;
      final action = newMissed ? 'missed' : 'performed';
      final time = timeFor(calendar, after.prayerTimes.place.key, now, prayer);
      if (time == null) {
        throw StateError(
          'Refresh today’s prayer times for ${after.prayerTimes.place.label} '
          'before marking ${prayer.label} $action.',
        );
      }
      if (now.isBefore(time.at)) {
        throw StateError(
          '${prayer.label} starts at ${formatPrayerTime(time.time)} (${calendar!.timezone}). '
          'You can mark it $action then.',
        );
      }
    }
  }
}
