import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qada_tracker/controller.dart';
import 'package:qada_tracker/database.dart';
import 'package:qada_tracker/main.dart';
import 'package:qada_tracker/model.dart';
import 'package:qada_tracker/walkthrough.dart';
import 'support/prayer_times.dart';
import 'theme_ui_test.dart' show fonts, capture, captureKey;

final now = DateTime(2026, 11, 14, 12);
Widget app(JournalDatabase db) => ProviderScope(
  overrides: [
    databaseProvider.overrideWith((ref) async => db),
    clockProvider.overrideWithValue(() => now),
    fakePrayerTimes,
  ],
  child: RepaintBoundary(key: captureKey, child: const QadaApp()),
);

Future<void> press(WidgetTester tester, String label) async {
  await tester.tap(
    find.widgetWithText(TextButton, label).evaluate().isNotEmpty
        ? find.widgetWithText(TextButton, label)
        : label == 'Back'
        ? find.widgetWithText(OutlinedButton, label)
        : find.widgetWithText(FilledButton, label),
  );
  await tester.pumpAndSettle();
}

void phone(WidgetTester tester, {bool narrow = false}) {
  tester.view.physicalSize = narrow
      ? const Size(320, 720)
      : const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUpAll(fonts);
  testWidgets(
    'first launch tours real screens, blocks edits, persists completion across disk restart',
    (tester) async {
      phone(tester);
      final directory = Directory.systemTemp.createTempSync('qada-guide-');
      final file = File('${directory.path}/journal.sqlite');
      var db = JournalDatabase(NativeDatabase(file));
      try {
        await tester.pumpWidget(app(db));
        await tester.pumpAndSettle();
        expect(find.text(walkthroughSteps.first.title), findsOneWidget);
        expect((await db.load(now)).walkthroughSeen, isFalse);
        await capture(tester, 'walkthrough-welcome');
        await press(tester, 'Next');
        expect(find.text(walkthroughSteps[1].title), findsOneWidget);
        await capture(tester, 'walkthrough-checkbox');
        // A tap at the real, spotlighted checkbox is absorbed by the tour.
        final checkbox = find.byWidgetPredicate(
          (w) => w is Checkbox && w.semanticLabel == 'Subuh performed',
        );
        await tester.tapAt(tester.getCenter(checkbox));
        await tester.pumpAndSettle();
        expect((await db.load(now)).records, isEmpty);
        await press(tester, 'Back');
        expect(find.text(walkthroughSteps.first.title), findsOneWidget);
        for (var i = 1; i < walkthroughSteps.length; i++) {
          await press(tester, 'Next');
          expect(find.text(walkthroughSteps[i].title), findsOneWidget);
          final bar = tester.widget<AppBar>(find.byType(AppBar));
          expect(
            find.descendant(
              of: find.byWidget(bar),
              matching: find.text(
                [
                  'Today',
                  'History',
                  'Qada',
                  'Progress',
                ][walkthroughSteps[i].tab],
              ),
            ),
            findsOneWidget,
          );
          if (i == 4 || i == 6) {
            await capture(tester, 'walkthrough-step-${i + 1}');
          }
          expect(tester.takeException(), isNull);
        }
        await press(tester, 'Get started');
        expect(find.byType(AppWalkthrough), findsNothing);
        var saved = await db.load(now);
        expect(saved.walkthroughSeen, isTrue);
        expect(saved.records, isEmpty);
        expect(saved.replacements, isEmpty);
        expect(saved.outstanding, 0);
        await tester.pumpWidget(const SizedBox());
        await db.close();
        db = JournalDatabase(NativeDatabase(file));
        await tester.pumpWidget(app(db));
        await tester.pumpAndSettle();
        expect(find.byType(AppWalkthrough), findsNothing);
        saved = await db.load(now);
        expect(saved.walkthroughSeen, isTrue);
        expect(find.text('0 of 5 prayers recorded today'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await db.close();
        directory.deleteSync(recursive: true);
      }
    },
  );

  testWidgets(
    'skip and Android back persist dismissal; Settings replays from the beginning',
    (tester) async {
      phone(tester);
      final db = JournalDatabase(NativeDatabase.memory());
      await tester.pumpWidget(app(db));
      await tester.pumpAndSettle();
      await press(tester, 'Skip tour');
      expect((await db.load(now)).walkthroughSeen, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app(db));
      await tester.pumpAndSettle();
      expect(find.byType(AppWalkthrough), findsNothing);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('App walkthrough'));
      await tester.pumpAndSettle();
      expect(find.text(walkthroughSteps.first.title), findsOneWidget);
      await press(tester, 'Next');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AppWalkthrough), findsNothing);
      expect((await db.load(now)).walkthroughSeen, isTrue);
      expect((await db.load(now)).records, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await db.close();
    },
  );

  testWidgets('an interrupted unfinished tour appears again on next launch', (
    tester,
  ) async {
    phone(tester);
    final db = JournalDatabase(NativeDatabase.memory());
    await tester.pumpWidget(app(db));
    await tester.pumpAndSettle();
    await press(tester, 'Next');
    await tester.pumpWidget(const SizedBox());
    expect((await db.load(now)).walkthroughSeen, isFalse);
    await tester.pumpWidget(app(db));
    await tester.pumpAndSettle();
    expect(find.text(walkthroughSteps.first.title), findsOneWidget);
    await press(tester, 'Skip tour');
    await tester.pumpWidget(const SizedBox());
    await db.close();
  });

  testWidgets('failed preference write keeps the tour open and supports retry', (
    tester,
  ) async {
    phone(tester);
    final db = JournalDatabase(NativeDatabase.memory());
    await tester.pumpWidget(app(db));
    await tester.pumpAndSettle();
    await db.customStatement(
      "CREATE TRIGGER reject_tour BEFORE UPDATE ON journal BEGIN SELECT RAISE(ABORT, 'write failure'); END",
    );
    await press(tester, 'Skip tour');
    expect(
      find.text('Could not save your tour preference. Please try again.'),
      findsOneWidget,
    );
    expect((await db.load(now)).walkthroughSeen, isFalse);
    await db.customStatement('DROP TRIGGER reject_tour');
    await press(tester, 'Skip tour');
    expect(find.byType(AppWalkthrough), findsNothing);
    expect((await db.load(now)).walkthroughSeen, isTrue);
    await tester.pumpWidget(const SizedBox());
    await db.close();
  });

  test(
    'legacy journals skip automatic onboarding; backups validate and retain the preference',
    () {
      final old = Journal(startDate: dayOnly(now)).toJson()
        ..remove('walkthroughSeen');
      expect(Journal.decode(jsonEncode(old), now).walkthroughSeen, isTrue);
      final fresh = Journal(startDate: dayOnly(now), walkthroughSeen: false);
      expect(Journal.decode(fresh.export(), now).walkthroughSeen, isFalse);
      expect(
        Journal.decode(
          fresh.copy(walkthroughSeen: true).export(),
          now,
        ).walkthroughSeen,
        isTrue,
      );
      old['walkthroughSeen'] = 'false';
      expect(() => Journal.decode(jsonEncode(old), now), throwsFormatException);
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'all tour steps fit narrow large-text ${dark ? 'dark' : 'light'} mode and handle resize',
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
        await db.save(
          Journal(
            startDate: dayOnly(now),
            walkthroughSeen: false,
            theme: dark ? AppTheme.dark : AppTheme.light,
          ),
        );
        await tester.pumpWidget(app(db));
        await tester.pumpAndSettle();
        for (var i = 0; i < walkthroughSteps.length; i++) {
          expect(tester.takeException(), isNull);
          expect(find.text(walkthroughSteps[i].title), findsOneWidget);
          if (i == 1) {
            await capture(
              tester,
              'walkthrough-narrow-${dark ? 'dark' : 'light'}',
            );
            tester.view.physicalSize = const Size(720, 320);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            tester.view.physicalSize = const Size(320, 720);
            await tester.pumpAndSettle();
          }
          await press(
            tester,
            i == walkthroughSteps.length - 1 ? 'Get started' : 'Next',
          );
        }
        expect(find.byType(AppWalkthrough), findsNothing);
        await tester.pumpWidget(const SizedBox());
        await db.close();
      },
    );
  }
}
