import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'controller.dart';
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
              error is FormatException
                  ? error.message
                  : 'Unable to update notification settings. Please try again.',
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

  @override
  Widget build(BuildContext context) {
    final j = ref.watch(journalProvider).requireValue;
    final service = ref.watch(reminderServiceProvider);
    final access = ref.watch(reminderAccessProvider).asData?.value;
    final enabled = j.reminderEnabled || j.prayerTimes.notifications;
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
        Text('Notifications', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        const Text(
          'Choose prayer-time alerts, a nightly check-in, or both. Android permission alone does not turn these reminders on.',
        ),
        SwitchListTile(
          key: const ValueKey('prayer-notifications-toggle'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Prayer-time notifications'),
          subtitle: const Text('A reminder at each of the five prayer times.'),
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
          title: const Text('Daily check-in reminder'),
          subtitle: const Text(
            '11:00 PM · if any of today’s prayers are still unrecorded.',
          ),
          value: j.reminderEnabled,
          onChanged: busy || !service.supported ? null : daily,
        ),
        if (!service.supported)
          const Text('Reminders are available on Android.'),
        if (!enabled) const Text('Both reminders are off.'),
        if (access?.error != null) Text(access!.error!),
        if (enabled &&
            access != null &&
            !(access.appNotifications ?? access.notifications))
          const Text('Android notification permission is blocked.'),
        if (j.prayerTimes.notifications &&
            access != null &&
            access.prayerTimesNotifications == false)
          const Text('The Prayer times notification channel is blocked.'),
        if (j.reminderEnabled && access != null && !access.notifications)
          const Text(
            'Daily check-in notifications are blocked in Android settings.',
          ),
        if (enabled && access != null && !access.exactAlarms)
          const Text(
            'Allow alarms & reminders for on-time delivery. Android may delay or skip inexact alerts.',
          ),
        if (notificationBlocked)
          TextButton(
            onPressed: busy
                ? null
                : () => action(service.openNotificationSettings),
            child: const Text('Android notification settings'),
          ),
        if (service.supported && enabled && access?.exactAlarms == false)
          TextButton(
            onPressed: busy ? null : () => action(service.openAlarmSettings),
            child: const Text('Allow alarms & reminders'),
          ),
      ],
    );
  }
}
