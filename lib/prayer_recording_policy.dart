import 'model.dart';
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
      if (after.status(now, prayer) != PrayerStatus.performed ||
          before.status(now, prayer) == PrayerStatus.performed) {
        continue;
      }
      final time = timeFor(calendar, after.prayerTimes.place.key, now, prayer);
      if (time == null) {
        throw StateError(
          'Refresh today’s prayer times for ${after.prayerTimes.place.label} '
          'before marking ${prayer.label} performed.',
        );
      }
      if (now.isBefore(time.at)) {
        throw StateError(
          '${prayer.label} starts at ${time.time} (${calendar!.timezone}). '
          'You can mark it performed then.',
        );
      }
    }
  }
}
