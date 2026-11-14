import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qada_tracker/model.dart';
import 'package:qada_tracker/reminders.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/reminders');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('old backups default to reminders off; new preference round trips', () {
    final now = DateTime(2026, 11, 13);
    final old = Journal(startDate: now).toJson()..remove('reminderEnabled');
    expect(Journal.decode(jsonEncode(old), now).reminderEnabled, isFalse);
    final enabled = Journal(startDate: now).copy(reminderEnabled: true);
    expect(Journal.decode(enabled.export(), now).reminderEnabled, isTrue);
    expect(enabled.copy(theme: AppTheme.dark).reminderEnabled, isTrue);
    old['reminderEnabled'] = 'yes';
    expect(() => Journal.decode(jsonEncode(old), now), throwsFormatException);
  });
  test(
    'bridge synchronizes opt-in, permissions, and Android settings',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'access') {
          return {
            'notifications': false,
            'appNotifications': true,
            'prayerNotifications': true,
            'exactAlarms': false,
          };
        }
        if (call.method == 'requestNotifications') return true;
        return null;
      });
      final service = ReminderService(channel: channel, supported: true);
      await service.sync(true);
      expect(calls.single.arguments, {'enabled': true});
      final access = await service.access();
      expect(access.notifications, isFalse);
      expect(access.appNotifications, isTrue);
      expect(access.prayerTimesNotifications, isTrue);
      expect(access.exactAlarms, isFalse);
      expect(await service.requestNotifications(), isTrue);
      await service.openAlarmSettings();
      await service.openNotificationSettings();
      await service.openAppSettings();
      await service.sendTestPrayerNotification();
      expect(calls.any((c) => c.method == 'testPrayerNotification'), isTrue);
      await service.sync(false);
      expect(calls.last.arguments, {'enabled': false});
    },
  );
  test(
    'scheduling failure does not throw away a saved prayer record',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'sync') throw PlatformException(code: 'alarm');
        return {'notifications': true, 'exactAlarms': true};
      });
      final service = ReminderService(channel: channel, supported: true);
      await service.sync(true);
      expect((await service.access()).error, isNotNull);
    },
  );
  test(
    'daily and prayer scheduling failures stay visible independently',
    () async {
      var failPrayer = true;
      var failDaily = false;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'syncPrayerTimes' && failPrayer) {
          throw PlatformException(code: 'prayer');
        }
        if (call.method == 'sync' && failDaily) {
          throw PlatformException(code: 'daily');
        }
        if (call.method == 'access') {
          return {
            'notifications': true,
            'appNotifications': true,
            'prayerNotifications': true,
            'exactAlarms': true,
          };
        }
        return null;
      });
      final service = ReminderService(channel: channel, supported: true);
      await service.syncPrayerTimes();
      await service.sync(true);
      expect((await service.access()).error, contains('prayer-time'));
      failPrayer = false;
      failDaily = true;
      await service.sync(true);
      await service.syncPrayerTimes();
      expect((await service.access()).error, contains('reminder'));
      expect((await service.access()).error, isNot(contains('prayer-time')));
    },
  );
}
