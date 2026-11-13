import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'controller.dart';
import 'model.dart';
import 'prayer_times_controller.dart';
import 'prayer_times_models.dart';
import 'reminders.dart';

class PrayerTimesPage extends ConsumerStatefulWidget {
  const PrayerTimesPage({super.key});
  @override
  ConsumerState<PrayerTimesPage> createState() => _PrayerTimesPageState();
}

class _PrayerTimesPageState extends ConsumerState<PrayerTimesPage> {
  bool busy = false;
  Timer? clock;
  @override
  void initState() {
    super.initState();
    clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    clock?.cancel();
    super.dispose();
  }

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
    if (!mounted) return;
    await ref
        .read(journalProvider.notifier)
        .change(
          (j) =>
              j.copy(prayerTimes: j.prayerTimes.copy(notifications: enabled)),
        );
  });
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(journalProvider).requireValue.prayerTimes;
    final data = ref.watch(prayerTimesProvider);
    final now = ref.read(clockProvider)();
    final service = ref.watch(reminderServiceProvider);
    final access = ref.watch(reminderAccessProvider).asData?.value;
    return RefreshIndicator(
      onRefresh: () => ref.read(prayerTimesProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Text(
            'A little space for prayer',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text('Choose a Malaysian place or use your current location.'),
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
          const Text(
            'Location is requested only when you tap this button. The selected coordinates are sent to WaktuSolat to find the Malaysian prayer zone.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 20),
          if (busy || data.isLoading) const LinearProgressIndicator(),
          ...data.when(
            loading: () => [
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Downloading prayer times…'),
              ),
            ],
            error: (error, _) => [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        error is FormatException
                            ? error.message
                            : 'Unable to load prayer times.',
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () =>
                            ref.read(prayerTimesProvider.notifier).refresh(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            data: (value) {
              final calendar = value.calendar;
              // A location change must never briefly show another place's times.
              if (calendar.sourceKey != settings.place.key) {
                return [const Text('Updating place…')];
              }
              final times = calendar.today(now);
              final future = calendar.entries.where((e) => e.at.isAfter(now));
              final next = future.isEmpty ? null : future.first;
              return [
                if (value.warning != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(value.warning!),
                    ),
                  ),
                Text(
                  DateFormat(
                    'EEEE, d MMMM yyyy',
                  ).format(calendar.localNow(now)),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Zone ${calendar.zone} · Times shown in ${calendar.timezone}',
                ),
                const SizedBox(height: 16),
                if (next != null)
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: ListTile(
                      leading: const Icon(Icons.schedule),
                      title: Text(
                        'Next: ${Prayer.values.byName(next.prayer).label}',
                      ),
                      subtitle: Text('${next.time} · ${next.date}'),
                    ),
                  ),
                if (times.isEmpty)
                  Card(
                    child: ListTile(
                      title: const Text('No saved times for today'),
                      subtitle: const Text(
                        'Connect to the internet and refresh.',
                      ),
                      trailing: IconButton(
                        tooltip: 'Refresh times',
                        onPressed: () =>
                            ref.read(prayerTimesProvider.notifier).refresh(),
                        icon: const Icon(Icons.refresh),
                      ),
                    ),
                  ),
                for (final time in times)
                  Card(
                    child: ListTile(
                      leading: Icon(
                        time == next
                            ? Icons.notifications_active_outlined
                            : Icons.access_time,
                      ),
                      title: Text(
                        Prayer.values.byName(time.prayer).label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing: Text(
                        time.time,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                if (settings.notifications)
                  Text(
                    'Downloaded through ${calendar.entries.last.date}.',
                    style: const TextStyle(fontSize: 12),
                  ),
                const SizedBox(height: 16),
                const Text(
                  'Source: WaktuSolat API · JAKIM zone timetable. Check the selected zone against your local mosque or e-Solat, especially near zone boundaries.',
                  style: TextStyle(fontSize: 12),
                ),
                TextButton.icon(
                  onPressed: data.isLoading
                      ? null
                      : () => ref.read(prayerTimesProvider.notifier).refresh(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh times'),
                ),
              ];
            },
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
