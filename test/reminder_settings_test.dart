import 'support/prayer_times.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qada_tracker/controller.dart';
import 'package:qada_tracker/database.dart';
import 'package:qada_tracker/model.dart';
import 'package:qada_tracker/reminders.dart';
import 'package:qada_tracker/reminder_settings.dart';

class FakeReminders extends ReminderService {
  FakeReminders(this.allowed) : super(supported: true);
  final bool allowed;
  final enabledStates = <bool>[];
  @override
  Future<bool> requestNotifications() async => allowed;
  @override
  Future<ReminderAccess> access() async =>
      ReminderAccess(notifications: allowed, exactAlarms: false);
  @override
  Future<void> syncPrayerTimes() async {}
  @override
  Future<void> sync(bool enabled) async {
    enabledStates.add(enabled);
  }
}

void main() {
  for (final allowed in [true, false]) {
    testWidgets('reminder toggle respects notification permission: $allowed', (
      tester,
    ) async {
      final db = JournalDatabase(NativeDatabase.memory());
      final now = DateTime(2026, 11, 13);
      final service = FakeReminders(allowed);
      final container = ProviderContainer(
        overrides: [
          fakePrayerTimes,
          databaseProvider.overrideWith((ref) async => db),
          clockProvider.overrideWithValue(() => now),
          reminderServiceProvider.overrideWithValue(service),
        ],
      );
      final subscription = container.listen(journalProvider, (_, _) {});
      addTearDown(() async {
        subscription.close();
        container.dispose();
        await db.close();
      });
      await container.read(journalProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: ReminderSettings()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('11:00 PM · if any of today’s prayers are still unrecorded.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('daily-check-in-toggle')));
      await tester.pumpAndSettle();
      expect((await db.load(now)).reminderEnabled, allowed);
      expect(service.enabledStates.last, allowed);
      if (allowed) {
        await tester.tap(find.text('Notification permissions & testing'));
        await tester.pumpAndSettle();
        expect(find.text('Allow alarms & reminders'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('daily-check-in-toggle')));
        await tester.pumpAndSettle();
        expect(service.enabledStates.last, isFalse);
        expect((await db.load(now)).reminderEnabled, isFalse);
        await container
            .read(journalProvider.notifier)
            .restore(Journal(startDate: now).copy(reminderEnabled: true));
        expect(service.enabledStates.last, isTrue);
        await container
            .read(journalProvider.notifier)
            .restore(Journal(startDate: now));
        expect(service.enabledStates.last, isFalse);
      } else {
        expect(
          find.text(
            'Notifications are blocked. Enable them in Android notification settings.',
          ),
          findsOneWidget,
        );
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('both switches are together and remain independent', (
    tester,
  ) async {
    final db = JournalDatabase(NativeDatabase.memory());
    final now = DateTime(2026, 11, 14);
    final service = FakeReminders(true);
    await db.save(Journal(startDate: now, reminderEnabled: true));
    final container = ProviderContainer(
      overrides: [
        fakePrayerTimes,
        databaseProvider.overrideWith((ref) async => db),
        clockProvider.overrideWithValue(() => now),
        reminderServiceProvider.overrideWithValue(service),
      ],
    );
    final listener = container.listen(journalProvider, (_, _) {});
    try {
      await container.read(journalProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: ReminderSettings()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final prayer = find.byKey(const ValueKey('prayer-notifications-toggle'));
      final daily = find.byKey(const ValueKey('daily-check-in-toggle'));
      expect(find.text('Notifications'), findsOneWidget);
      expect(tester.widget<SwitchListTile>(prayer).value, isFalse);
      expect(tester.widget<SwitchListTile>(daily).value, isTrue);
      await tester.tap(prayer);
      await tester.pumpAndSettle();
      expect((await db.load(now)).prayerTimes.notifications, isTrue);
      expect((await db.load(now)).reminderEnabled, isTrue);
      await tester.tap(daily);
      await tester.pumpAndSettle();
      expect((await db.load(now)).prayerTimes.notifications, isTrue);
      expect((await db.load(now)).reminderEnabled, isFalse);
      await tester.tap(prayer);
      await tester.pumpAndSettle();
      expect(find.text('Both reminders are off.'), findsOneWidget);
      expect((await db.load(now)).prayerTimes.notifications, isFalse);
      expect((await db.load(now)).reminderEnabled, isFalse);
    } finally {
      await tester.pumpWidget(const SizedBox());
      listener.close();
      container.dispose();
      await db.close();
    }
  });
}
