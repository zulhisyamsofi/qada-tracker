import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qada_tracker/controller.dart';
import 'package:qada_tracker/database.dart';
import 'package:qada_tracker/main.dart';
import 'package:qada_tracker/model.dart';
import 'package:qada_tracker/reminders.dart';
import 'package:qada_tracker/walkthrough.dart';
import 'support/prayer_times.dart';
import 'theme_ui_test.dart' show fonts, capture, captureKey;
import 'walkthrough_test.dart' show phone, press;

final now = DateTime(2026, 11, 14, 12);

class ConsentReminders extends ReminderService {
  ConsentReminders({
    this.granted = true,
    this.appAllowed = true,
    this.channelAllowed = true,
    this.dailyAllowed,
  }) : super(supported: true);
  final bool granted, appAllowed, channelAllowed;
  final bool? dailyAllowed;
  bool exact = false;
  int requests = 0,
      prayerSyncs = 0,
      alarmSettings = 0,
      notificationSettings = 0;
  @override
  Future<void> sync(bool enabled) async {}
  @override
  Future<void> syncPrayerTimes() async {
    prayerSyncs++;
  }

  @override
  Future<bool> requestNotifications() async {
    requests++;
    return granted;
  }

  @override
  Future<ReminderAccess> access() async => ReminderAccess(
    notifications: dailyAllowed ?? appAllowed,
    appNotifications: appAllowed,
    exactAlarms: exact,
    prayerTimesNotifications: channelAllowed,
  );
  @override
  Future<void> openAlarmSettings() async {
    alarmSettings++;
    exact = true;
  }

  @override
  Future<void> openNotificationSettings() async {
    notificationSettings++;
  }
}

Widget app(JournalDatabase db, ConsentReminders service) => ProviderScope(
  overrides: [
    databaseProvider.overrideWith((ref) async => db),
    clockProvider.overrideWithValue(() => now),
    reminderServiceProvider.overrideWithValue(service),
    fakePrayerTimes,
  ],
  child: RepaintBoundary(key: captureKey, child: const QadaApp()),
);

Future<void> openConsent(WidgetTester tester) async {
  for (
    var i = 0;
    i < walkthroughSteps.indexWhere((s) => s.notificationSetup);
    i++
  ) {
    await press(tester, 'Next');
  }
  expect(find.text('Prayer-time reminders'), findsOneWidget);
}

Finder get alertSwitch =>
    find.byKey(const ValueKey('walkthrough-prayer-alerts'));
