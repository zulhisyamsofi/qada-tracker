import 'support/prayer_actions.dart';
import 'support/prayer_times.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qada_tracker/controller.dart';
import 'package:qada_tracker/database.dart';
import 'package:qada_tracker/main.dart';
import 'package:qada_tracker/model.dart';

void main() {
  testWidgets('Done today, Missed yesterday, then dated qada completion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime(2026, 11, 13, 12);
    final db = JournalDatabase(NativeDatabase.memory());
    await db.save(Journal(startDate: DateTime(2026, 11, 12)));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fakePrayerTimes,
          databaseProvider.overrideWith((ref) async => db),
          clockProvider.overrideWithValue(() => now),
        ],
        child: const QadaApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('0 of 5 prayers recorded today'), findsOneWidget);
    await tester.tap(prayerActions().first);
    await tester.pumpAndSettle();
    expect(find.text('1 of 5 prayers recorded today'), findsOneWidget);
    await tester.tap(find.text('History').last);
    await tester.pumpAndSettle();
    final missed = missedButton(Prayer.subuh, DateTime(2026, 11, 12));
    await tester.scrollUntilVisible(
      missed,
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(missed);
    await tester.pumpAndSettle();
    await tester.tap(missed);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(doneButton(Prayer.subuh, DateTime(2026, 11, 12)));
    await tester.pumpAndSettle();
    final stored = await db.load(now);
    expect(
      stored.status(DateTime(2026, 11, 12), Prayer.subuh),
      PrayerStatus.missed,
    );
    expect(stored.status(now, Prayer.subuh), PrayerStatus.performed);
    expect(stored.balance(Prayer.subuh), 0);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
    await db.close();
  });

  testWidgets('midnight and resume show a fresh day without losing yesterday', (
    tester,
  ) async {
    var now = DateTime(2026, 11, 13, 23, 59, 59);
    final db = JournalDatabase(NativeDatabase.memory());
    await db.save(
      Journal(
        startDate: dayOnly(now),
      ).setStatuses(now, {Prayer.subuh: PrayerStatus.performed}, now),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fakePrayerTimes,
          databaseProvider.overrideWith((ref) async => db),
          clockProvider.overrideWithValue(() => now),
        ],
        child: const QadaApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 of 5 prayers recorded today'), findsOneWidget);
    now = DateTime(2026, 11, 14);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('0 of 5 prayers recorded today'), findsOneWidget);
    await tester.tap(find.text('History').last);
    await tester.pumpAndSettle();
    expect(
      (tester
                  .widget<Badge>(
                    find.byKey(const ValueKey('history-review-badge')),
                  )
                  .label!
              as Text)
          .data,
      '0',
    );
    now = DateTime(2026, 11, 17);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(
      (tester
                  .widget<Badge>(
                    find.byKey(const ValueKey('history-review-badge')),
                  )
                  .label!
              as Text)
          .data,
      '0',
    );
    expect(
      (await db.load(now)).status(DateTime(2026, 11, 13), Prayer.subuh),
      PrayerStatus.performed,
    );
    await tester.pumpWidget(const SizedBox());
    await db.close();
  });
}
