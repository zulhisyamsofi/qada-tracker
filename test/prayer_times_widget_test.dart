import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qada_tracker/controller.dart';
import 'package:qada_tracker/database.dart';
import 'package:qada_tracker/main.dart';
import 'package:qada_tracker/model.dart';
import 'package:qada_tracker/reminders.dart';
import 'package:qada_tracker/prayer_times_page.dart';
import 'package:qada_tracker/prayer_times_api.dart';
import 'package:qada_tracker/prayer_times_controller.dart';
import 'package:qada_tracker/prayer_times_models.dart';
import 'prayer_times_controller_test.dart' show FakeTimesApi;

class DeniedLocation extends PrayerLocation {
  @override
  Future<PrayerPlace> current() async => throw const FormatException(
    'Location access was not granted. You can still choose a place from the list.',
  );
}

void main() {
  testWidgets(
    'Times tab displays saved times and preserves selection on GPS denial',
    (tester) async {
      final now = DateTime.utc(2026, 11, 13, 2);
      final db = JournalDatabase(NativeDatabase.memory());
      final api = FakeTimesApi();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWith((ref) async => db),
            clockProvider.overrideWithValue(() => now),
            prayerTimesApiProvider.overrideWithValue(api),
            prayerLocationProvider.overrideWithValue(DeniedLocation()),
          ],
          child: const QadaApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Times'));
      await tester.pumpAndSettle();
      expect(find.text('Prayer Times'), findsOneWidget);
      expect(
        find.text('Zone WLY01 · Times shown in Asia/Kuala_Lumpur'),
        findsOneWidget,
      );
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use device location'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Location access was not granted. You can still choose a place from the list.',
        ),
        findsOneWidget,
      );
      expect((await db.load(now)).prayerTimes.place.id, 'kuala_lumpur');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Putrajaya').last);
      await tester.pumpAndSettle();
      expect((await db.load(now)).prayerTimes.place.id, 'putrajaya');
      expect((await db.loadCalendar())!.sourceKey, malaysiaPlaces[1].key);
      await tester.pumpWidget(const SizedBox());
      api.client.close();
      await db.close();
    },
  );
  for (final enabled in [true, false]) {
    testWidgets('offline notification control: initially enabled $enabled', (
      tester,
    ) async {
      final now = DateTime.utc(2026, 11, 13, 2);
      final db = JournalDatabase(NativeDatabase.memory());
      final api = FakeTimesApi()..fail = true;
      final service = _TimesReminders();
      await db.save(
        Journal(
          startDate: dayOnly(now),
        ).copy(prayerTimes: PrayerTimeSettings(notifications: enabled)),
      );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith((ref) async => db),
          clockProvider.overrideWithValue(() => now),
          prayerTimesApiProvider.overrideWithValue(api),
          reminderServiceProvider.overrideWithValue(service),
        ],
      );
      final journalListener = container.listen(journalProvider, (_, _) {});
      await container.read(journalProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: PrayerTimesPage())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byType(SwitchListTile), 120);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      // Turning off is always possible offline. A denied opt-in stays off.
      expect((await db.load(now)).prayerTimes.notifications, isFalse);
      if (!enabled) {
        expect(
          find.text(
            'Notifications are blocked. Allow them in Android notification settings.',
          ),
          findsOneWidget,
        );
      }
      await tester.pumpWidget(const SizedBox());
      journalListener.close();
      container.dispose();
      api.client.close();
      await db.close();
    });
  }
}

class _TimesReminders extends ReminderService {
  _TimesReminders() : super(supported: true);
  @override
  Future<void> sync(bool enabled) async {}
  @override
  Future<void> syncPrayerTimes() async {}
  @override
  Future<bool> requestNotifications() async => false;
  @override
  Future<ReminderAccess> access() async => const ReminderAccess(
    notifications: false,
    exactAlarms: false,
    prayerTimesNotifications: false,
  );
}
