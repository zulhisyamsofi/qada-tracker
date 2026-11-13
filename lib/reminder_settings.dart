import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'controller.dart';
import 'reminders.dart';

class ReminderSettings extends ConsumerStatefulWidget {
  const ReminderSettings({super.key});
  @override
  ConsumerState<ReminderSettings> createState() => _ReminderSettingsState();
}

class _ReminderSettingsState extends ConsumerState<ReminderSettings> {
  bool busy = false;
  Future<void> change(bool enabled) async {
    setState(() => busy = true);
    try {
      final service = ref.read(reminderServiceProvider);
      if (enabled && !await service.requestNotifications()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Notifications are blocked. Enable them in Android notification settings.',
              ),
            ),
          );
        }
        return;
      }
      if (!mounted) return;
      await ref
          .read(journalProvider.notifier)
          .change((j) => j.copy(reminderEnabled: enabled));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to update reminder settings. Please try again.',
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

  Future<void> open(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open Android settings.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(reminderServiceProvider);
    final enabled = ref.watch(journalProvider).requireValue.reminderEnabled;
    final access = ref.watch(reminderAccessProvider).asData?.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Daily check-in reminder'),
          subtitle: const Text(
            '11:00 PM · only if none of today’s prayers are recorded.',
          ),
          value: enabled,
          onChanged: busy || !service.supported ? null : change,
        ),
        if (!service.supported)
          const Text('Reminders are available on Android.'),
        if (access?.error != null) Text(access!.error!),
        if (enabled && access != null && !access.notifications)
          const Text('Notifications are blocked in Android settings.'),
        if (enabled && access != null && !access.exactAlarms) ...[
          const Text(
            'Allow alarms & reminders for reliable 11:00 PM delivery. Without access, Android may delay or skip the reminder; it will never be sent after midnight.',
          ),
          TextButton(
            onPressed: () => open(service.openAlarmSettings),
            child: const Text('Allow alarms & reminders'),
          ),
        ],
        if (service.supported)
          TextButton(
            onPressed: () => open(service.openNotificationSettings),
            child: const Text('Android notification settings'),
          ),
      ],
    );
  }
}
