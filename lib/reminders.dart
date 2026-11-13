import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReminderAccess {
  const ReminderAccess({
    required this.notifications,
    required this.exactAlarms,
    this.error,
  });
  final bool notifications;
  final bool exactAlarms;
  final String? error;
}

/// Android owns the alarms and checks SQLite at delivery, even without Flutter.
/// Other platforms remain usable without registering a notification plugin.
class ReminderService {
  ReminderService({MethodChannel? channel, bool? supported})
    : channel = channel ?? const MethodChannel('qada_tracker/reminders'),
      supported = supported ?? Platform.isAndroid {
    if (this.supported) {
      this.channel.setMethodCallHandler((call) async {
        if (call.method == 'openToday') onOpenToday?.call();
      });
    }
  }
  final MethodChannel channel;
  final bool supported;
  String? _error;
  void Function()? onOpenToday;

  Future<void> sync(bool enabled) async {
    if (!supported) return;
    try {
      await channel.invokeMethod<void>('sync', {'enabled': enabled});
      _error = null;
    } on PlatformException {
      _error =
          'Android could not schedule the reminder. Try reopening the app.';
    } on MissingPluginException {
      _error = 'Reminders are not available in this build.';
    }
  }

  Future<ReminderAccess> access() async {
    if (!supported) {
      return const ReminderAccess(notifications: false, exactAlarms: false);
    }
    try {
      final result = await channel.invokeMapMethod<String, dynamic>('access');
      return ReminderAccess(
        notifications: result?['notifications'] == true,
        exactAlarms: result?['exactAlarms'] == true,
        error: _error,
      );
    } on PlatformException {
      return const ReminderAccess(
        notifications: false,
        exactAlarms: false,
        error: 'Unable to read Android notification settings.',
      );
    } on MissingPluginException {
      return const ReminderAccess(
        notifications: false,
        exactAlarms: false,
        error: 'Reminders are not available in this build.',
      );
    }
  }

  Future<bool> requestNotifications() async =>
      supported &&
      await channel.invokeMethod<bool>('requestNotifications') == true;
  Future<void> openAlarmSettings() async {
    if (supported) await channel.invokeMethod<void>('openAlarmSettings');
  }

  Future<void> openNotificationSettings() async {
    if (supported) await channel.invokeMethod<void>('openNotificationSettings');
  }
}

final reminderServiceProvider = Provider<ReminderService>(
  (ref) => ReminderService(),
);
final reminderAccessProvider = FutureProvider<ReminderAccess>(
  (ref) => ref.watch(reminderServiceProvider).access(),
);
