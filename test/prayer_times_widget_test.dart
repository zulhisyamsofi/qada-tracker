import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qada_tracker/controller.dart';
import 'package:qada_tracker/database.dart';
import 'package:qada_tracker/main.dart';
import 'package:qada_tracker/model.dart';
import 'package:qada_tracker/reminders.dart';
import 'package:qada_tracker/reminder_settings.dart';
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
    'Today displays five inline times and preserves selection on GPS denial',
    (tester) async {
      final now = DateTime.utc(2026, 11, 13, 2);
      final db = JournalDatabase(NativeDatabase.memory());
      await db.save(Journal(startDate: dayOnly(now)));
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
      expect(find.text('Times'), findsNothing);
      for (final label in [
        'Subuh (05:48)',
        'Zohor (13:00)',
        'Asar (16:22)',
        'Maghrib (18:58)',
        'Isyak (20:11)',
      ]) {
        await tester.scrollUntilVisible(find.text(label), 120);
        expect(find.text(label), findsOneWidget);
      }
      await tester.drag(find.byType(ListView), const Offset(0, 1000));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Prayer times & location'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Prayer times & location'));
      await tester.pumpAndSettle();
      expect(find.text('Prayer times & location'), findsOneWidget);
      expect(find.byType(PrayerTimesSettings), findsOneWidget);
      expect(find.text('Prayer-time notifications'), findsNothing);
      expect(find.text('Daily check-in reminder'), findsNothing);
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
      await db.save(Journal(startDate: dayOnly(now)));
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
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: ReminderSettings()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('prayer-notifications-toggle')),
        120,
      );
      await tester.tap(
        find.byKey(const ValueKey('prayer-notifications-toggle')),
      );
      await tester.pumpAndSettle();
      // Turning off is always possible offline. A denied opt-in stays off.
      expect((await db.load(now)).prayerTimes.notifications, isFalse);
      if (!enabled) {
        expect(
          find.text(
            'Notifications were not enabled. You can continue without them or allow them later in Settings.',
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

  testWidgets(
    'early checkbox and menu actions explain the restriction and unlock at start',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var now = DateTime.utc(2026, 11, 13, 2);
      final db = JournalDatabase(NativeDatabase.memory());
      await db.save(Journal(startDate: dayOnly(now)));
      final api = FakeTimesApi();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWith((ref) async => db),
            clockProvider.overrideWithValue(() => now),
            prayerTimesApiProvider.overrideWithValue(api),
          ],
          child: const QadaApp(),
        ),
      );
      await tester.pumpAndSettle();
      final zohor = find.byWidgetPredicate(
        (w) => w is Checkbox && w.semanticLabel == 'Zohor performed',
      );
      await tester.scrollUntilVisible(zohor, 150);
      await tester.pumpAndSettle();
      await tester.tap(zohor);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Zohor starts at 13:00 (Asia/Kuala_Lumpur). You can mark it performed then.',
        ),
        findsOneWidget,
      );
      expect(
        (await db.load(now)).status(now, Prayer.zohor),
        PrayerStatus.unrecorded,
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byTooltip('Update Isyak'), 150);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Update Isyak'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark performed'));
      await tester.pumpAndSettle();
      expect(
        (await db.load(now)).status(now, Prayer.isyak),
        PrayerStatus.unrecorded,
      );
      // No reopen is necessary; the write rechecks the real clock at the boundary.
      now = DateTime.utc(2026, 11, 13, 5);
      await tester.drag(find.byType(ListView), const Offset(0, 1000));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(zohor, 150);
      await tester.pumpAndSettle();
      await tester.tap(zohor);
      await tester.pumpAndSettle();
      expect(
        (await db.load(now)).status(now, Prayer.zohor),
        PrayerStatus.performed,
      );
      await tester.pumpWidget(const SizedBox());
      api.client.close();
      await db.close();
    },
  );

  testWidgets(
    'prayer notification taps open Today after leaving the first tab',
    (tester) async {
      final now = DateTime.utc(2026, 11, 13, 2);
      final db = JournalDatabase(NativeDatabase.memory());
      await db.save(Journal(startDate: dayOnly(now)));
      final api = FakeTimesApi();
      final service = _TimesReminders();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWith((ref) async => db),
            clockProvider.overrideWithValue(() => now),
            prayerTimesApiProvider.overrideWithValue(api),
            reminderServiceProvider.overrideWithValue(service),
          ],
          child: const QadaApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Progress').last);
      await tester.pumpAndSettle();
      expect(find.text('Every step counts'), findsOneWidget);
      service.onOpenPrayerTimes!();
      await tester.pumpAndSettle();
      expect(find.text('0 of 5 prayers recorded today'), findsOneWidget);
      final repairedBefore = service.repairs;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(service.repairs, greaterThan(repairedBefore));
      expect(find.text('Times'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      api.client.close();
      await db.close();
    },
  );
}

class _TimesReminders extends ReminderService {
  _TimesReminders() : super(supported: true);
  @override
  Future<void> sync(bool enabled) async {}
  int repairs = 0;
  @override
  Future<void> syncPrayerTimes() async {
    repairs++;
  }

  @override
  Future<bool> requestNotifications() async => false;
  @override
  Future<ReminderAccess> access() async => const ReminderAccess(
    notifications: false,
    exactAlarms: false,
    prayerTimesNotifications: false,
  );
}
