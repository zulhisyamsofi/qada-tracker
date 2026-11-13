import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'controller.dart';
import 'model.dart';
import 'prayer_recording_policy.dart';
import 'prayer_times_controller.dart';
import 'prayer_times_models.dart';
import 'reminders.dart';
import 'ui/glass.dart';

/// Compact context for the times printed on Today's prayer cards.
class TodayPrayerTimesCard extends ConsumerWidget {
  const TodayPrayerTimesCard({
    required this.day,
    required this.onSettings,
    super.key,
  });
  final DateTime day;
  final VoidCallback onSettings;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(journalProvider).requireValue.prayerTimes;
    final data = ref.watch(prayerTimesProvider);
    final loading = data.isLoading || (data.asData?.value.refreshing ?? false);
    final calendar = data.asData?.value.calendar;
    final valid =
        PrayerRecordingPolicy.timeFor(
          calendar,
          settings.place.key,
          day,
          Prayer.subuh,
        ) !=
        null;
    final now = ref.read(clockProvider)();
    final upcoming = valid
        ? calendar!.entries
              .where((e) => e.date == dateKey(day) && e.at.isAfter(now))
              .firstOrNull
        : null;
    final detail = valid
        ? '${upcoming == null ? 'All prayer times have started' : 'Next: ${Prayer.values.byName(upcoming.prayer).label} ${upcoming.time}'} · ${calendar!.timezone}'
        : loading
        ? 'Loading prayer times…'
        : 'Times unavailable. Refresh to record today’s prayers.';
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${settings.place.label}${valid ? ' · ${calendar!.zone}' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        detail,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Prayer times & location',
                  onPressed: onSettings,
                  icon: const Icon(Icons.tune_rounded),
                ),
              ],
            ),
            if (data.asData?.value.warning != null && valid)
              const Text(
                'Saved timetable · Refresh currently unavailable',
                style: TextStyle(fontSize: 12),
              ),
            if (!valid && !loading)
              TextButton.icon(
                onPressed: () =>
                    ref.read(prayerTimesProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh times'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Place, source, and alert controls are reached from Today, without a fifth tab.
class PrayerTimesSettings extends ConsumerStatefulWidget {
  const PrayerTimesSettings({super.key});
  @override
  ConsumerState<PrayerTimesSettings> createState() =>
      _PrayerTimesSettingsState();
}

class _PrayerTimesSettingsState extends ConsumerState<PrayerTimesSettings> {
  bool busy = false;
  Future<void> action(Future<void> Function() work) async {
    setState(() => busy = true);
    try {
      await work();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is FormatException
                  ? error.message
                  : 'Could not complete this action. Choose a place or try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> choose(PrayerPlace place) => ref
      .read(journalProvider.notifier)
      .change((j) => j.copy(prayerTimes: j.prayerTimes.copy(place: place)));
  Future<void> notifications(bool enabled) => action(() async {
    final service = ref.read(reminderServiceProvider);
    if (enabled && !await service.requestNotifications()) {
      throw const FormatException(
        'Notifications are blocked. Allow them in Android notification settings.',
      );
    }
    if (mounted) {
      await ref
          .read(journalProvider.notifier)
          .change(
            (j) =>
                j.copy(prayerTimes: j.prayerTimes.copy(notifications: enabled)),
          );
    }
  });
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(journalProvider).requireValue.prayerTimes;
    final data = ref.watch(prayerTimesProvider);
    final loading = data.isLoading || (data.asData?.value.refreshing ?? false);
    final calendar = data.asData?.value.calendar;
    final matching = calendar?.sourceKey == settings.place.key;
    final service = ref.watch(reminderServiceProvider);
    final access = ref.watch(reminderAccessProvider).asData?.value;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Prayer times & location',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Times appear beside each prayer on Today. Choose a Malaysian place or use your current location.',
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            key: ValueKey(settings.place.key),
            initialValue: settings.place.id,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Place'),
            items: [
              if (!malaysiaPlaces.any((p) => p.id == settings.place.id))
                DropdownMenuItem(
                  value: settings.place.id,
                  child: Text(settings.place.label),
                ),
              for (final place in malaysiaPlaces)
                DropdownMenuItem(value: place.id, child: Text(place.label)),
            ],
            onChanged: busy
                ? null
                : (id) {
                    if (id != null && id != settings.place.id) {
                      action(
                        () => choose(
                          malaysiaPlaces.firstWhere((p) => p.id == id),
                        ),
                      );
                    }
                  },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: busy
                ? null
                : () => action(() async {
                    final place = await ref
                        .read(prayerLocationProvider)
                        .current();
                    if (mounted) await choose(place);
                  }),
            icon: const Icon(Icons.my_location),
            label: const Text('Use device location'),
          ),
          const SizedBox(height: 6),
          const Text(
            'Location is requested only when you tap this button. The selected coordinates are sent to WaktuSolat to find the Malaysian prayer zone.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (busy || loading) const LinearProgressIndicator(),
          if (matching) ...[
            Text(
              'Zone ${calendar!.zone} · Times shown in ${calendar.timezone}',
            ),
            if (data.asData?.value.warning != null)
              Text(data.asData!.value.warning!),
            const SizedBox(height: 8),
            Text(
              'Downloaded through ${calendar.entries.last.date}.',
              style: const TextStyle(fontSize: 12),
            ),
          ] else if (!loading)
            const Text(
              'Unable to load prayer times. Check your connection or choose another place.',
            ),
          TextButton.icon(
            onPressed: loading
                ? null
                : () => ref.read(prayerTimesProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh times'),
          ),
          const Text(
            'Source: WaktuSolat API · JAKIM zone timetable. Check the selected zone against your local mosque or e-Solat, especially near zone boundaries.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Prayer-time notifications'),
            subtitle: const Text(
              'A notification at each of the five prayer times.',
            ),
            value: settings.notifications,
            onChanged: busy || !service.supported ? null : notifications,
          ),
          if (access?.error != null) Text(access!.error!),
          if (settings.notifications) ...[
            const Text(
              'Android refreshes downloaded times when internet is available. The last selected location is used; GPS is not tracked in the background.',
              style: TextStyle(fontSize: 12),
            ),
            if (access != null &&
                !(access.prayerTimesNotifications ?? access.notifications))
              const Text(
                'Notifications are blocked. Enable them in Android settings.',
              ),
            if (access != null && !access.exactAlarms) ...[
              const Text(
                'Allow alarms & reminders for on-time prayer alerts. Without access, Android may delay or skip alerts.',
              ),
              TextButton(
                onPressed: () => action(service.openAlarmSettings),
                child: const Text('Allow alarms & reminders'),
              ),
            ],
            TextButton(
              onPressed: () => action(service.openNotificationSettings),
              child: const Text('Android notification settings'),
            ),
          ],
        ],
      ),
    );
  }
}
