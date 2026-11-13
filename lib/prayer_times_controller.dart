import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'controller.dart';
import 'prayer_times_api.dart';
import 'prayer_times_models.dart';
import 'reminders.dart';
import 'home_widget.dart';

final prayerTimesApiProvider = Provider<PrayerTimesApi>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return PrayerTimesApi(client);
});
final prayerLocationProvider = Provider<PrayerLocation>(
  (ref) => PrayerLocation(),
);

class PrayerTimesData {
  const PrayerTimesData(this.calendar, {this.warning, this.refreshing = false});
  final PrayerCalendar calendar;
  final String? warning;
  final bool refreshing;
}

final prayerTimesProvider =
    AsyncNotifierProvider<PrayerTimesController, PrayerTimesData>(
      PrayerTimesController.new,
      retry: (_, _) => null,
    );

class PrayerTimesController extends AsyncNotifier<PrayerTimesData> {
  @override
  Future<PrayerTimesData> build() async {
    final settings = await ref.watch(
      journalProvider.selectAsync((j) => j.prayerTimes),
    );
    return _load(settings, force: false);
  }

  Future<PrayerTimesData> _load(
    PrayerTimeSettings settings, {
    required bool force,
  }) async {
    final now = ref.read(clockProvider)();
    final api = ref.read(prayerTimesApiProvider);
    final reminders = ref.read(reminderServiceProvider);
    final db = await ref.read(databaseProvider.future);
    final stored = await db.loadCalendar();
    final cached = stored?.sourceKey == settings.place.key ? stored : null;
    if (!force && cached != null && cached.fresh(now)) {
      return PrayerTimesData(cached);
    }
    try {
      final calendar = await api.fetch(settings.place, now);
      if (await db.saveCalendar(calendar, now)) {
        await reminders.syncPrayerTimes();
        await ref.read(homeWidgetServiceProvider).sync();
        if (ref.mounted) ref.invalidate(reminderAccessProvider);
      }
      return PrayerTimesData(calendar);
    } catch (_) {
      if (cached != null && cached.today(now).length == 5) {
        return PrayerTimesData(
          cached,
          warning:
              'Could not refresh. Showing saved times; alerts are available through ${cached.entries.last.date}.',
        );
      }
      throw const FormatException(
        'Unable to download prayer times. Check your internet connection and retry, or choose another place.',
      );
    }
  }

  Future<void> refresh() async {
    final settings = ref.read(journalProvider).requireValue.prayerTimes;
    final previous = state.asData?.value;
    state = previous?.calendar.sourceKey == settings.place.key
        ? AsyncData(
            PrayerTimesData(
              previous!.calendar,
              warning: previous.warning,
              refreshing: true,
            ),
          )
        : const AsyncLoading<PrayerTimesData>();
    try {
      final next = await _load(settings, force: true);
      if (ref.mounted &&
          ref.read(journalProvider).requireValue.prayerTimes.place.key ==
              settings.place.key) {
        state = AsyncData(next);
      }
    } catch (error, stack) {
      if (ref.mounted &&
          ref.read(journalProvider).requireValue.prayerTimes.place.key ==
              settings.place.key) {
        state = AsyncError(error, stack);
      }
    }
  }
}
