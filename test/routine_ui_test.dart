import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qada_tracker/controller.dart';
import 'package:qada_tracker/database.dart';
import 'package:qada_tracker/main.dart';
import 'package:qada_tracker/model.dart';
import 'package:qada_tracker/prayer_times_models.dart';
import 'package:qada_tracker/reminders.dart';
import 'package:qada_tracker/tracking_settings.dart';
import 'support/prayer_times.dart';
import 'theme_ui_test.dart' show fonts, capture, captureKey;

class RoutineReminders extends ReminderService {
  RoutineReminders() : super(supported: true);
  int prayerSyncs = 0;
  @override
  Future<void> sync(bool enabled) async {}
  @override
  Future<void> syncPrayerTimes() async {
    prayerSyncs++;
  }

  @override
  Future<bool> requestNotifications() async => true;
  @override
  Future<ReminderAccess> access() async => const ReminderAccess(
    notifications: true,
    appNotifications: true,
    prayerTimesNotifications: true,
    exactAlarms: true,
  );
}

final today = DateTime(2026, 11, 14, 23);
Widget app(
  JournalDatabase db,
  RoutineReminders reminders,
  DateTime Function() clock,
) => ProviderScope(
  overrides: [
    databaseProvider.overrideWith((ref) async => db),
    clockProvider.overrideWithValue(clock),
    fakePrayerTimes,
    reminderServiceProvider.overrideWithValue(reminders),
  ],
  child: RepaintBoundary(key: captureKey, child: const QadaApp()),
);
void phone(WidgetTester tester, {bool narrow = false}) {
  tester.view.physicalSize = Size(narrow ? 320 : 390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> management(WidgetTester tester) async {
  await tap(tester, find.byTooltip('Settings'));
  await tap(tester, find.text('Menstrual period & tracking pause'));
  expect(find.byType(TrackingSettings), findsOneWidget);
}

void main() {
  setUpAll(fonts);
  for (final mode in [AppTheme.light, AppTheme.dark]) {
    testWidgets(
      '+1 qada has exact Undo, does not change daily records, and stops at zero ${mode.name}',
      (tester) async {
        phone(tester, narrow: mode == AppTheme.dark);
        if (mode == AppTheme.dark) {
          tester.platformDispatcher.textScaleFactorTestValue = 1.6;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        }
        final db = JournalDatabase(NativeDatabase.memory());
        final reminders = RoutineReminders();
        final yesterday = DateTime(2026, 11, 13);
        await db.save(
          Journal(startDate: yesterday, theme: mode)
              .setStarting({
                for (final p in Prayer.values) p: p == Prayer.subuh ? 1 : 0,
              })
              .setStatuses(yesterday, {
                Prayer.subuh: PrayerStatus.missed,
              }, today),
        );
        try {
          await tester.pumpWidget(app(db, reminders, () => today));
          await tester.pumpAndSettle();
          await tap(tester, find.text('Qada').last);
          final plus = find.byKey(const ValueKey('qada-quick-subuh'));
          await tap(tester, plus);
          await tap(tester, plus);
          var j = await db.load(today);
          expect(j.balance(Prayer.subuh), 0);
          expect(j.replacements.length, 2);
          expect(j.status(today, Prayer.subuh), PrayerStatus.unrecorded);
          expect(j.status(yesterday, Prayer.subuh), PrayerStatus.missed);
          expect(tester.widget<OutlinedButton>(plus).onPressed, isNull);
          await capture(tester, 'qada-quick-${mode.name}');
          await tester.tap(
            find.descendant(
              of: find.byType(SnackBar),
              matching: find.text('Undo'),
            ),
          );
          await tester.pumpAndSettle();
          j = await db.load(today);
          expect(j.balance(Prayer.subuh), 1);
          expect(j.replacements.length, 1);
          expect(tester.widget<OutlinedButton>(plus).onPressed, isNotNull);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await db.close();
        }
      },
    );
  }
  testWidgets(
    'daily time picker and selective prayer alerts persist and cancellation preserves settings',
    (tester) async {
      phone(tester);
      final db = JournalDatabase(NativeDatabase.memory());
      final reminders = RoutineReminders();
      await db.save(
        Journal(
          startDate: dayOnly(today),
          prayerTimes: const PrayerTimeSettings(notifications: true),
        ),
      );
      try {
        await tester.pumpWidget(app(db, reminders, () => today));
        await tester.pumpAndSettle();
        await tap(tester, find.byTooltip('Settings'));
        await tap(tester, find.byKey(const ValueKey('prayer-alert-subuh')));
        expect((await db.load(today)).prayerTimes.notificationMask, 30);
        await tap(tester, find.byKey(const ValueKey('daily-reminder-time')));
        await tester.tap(find.byTooltip('Switch to text input mode'));
        await tester.pumpAndSettle();
        final fields = find.byType(TextField);
        await tester.enterText(fields.at(0), '10');
        await tester.enterText(fields.at(1), '15');
        await tester.tap(find.text('PM').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        expect((await db.load(today)).reminderMinutes, 22 * 60 + 15);
        await tap(tester, find.byKey(const ValueKey('daily-reminder-time')));
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect((await db.load(today)).reminderMinutes, 1335);
        await tap(
          tester,
          find.byKey(const ValueKey('prayer-notifications-toggle')),
        );
        expect((await db.load(today)).prayerTimes.notificationMask, 30);
        await tap(
          tester,
          find.byKey(const ValueKey('prayer-notifications-toggle')),
        );
        expect(
          tester
              .widget<FilterChip>(
                find.byKey(const ValueKey('prayer-alert-subuh')),
              )
              .selected,
          isFalse,
        );
        await capture(tester, 'routine-notifications');
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(app(db, reminders, () => today));
        await tester.pumpAndSettle();
        expect((await db.load(today)).reminderMinutes, 1335);
        expect((await db.load(today)).prayerTimes.notificationMask, 30);
        expect(reminders.prayerSyncs, greaterThan(1));
      } finally {
        await tester.pumpWidget(const SizedBox());
        await db.close();
      }
    },
  );
  testWidgets(
    'pause confirms and preserves records; partial-day resume keeps earlier days exempt',
    (tester) async {
      phone(tester);
      var now = today;
      final db = JournalDatabase(NativeDatabase.memory());
      final reminders = RoutineReminders();
      await db.save(
        Journal(
          startDate: dayOnly(today),
        ).setStatuses(today, {Prayer.subuh: PrayerStatus.performed}, today),
      );
      try {
        await tester.pumpWidget(app(db, reminders, () => now));
        await tester.pumpAndSettle();
        await management(tester);
        await tap(tester, find.text('Pause tracking'));
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect((await db.load(now)).trackingPauses, isEmpty);
        await tap(tester, find.text('Pause tracking'));
        await tester.tap(find.text('Confirm pause'));
        await tester.pumpAndSettle();
        var j = await db.load(now);
        expect(j.status(today, Prayer.subuh), PrayerStatus.performed);
        expect(j.status(today, Prayer.zohor), PrayerStatus.exempt);
        await capture(tester, 'tracking-management-active');
        Navigator.of(tester.element(find.byType(TrackingSettings))).pop();
        await tester.pumpAndSettle();
        expect(find.text('1/1'), findsOneWidget);
        final zohor = find.byWidgetPredicate(
          (w) =>
              w is Checkbox &&
              w.semanticLabel == 'Zohor exempt; no prayer to record',
        );
        expect(tester.widget<Checkbox>(zohor).onChanged, isNull);
        await capture(tester, 'today-partially-exempt');
        now = DateTime(2026, 11, 16, 18);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(find.text('No prayers to record today'), findsOneWidget);
        await management(tester);
        await tap(tester, find.text('Resume tracking'));
        final resumeButton = find.widgetWithText(FilledButton, 'Resume');
        expect(tester.widget<FilledButton>(resumeButton).onPressed, isNull);
        await tester.tap(find.byType(DropdownButtonFormField<int>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Asar').last);
        await tester.pumpAndSettle();
        await tester.tap(resumeButton);
        await tester.pumpAndSettle();
        j = await db.load(now);
        expect(j.status(now, Prayer.zohor), PrayerStatus.exempt);
        expect(j.status(now, Prayer.asar), PrayerStatus.unrecorded);
        expect(j.fullyExempt(DateTime(2026, 11, 15)), isTrue);
        expect(j.outstanding, 0);
        Navigator.of(tester.element(find.byType(TrackingSettings))).pop();
        await tester.pumpAndSettle();
        await tap(tester, find.text('History').last);
        expect(
          tester
              .widget<Badge>(find.byKey(const ValueKey('history-review-badge')))
              .isLabelVisible,
          isFalse,
        );
        await capture(tester, 'history-exempt-dates');
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await db.close();
      }
    },
  );
  testWidgets(
    'date-range exemptions require confirmation and preserve a confirmed miss',
    (tester) async {
      phone(tester);
      final db = JournalDatabase(NativeDatabase.memory());
      final reminders = RoutineReminders();
      final yesterday = DateTime(2026, 11, 13);
      await db.save(
        Journal(
          startDate: yesterday,
        ).setStatuses(yesterday, {Prayer.subuh: PrayerStatus.missed}, today),
      );
      try {
        await tester.pumpWidget(app(db, reminders, () => today));
        await tester.pumpAndSettle();
        await management(tester);
        Future<void> select() async {
          await tap(tester, find.text('Add period dates'));
          await tester.tap(find.text('13').hitTestable().first);
          await tester.pumpAndSettle();
          await tester.tap(find.text('14').hitTestable().first);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Save'));
          await tester.pumpAndSettle();
        }

        await select();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect((await db.load(today)).trackingPauses, isEmpty);
        await select();
        await tester.tap(find.text('Confirm'));
        await tester.pumpAndSettle();
        final j = await db.load(today);
        expect(j.trackingPauses.single.from, yesterday);
        expect(j.trackingPauses.single.through, dayOnly(today));
        expect(j.status(yesterday, Prayer.subuh), PrayerStatus.missed);
        expect(j.status(yesterday, Prayer.zohor), PrayerStatus.exempt);
        expect(j.outstanding, 1);
        expect(j.unresolvedDays(today), isEmpty);
        await tap(tester, find.text('Remove'));
        await tester.tap(find.text('Confirm'));
        await tester.pumpAndSettle();
        expect((await db.load(today)).unresolvedDays(today), [yesterday]);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await db.close();
      }
    },
  );
  testWidgets('individual exemption is absent from prayer menus', (
    tester,
  ) async {
    phone(tester);
    final db = JournalDatabase(NativeDatabase.memory());
    await db.save(Journal(startDate: dayOnly(today)));
    try {
      await tester.pumpWidget(app(db, RoutineReminders(), () => today));
      await tester.pumpAndSettle();
      await tap(tester, find.byTooltip('Update Subuh'));
      expect(find.text('Mark exempt'), findsNothing);
      expect(find.text('Mark missed'), findsOneWidget);
      expect((await db.load(today)).records, isEmpty);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await db.close();
    }
  });
}
