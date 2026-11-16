import 'localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'controller.dart';
import 'model.dart';
import 'reminders.dart';

class TrackingSettings extends ConsumerStatefulWidget {
  const TrackingSettings({super.key});
  @override
  ConsumerState<TrackingSettings> createState() => _TrackingSettingsState();
}

class _TrackingSettingsState extends ConsumerState<TrackingSettings> {
  bool busy = false;
  String newId() => DateTime.now().microsecondsSinceEpoch.toString();
  Future<void> change(Journal Function(Journal) update) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await ref.read(journalProvider.notifier).change(update);
      await ref.read(reminderServiceProvider).syncPrayerTimes();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(context, error.toString().replaceFirst('Bad state: ', '')),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<bool> confirm(String title, String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(tr(context, title)),
          content: Text(tr(context, text)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr(context, 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr(context, 'Confirm')),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> dates() async {
    final today = dayOnly(ref.read(clockProvider)());
    final selected = await showDateRangePicker(
      context: context,
      firstDate: earliestJournalDay,
      lastDate: DateTime(today.year + 5 > 2200 ? 2200 : today.year + 5, 12, 31),
      currentDate: today,
      helpText: tr(context, 'Choose menstrual period dates'),
    );
    if (selected == null || !mounted) return;
    if (!await confirm(
      'Confirm exempt dates?',
      '${DateFormat.yMMMd(Localizations.localeOf(context).languageCode).format(selected.start)} – ${DateFormat.yMMMd(Localizations.localeOf(context).languageCode).format(selected.end)}\n\nUnrecorded prayers on these dates will be exempt. Existing performed and missed records will stay unchanged. Exempt prayers do not add qada or require review.',
    )) {
      return;
    }
    final pause = TrackingPause(
      id: newId(),
      from: selected.start,
      through: selected.end,
    );
    await change((j) => j.addPause(pause));
  }

  Future<void> start() async {
    var first = 0;
    final selected = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: Text(tr(context, 'Pause tracking from today')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr(
                    context,
                    'Choose the first exempt prayer today. Earlier prayers and existing performed/missed records stay unchanged. The pause continues until you resume.',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: first,
                  decoration: InputDecoration(
                    labelText: tr(context, 'First exempt prayer'),
                  ),
                  items: [
                    for (final p in Prayer.values)
                      DropdownMenuItem(
                        value: p.index,
                        child: Text(tr(context, p.label)),
                      ),
                  ],
                  onChanged: (v) => set(() => first = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr(context, 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, first),
              child: Text(tr(context, 'Confirm pause')),
            ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    final pause = TrackingPause(
      id: newId(),
      from: ref.read(clockProvider)(),
      fromPrayer: selected,
    );
    await change((j) => j.addPause(pause));
  }

  Future<void> resume(TrackingPause pause) async {
    int? first;
    final selected = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: Text(tr(context, 'Resume tracking')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr(
                    context,
                    'Choose the first prayer to track today. Earlier prayers remain exempt. Existing confirmations stay unchanged.',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: first,
                  decoration: InputDecoration(
                    labelText: tr(context, 'First prayer to track'),
                  ),
                  items: [
                    for (final p in Prayer.values)
                      DropdownMenuItem(
                        value: p.index,
                        child: Text(tr(context, p.label)),
                      ),
                    DropdownMenuItem(
                      value: 5,
                      child: Text(tr(context, 'Tomorrow')),
                    ),
                  ],
                  onChanged: (v) => set(() => first = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr(context, 'Cancel')),
            ),
            FilledButton(
              onPressed: first == null
                  ? null
                  : () => Navigator.pop(context, first),
              child: Text(tr(context, 'Resume')),
            ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    await change(
      (j) => j.resumePause(pause.id, ref.read(clockProvider)(), selected),
    );
  }

  String label(TrackingPause p) {
    final start =
        '${DateFormat.yMMMd(Localizations.localeOf(context).languageCode).format(p.from)} · from ${Prayer.values[p.fromPrayer].label}';
    final end = p.through == null
        ? 'Ongoing until you resume'
        : '${DateFormat.yMMMd(Localizations.localeOf(context).languageCode).format(p.through!)} · through ${Prayer.values[p.throughPrayer].label}';
    return '${tr(context, start)}\n${tr(context, end)}';
  }

  @override
  Widget build(BuildContext context) {
    final j = ref.watch(journalProvider).requireValue;
    final ongoing = j.trackingPauses
        .where((p) => p.through == null)
        .firstOrNull;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          tr(context, 'Menstrual period & tracking pause'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Text(
          tr(
            context,
            'Set your menstrual period dates to exclude prayers from tracking and qada. Dates are confirmed by you; the app does not predict your cycle. Existing performed and missed records stay unchanged.',
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('add-exempt-dates'),
              onPressed: busy ? null : dates,
              icon: const Icon(Icons.date_range_outlined),
              label: Text(tr(context, 'Add period dates')),
            ),
            FilledButton.icon(
              key: const ValueKey('tracking-pause-toggle'),
              onPressed: busy
                  ? null
                  : ongoing == null
                  ? start
                  : () => resume(ongoing),
              icon: Icon(
                ongoing == null
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline,
              ),
              label: Text(
                tr(
                  context,
                  ongoing == null ? 'Pause tracking' : 'Resume tracking',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(tr(context, 'Silence prayer alerts for exempt prayers')),
          subtitle: Text(
            tr(
              context,
              'Daily check-ins also ignore exempt prayers. Your reminder preferences are kept for when tracking resumes.',
            ),
          ),
          value: j.mutePrayerAlertsWhenExempt,
          onChanged: busy
              ? null
              : (v) => change((j) => j.copy(mutePrayerAlertsWhenExempt: v)),
        ),
        const Divider(height: 28),
        if (j.trackingPauses.isEmpty)
          Text(tr(context, 'No exempt date ranges or ongoing pause.')),
        for (final p in j.trackingPauses.reversed)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr(context, label(p))),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (p.through == null)
                        TextButton(
                          onPressed: busy ? null : () => resume(p),
                          child: Text(tr(context, 'Resume')),
                        ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () async {
                                if (await confirm(
                                  'Remove this exempt period?',
                                  'Unrecorded prayers in this period will need review again. Existing performed, missed, and individually exempt records stay unchanged.',
                                )) {
                                  await change((j) => j.removePause(p.id));
                                }
                              },
                        child: Text(tr(context, 'Remove')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
