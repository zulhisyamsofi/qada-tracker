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
    // SQLite writes decode new settings objects even when the source is unchanged.
    // Prayer marks and notification preferences must not reload the timetable.
    await ref.watch(
      journalProvider.selectAsync((j) => j.prayerTimes.place.key),
    );
    return _load(
      ref.read(journalProvider).requireValue.prayerTimes,
      force: false,
    );
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

/// Shared consent and scheduling path for onboarding and Settings.
Future<void> updatePrayerNotifications(
  WidgetRef ref, {
  required bool enabled,
  PrayerPlace? place,
}) async {
  final service = ref.read(reminderServiceProvider);
  if (enabled) {
    final allowed = await service.requestNotifications();
    final access = await service.access();
    if (!allowed || !(access.appNotifications ?? access.notifications)) {
      throw const FormatException(
        'Notifications were not enabled. You can continue without them or allow them later in Settings.',
      );
    }
    if (access.prayerTimesNotifications == false) {
      throw const FormatException(
        'The Prayer times notification channel is blocked. Allow it in Android notification settings, or continue without reminders.',
      );
    }
  }
  if (!ref.context.mounted) return;
  await ref
      .read(journalProvider.notifier)
      .change(
        (j) => j.copy(
          prayerTimes: j.prayerTimes.copy(notifications: enabled, place: place),
        ),
      );
  await service.syncPrayerTimes();
  if (ref.context.mounted) ref.invalidate(reminderAccessProvider);
}
