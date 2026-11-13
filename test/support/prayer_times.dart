import 'package:qada_tracker/database.dart';
import 'package:qada_tracker/prayer_times_controller.dart';
import 'package:qada_tracker/prayer_times_models.dart';
import '../prayer_times_controller_test.dart' show FakeTimesApi;

final fakePrayerTimes = prayerTimesApiProvider.overrideWith((ref) {
  final api = FakeTimesApi();
  ref.onDispose(api.client.close);
  return api;
});

Future<void> seedPrayerCalendar(JournalDatabase db, DateTime now) async {
  final api = FakeTimesApi();
  try {
    await db.saveCalendar(await api.fetch(malaysiaPlaces.first, now), now);
  } finally {
    api.client.close();
  }
}
