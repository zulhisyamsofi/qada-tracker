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
          return {'notifications': true, 'exactAlarms': false};
        }
        if (call.method == 'requestNotifications') return true;
        return null;
      });
      final service = ReminderService(channel: channel, supported: true);
      await service.sync(true);
      expect(calls.single.arguments, {'enabled': true});
      final access = await service.access();
      expect(access.notifications, isTrue);
      expect(access.exactAlarms, isFalse);
      expect(await service.requestNotifications(), isTrue);
      await service.openAlarmSettings();
      await service.openNotificationSettings();
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
}
