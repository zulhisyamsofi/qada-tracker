import 'localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'controller.dart';
import 'model.dart';
import 'prayer_times_controller.dart';
import 'reminders.dart';

/// Both reminder preferences and their shared Android access controls.
class ReminderSettings extends ConsumerStatefulWidget {
  const ReminderSettings({super.key});
  @override
  ConsumerState<ReminderSettings> createState() => _ReminderSettingsState();
}

class _ReminderSettingsState extends ConsumerState<ReminderSettings> {
  bool busy = false;
  Future<void> action(Future<void> Function() work) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await work();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                context,
                error is FormatException
                    ? error.message
                    : 'Unable to update notification settings. Please try again.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        ref.invalidate(reminderAccessProvider);
        setState(() => busy = false);
      }
    }
  }

  Future<void> daily(bool enabled) => action(() async {
    final service = ref.read(reminderServiceProvider);
    if (enabled && !await service.requestNotifications()) {
      throw const FormatException(
        'Notifications are blocked. Enable them in Android notification settings.',
      );
    }
    if (!mounted) return;
    await ref
        .read(journalProvider.notifier)
        .change((j) => j.copy(reminderEnabled: enabled));
  });

  Future<void> chooseDailyTime() async {
    final minutes = ref.read(journalProvider).requireValue.reminderMinutes;
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      helpText: tr(context, 'Daily check-in time'),
    );
    if (selected == null || !mounted) return;
    await action(
      () => ref
          .read(journalProvider.notifier)
          .change(
            (j) =>
                j.copy(reminderMinutes: selected.hour * 60 + selected.minute),
          ),
    );
  }

  Future<void> prayer(Prayer p, bool enabled) => action(() async {
    await ref.read(journalProvider.notifier).change((j) {
      final bit = 1 << p.index;
      final mask = enabled
          ? j.prayerTimes.notificationMask | bit
          : j.prayerTimes.notificationMask & ~bit;
      return j.copy(prayerTimes: j.prayerTimes.copy(notificationMask: mask));
    });
    await ref.read(reminderServiceProvider).syncPrayerTimes();
  });

  @override
  Widget build(BuildContext context) {
    final j = ref.watch(journalProvider).requireValue;
    final service = ref.watch(reminderServiceProvider);
    final access = ref.watch(reminderAccessProvider).asData?.value;
    final enabled = j.reminderEnabled || j.prayerTimes.notifications;
    final dailyTime = TimeOfDay(
      hour: j.reminderMinutes ~/ 60,
      minute: j.reminderMinutes % 60,
    ).format(context);
    final notificationBlocked =
        service.supported &&
        enabled &&
        access != null &&
        (!(access.appNotifications ?? access.notifications) ||
            (j.prayerTimes.notifications &&
                access.prayerTimesNotifications == false) ||
            (j.reminderEnabled && !access.notifications));
    return Column(
      key: const ValueKey('notification-settings-group'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(context, 'Notifications'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          tr(
            context,
            'Choose prayer-time alerts, a daily check-in, or both. Android permission alone does not turn these reminders on.',
          ),
        ),
        SwitchListTile(
          key: const ValueKey('prayer-notifications-toggle'),
          contentPadding: EdgeInsets.zero,
          title: Text(tr(context, 'Prayer-time notifications')),
          subtitle: Text(tr(context, 'Alerts for your selected prayers.')),
          value: j.prayerTimes.notifications,
          onChanged: busy || !service.supported
              ? null
              : (value) => action(
                  () => updatePrayerNotifications(ref, enabled: value),
                ),
        ),
        SwitchListTile(
          key: const ValueKey('daily-check-in-toggle'),
          contentPadding: EdgeInsets.zero,
          title: Text(tr(context, 'Daily check-in reminder')),
          subtitle: Text(
            tr(
              context,
              '$dailyTime · if any of today’s prayers are still unrecorded.',
            ),
          ),
          value: j.reminderEnabled,
          onChanged: busy || !service.supported ? null : daily,
        ),
        ListTile(
          key: const ValueKey('daily-reminder-time'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.schedule_outlined),
          title: Text(tr(context, 'Daily check-in time')),
          subtitle: Text(tr(context, '$dailyTime · phone local time')),
          trailing: const Icon(Icons.chevron_right),
          onTap: busy || !service.supported ? null : chooseDailyTime,
        ),
        if (j.prayerTimes.notifications) ...[
          Text(tr(context, 'Notify me for')),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in Prayer.values)
                FilterChip(
                  key: ValueKey('prayer-alert-${p.name}'),
                  label: Text(tr(context, p.label)),
                  selected:
                      (j.prayerTimes.notificationMask & (1 << p.index)) != 0,
                  onSelected: busy || !service.supported
                      ? null
                      : (enabled) => prayer(p, enabled),
                ),
            ],
          ),
          if (j.prayerTimes.notificationMask == 0)
            Text(tr(context, 'No prayer alerts selected.')),
          const SizedBox(height: 12),
        ],
        if (!service.supported)
          Text(tr(context, 'Reminders are available on Android.')),
        if (!enabled) Text(tr(context, 'Both reminders are off.')),
        if (access?.error != null) Text(tr(context, access!.error!)),
        if (enabled &&
            access != null &&
            !(access.appNotifications ?? access.notifications))
          Text(tr(context, 'Android notification permission is blocked.')),
        if (j.prayerTimes.notifications &&
            access?.prayerTimesNotifications == false)
          Text(
            tr(context, 'The Prayer times notification channel is blocked.'),
          ),
        if (j.reminderEnabled && access != null && !access.notifications)
          Text(
            tr(
              context,
              'Daily check-in notifications are blocked in Android settings.',
            ),
          ),
        if (enabled && access != null && !access.exactAlarms)
          Text(
            tr(
              context,
              'Allow alarms & reminders for on-time delivery. Android may delay or skip inexact alerts.',
            ),
          ),
        if (notificationBlocked)
          TextButton(
            onPressed: busy
                ? null
                : () => action(service.openNotificationSettings),
            child: Text(tr(context, 'Android notification settings')),
          ),
        if (service.supported && enabled && access?.exactAlarms == false)
          TextButton(
            onPressed: busy ? null : () => action(service.openAlarmSettings),
            child: Text(tr(context, 'Allow alarms & reminders')),
          ),
      ],
    );
  }
}
