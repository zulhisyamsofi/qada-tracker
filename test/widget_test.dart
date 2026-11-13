import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qada_tracker/controller.dart';
import 'package:qada_tracker/database.dart';
import 'package:qada_tracker/main.dart';
import 'package:qada_tracker/model.dart';

void main() {
  testWidgets(
    'tick prayer, review yesterday, confirm miss and record replacement',
    (tester) async {
      final now = DateTime(2026, 11, 13, 12);
      final db = JournalDatabase(NativeDatabase.memory());
      await db.save(Journal(startDate: DateTime(2026, 11, 12)));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWith((ref) async => db),
            clockProvider.overrideWithValue(() => now),
          ],
          child: const QadaApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('0 of 5 prayers recorded today'), findsOneWidget);
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      expect(find.text('1 of 5 prayers recorded today'), findsOneWidget);
      await tester.tap(find.text('1 day needs review'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remaining missed'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pumpAndSettle();
      expect(
        find.text('You’re all caught up. No previous days need review.'),
        findsOneWidget,
      );
      Navigator.of(tester.element(find.text('A moment to review'))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Qada').last);
      await tester.pumpAndSettle();
      expect(find.text('5'), findsOneWidget);
      await tester.tap(find.text('Record').first);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Record'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('4'), findsOneWidget);
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
    },
  );

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
    expect(find.text('1 day needs review'), findsOneWidget);
    now = DateTime(2026, 11, 17);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('4 days need review'), findsOneWidget);
    expect(
      (await db.load(now)).status(DateTime(2026, 11, 13), Prayer.subuh),
      PrayerStatus.performed,
    );
    await tester.pumpWidget(const SizedBox());
    await db.close();
  });
}
