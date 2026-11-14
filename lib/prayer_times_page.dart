import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'controller.dart';
import 'prayer_times_controller.dart';
import 'prayer_times_models.dart';

/// Location and timetable controls; notification choices live in Settings.
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
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> choose(PrayerPlace place) => ref
      .read(journalProvider.notifier)
      .change((j) => j.copy(prayerTimes: j.prayerTimes.copy(place: place)));
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(journalProvider).requireValue.prayerTimes;
    final data = ref.watch(prayerTimesProvider);
    final loading = data.isLoading || (data.asData?.value.refreshing ?? false);
    final calendar = data.asData?.value.calendar;
    final matching = calendar?.sourceKey == settings.place.key;
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
        ],
      ),
    );
  }
}