Future<void> toggleAlerts(WidgetTester tester) async {
  await tester.ensureVisible(alertSwitch);
  await tester.tap(alertSwitch);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(fonts);
  testWidgets(
    'first launch defaults selection on, asks only on consent, saves the chosen place, and can disable from Settings',
    (tester) async {
      phone(tester);
      final db = JournalDatabase(NativeDatabase.memory());
      final service = ConsentReminders();
      try {
        await tester.pumpWidget(app(db, service));
        await tester.pumpAndSettle();
        expect(service.requests, 0);
        expect((await db.load(now)).prayerTimes.notifications, isFalse);
        await openConsent(tester);
        expect(tester.widget<SwitchListTile>(alertSwitch).value, isTrue);
        expect(service.requests, 0);
        await capture(tester, 'notification-consent');
        final place = find.byKey(const ValueKey('walkthrough-place'));
        await tester.ensureVisible(place);
        await tester.tap(place);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Johor Bahru').last);
        await tester.tap(find.text('Johor Bahru').last);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Allow alarms & reminders'));
        await tester.tap(find.text('Allow alarms & reminders'));
        await tester.pumpAndSettle();
        expect(service.alarmSettings, 1);
        expect(service.requests, 0);
        await press(tester, 'Enable & continue');
        expect(service.requests, 1);
        expect(find.text('Review your History'), findsOneWidget);
        var journal = await db.load(now);
        expect(journal.prayerTimes.notifications, isTrue);
        expect(journal.prayerTimes.place.id, 'johor_bahru');
        expect(journal.reminderEnabled, isFalse);
        expect(journal.records, isEmpty);
        expect(service.prayerSyncs, greaterThan(0));
        await press(tester, 'Skip tour');
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(app(db, service));
        await tester.pumpAndSettle();
        expect(find.byType(AppWalkthrough), findsNothing);
        expect((await db.load(now)).prayerTimes.notifications, isTrue);
        await tester.tap(find.byTooltip('Settings'));
        await tester.pumpAndSettle();
        final prayerToggle = find.byKey(
          const ValueKey('prayer-notifications-toggle'),
        );
        await tester.ensureVisible(prayerToggle);
        await tester.tap(prayerToggle);
        await tester.pumpAndSettle();
        journal = await db.load(now);
        expect(journal.prayerTimes.notifications, isFalse);
        expect(journal.prayerTimes.place.id, 'johor_bahru');
        expect(service.requests, 1);
        expect(
          Journal.decode(journal.export(), now).prayerTimes.notifications,
          isFalse,
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
        await db.close();
      }
    },
  );

  testWidgets(
    'blocked daily check-in channel does not prevent opting into prayer alerts',
    (tester) async {
      phone(tester);
      final db = JournalDatabase(NativeDatabase.memory());
      final service = ConsentReminders(dailyAllowed: false);
      try {
        await tester.pumpWidget(app(db, service));
        await tester.pumpAndSettle();
        await openConsent(tester);
        await press(tester, 'Enable & continue');
        expect(find.text('Review your History'), findsOneWidget);
        expect((await db.load(now)).prayerTimes.notifications, isTrue);
        expect((await db.load(now)).reminderEnabled, isFalse);
        await press(tester, 'Skip tour');
      } finally {
        await tester.pumpWidget(const SizedBox());
        await db.close();
      }
    },
  );

  for (final failure in ['permission', 'app', 'channel']) {
    testWidgets(
      '$failure denial leaves alerts off and allows continuing without another prompt',
      (tester) async {
        phone(tester);
        final db = JournalDatabase(NativeDatabase.memory());
        final service = ConsentReminders(
          granted: failure != 'permission',
          appAllowed: failure != 'app',
          channelAllowed: failure != 'channel',
        );
        try {
          await tester.pumpWidget(app(db, service));
          await tester.pumpAndSettle();
          await openConsent(tester);
          await press(tester, 'Enable & continue');
          expect(service.requests, 1);
          expect(find.text('Prayer-time reminders'), findsOneWidget);
          expect(tester.widget<SwitchListTile>(alertSwitch).value, isFalse);
          expect((await db.load(now)).prayerTimes.notifications, isFalse);
          expect(service.notificationSettings, 0);
          expect(
            find.textContaining(
              failure == 'channel'
                  ? 'channel is blocked'
                  : 'Notifications were not enabled',
            ),
            findsOneWidget,
          );
          await press(tester, 'Next');
          expect(find.text('Review your History'), findsOneWidget);
          expect(service.requests, 1);
          expect((await db.load(now)).prayerTimes.notifications, isFalse);
          await press(tester, 'Skip tour');
        } finally {
          await tester.pumpWidget(const SizedBox());
          await db.close();
        }
      },
    );
  }

  testWidgets(
    'skipping and turning the default selection off never request notification permission; replay respects opt-out',
    (tester) async {
      phone(tester);
      final db = JournalDatabase(NativeDatabase.memory());
      final service = ConsentReminders();
      try {
        await tester.pumpWidget(app(db, service));
        await tester.pumpAndSettle();
        await press(tester, 'Skip tour');
        expect((await db.load(now)).prayerTimes.notifications, isFalse);
        expect(service.requests, 0);
        await tester.pumpWidget(const SizedBox());
        await db.save(Journal(startDate: dayOnly(now), walkthroughSeen: false));
        await tester.pumpWidget(app(db, service));
        await tester.pumpAndSettle();
        await openConsent(tester);
        await toggleAlerts(tester);
        await press(tester, 'Next');
        expect(service.requests, 0);
        expect((await db.load(now)).prayerTimes.notifications, isFalse);
        await press(tester, 'Skip tour');
        await tester.tap(find.byTooltip('Settings'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('App walkthrough'),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('App walkthrough'));
        await tester.pumpAndSettle();
        await openConsent(tester);
        expect(tester.widget<SwitchListTile>(alertSwitch).value, isFalse);
        await press(tester, 'Skip tour');
        expect(service.requests, 0);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await db.close();
      }
    },
  );

  testWidgets(
    'failed consent save remains on the step and retries without modifying prayer records',
    (tester) async {
      phone(tester);
      final db = JournalDatabase(NativeDatabase.memory());
      final service = ConsentReminders();
      try {
        await tester.pumpWidget(app(db, service));
        await tester.pumpAndSettle();
        await openConsent(tester);
        await db.customStatement(
          "CREATE TRIGGER reject_consent BEFORE UPDATE ON journal BEGIN SELECT RAISE(ABORT, 'write failure'); END",
        );
        await press(tester, 'Enable & continue');
        expect(
          find.text('Could not save reminder settings. Please try again.'),
          findsOneWidget,
        );
        expect((await db.load(now)).prayerTimes.notifications, isFalse);
        await db.customStatement('DROP TRIGGER reject_consent');
        await press(tester, 'Enable & continue');
        final saved = await db.load(now);
        expect(saved.prayerTimes.notifications, isTrue);
        expect(saved.records, isEmpty);
        expect(saved.outstanding, 0);
        await press(tester, 'Skip tour');
      } finally {
        await tester.pumpWidget(const SizedBox());
        await db.close();
      }
    },
  );

  for (final mode in [AppTheme.light, AppTheme.dark]) {
    testWidgets(
      'consent and denial fit narrow large-text ${mode.name} mode and rotation',
      (tester) async {
        phone(tester, narrow: true);
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(
              highContrast: true,
              disableAnimations: true,
            );
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final db = JournalDatabase(NativeDatabase.memory());
        final service = ConsentReminders(granted: false);
        await db.save(
          Journal(startDate: dayOnly(now), walkthroughSeen: false, theme: mode),
        );
        try {
          await tester.pumpWidget(app(db, service));
          await tester.pumpAndSettle();
          await openConsent(tester);
          await tester.ensureVisible(alertSwitch);
          await tester.pumpAndSettle();
          await capture(tester, 'notification-consent-narrow-${mode.name}');
          expect(tester.takeException(), isNull);
          await press(tester, 'Enable & continue');
          expect(tester.takeException(), isNull);
          tester.view.physicalSize = const Size(720, 320);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await press(tester, 'Next');
          expect(find.text('Review your History'), findsOneWidget);
          await press(tester, 'Skip tour');
        } finally {
          await tester.pumpWidget(const SizedBox());
          await db.close();
        }
      },
    );
  }
}
