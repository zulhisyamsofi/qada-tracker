import 'storage/platform_native.dart'
    if (dart.library.js_interop) 'storage/platform_web.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReminderAccess {
  const ReminderAccess({
    required this.notifications,
    required this.exactAlarms,
    this.error,
    this.prayerTimesNotifications,
    this.appNotifications,
  });

  /// App permission combined with the daily check-in channel setting.
  final bool notifications;
  final bool exactAlarms;
  final String? error;
  final bool? prayerTimesNotifications;

  /// Global Android app permission, independent of either channel.
  final bool? appNotifications;
}

/// Android owns the alarms and checks SQLite at delivery, even without Flutter.
/// Other platforms remain usable without registering a notification plugin.
class ReminderService {
  ReminderService({MethodChannel? channel, bool? supported})
    : channel = channel ?? const MethodChannel('qada_tracker/reminders'),
      supported = supported ?? androidSupported {
    if (this.supported) {
      this.channel.setMethodCallHandler((call) async {
        if (call.method == 'openToday') onOpenToday?.call();
        if (call.method == 'openPrayerTimes') onOpenPrayerTimes?.call();
      });
    }
  }
  final MethodChannel channel;
  final bool supported;
  String? _error;
  String? _prayerError;
  void Function()? onOpenToday;
  void Function()? onOpenPrayerTimes;
  Future<bool> initialPrayerTimesTap() async {
    if (!supported) return false;
    try {
      return await channel.invokeMethod<bool>('initialPrayerTimesTap') == true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> syncPrayerTimes() async {
    if (!supported) return;
    try {
      await channel.invokeMethod<void>('syncPrayerTimes');
      _prayerError = null;
    } on PlatformException {
      _prayerError = 'Android could not schedule prayer-time alerts.';
    } on MissingPluginException {
      _prayerError = 'Prayer-time alerts are unavailable in this build.';
    }
  }

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
        prayerTimesNotifications: result?['prayerNotifications'] as bool?,
        appNotifications: result?['appNotifications'] as bool?,
        error: _error == null && _prayerError == null
            ? null
            : [
                if (_error != null) _error,
                if (_prayerError != null) _prayerError,
              ].join('\n'),
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
