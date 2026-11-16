import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qada_tracker/database.dart';
import 'package:qada_tracker/model.dart';
import 'package:qada_tracker/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qada_tracker/controller.dart';
import 'support/prayer_times.dart';
import 'prayer_recording_test.dart' show sampleCalendar;
import 'package:qada_tracker/prayer_recording_policy.dart';
import 'theme_ui_test.dart' show fonts, capture, captureKey;

final now = DateTime(2026, 11, 16, 23);
final day = DateTime(2026, 11, 15);
Journal missed() => Journal(
  startDate: day,
).setStatuses(day, {Prayer.subuh: PrayerStatus.missed}, now);
Widget app(JournalDatabase db) => ProviderScope(
  overrides: [
    databaseProvider.overrideWith((ref) async => db),
    clockProvider.overrideWithValue(() => now),
    fakePrayerTimes,
  ],
  child: RepaintBoundary(key: captureKey, child: const QadaApp()),
);
void main() {
  setUpAll(fonts);
  test('current-day qada links retain the prayer start-time boundary', () {
    final clock = DateTime.utc(2026, 11, 14, 15);
    final journal = Journal(
      startDate: DateTime(2026, 11, 13),
    ).setStatuses(clock, {Prayer.asar: PrayerStatus.missed}, clock);
    final completed = journal.completeMiss(clock, Prayer.asar, clock, 'early');
    expect(
      () => PrayerRecordingPolicy.validate(
        journal,
        completed,
        sampleCalendar(),
        clock,
      ),
      throwsStateError,
    );
    PrayerRecordingPolicy.validate(
      journal,
      completed,
      sampleCalendar(),
      DateTime.utc(2026, 11, 14, 16),
    );
  });
  test(
    'dated completion is exactly once, keeps miss, and supports undo and explicit correction',
    () {
      final original = missed();
      final j = original.completeMiss(day, Prayer.subuh, now, 'linked');
      expect(j.balance(Prayer.subuh), 0);
      expect(j.status(day, Prayer.subuh), PrayerStatus.missed);
      expect(j.replacementFor(day, Prayer.subuh)!.id, 'linked');
      expect(
        () => j.completeMiss(day, Prayer.subuh, now, 'duplicate'),
        throwsStateError,
      );
      expect(
        () => j.setStatuses(day, {Prayer.subuh: PrayerStatus.performed}, now),
        throwsFormatException,
      );
      expect(j.undo('linked').balance(Prayer.subuh), 1);
      final corrected = j.correctReplacedMiss(day, Prayer.subuh, now);
      expect(corrected.balance(Prayer.subuh), 0);
      expect(corrected.replacements, isEmpty);
      expect(corrected.status(day, Prayer.subuh), PrayerStatus.performed);
    },
  );
  test(
    'legacy replacement linking and splitting preserve balance, timestamp and total quantity',
    () {
      var j = missed()
          .setStatuses(now, {Prayer.subuh: PrayerStatus.missed}, now)
          .complete(Prayer.subuh, 2, now, 'old');
      j = j.linkReplacement(day, Prayer.subuh, 'old', 'split');
      expect(j.balance(Prayer.subuh), 0);
      expect(j.replacements.length, 2);
      expect(j.replacements.fold(0, (int n, e) => n + e.quantity), 2);
      expect(j.replacementFor(day, Prayer.subuh)!.completedAt, now);
      j = j.linkReplacement(now, Prayer.subuh, 'old', 'other');
      expect(j.balance(Prayer.subuh), 0);
      expect(j.replacements.every((e) => e.missedDate != null), isTrue);
      expect(
        () => j.linkReplacement(day, Prayer.subuh, 'old', 'bad'),
        throwsStateError,
      );
    },
  );
  test(
    'version 3 backup validates links and reads version 1/2 without inventing dates',
    () {
      final j = missed().completeMiss(day, Prayer.subuh, now, 'qada');
      expect(Journal.decode(j.export(), now).toJson(), j.toJson());
      void invalid(void Function(Map<String, dynamic>) update) {
        final root = jsonDecode(j.export()) as Map<String, dynamic>;
        update(root);
        expect(
          () => Journal.decode(jsonEncode(root), now),
          throwsFormatException,
        );
      }

      invalid((r) => r['version'] = 2);
      invalid(
        (r) => (r['replacements'] as List).first['missedDate'] = '2026-11-17',
      );
      invalid((r) => (r['replacements'] as List).first['quantity'] = 2);
      invalid(
        (r) => (r['replacements'] as List).add({
          ...((r['replacements'] as List).first as Map),
          'id': 'second',
        }),
      );
      for (final version in [1, 2]) {
        final root = missed().complete(Prayer.subuh, 1, now, 'old').toJson()
          ..['version'] = version;
        final legacy = Journal.decode(jsonEncode(root), now);
        expect(legacy.balance(Prayer.subuh), 0);
        expect(legacy.replacements.single.missedDate, isNull);
      }
    },
  );
  test(
    'linked journal survives file restart and failed corrections roll back',
    () async {
      final dir = Directory.systemTemp.createTempSync('qada-linked-');
      final file = File('${dir.path}/journal.sqlite');
      var db = JournalDatabase(NativeDatabase(file));
      try {
        final j = missed().completeMiss(day, Prayer.subuh, now, 'qada');
        await db.save(j);
        await db.close();
        db = JournalDatabase(NativeDatabase(file));
        expect((await db.load(now)).toJson(), j.toJson());
        await expectLater(
          db.change(
            now,
            (j) => j.setStatuses(day, {
              Prayer.subuh: PrayerStatus.unrecorded,
            }, now),
          ),
          throwsFormatException,
        );
        expect((await db.load(now)).toJson(), j.toJson());
      } finally {
        await db.close();
        dir.deleteSync(recursive: true);
      }
    },
  );
  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets(
      'Records completes the selected miss and corrects it without a negative balance ${theme.name}',
      (t) async {
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final db = JournalDatabase(NativeDatabase.memory());
        await db.save(missed().copy(theme: theme));
        Future<void> tap(Finder f) async {
          await t.ensureVisible(f);
          await t.pumpAndSettle();
          await t.tap(f);
          await t.pumpAndSettle();
        }

        try {
          await t.pumpWidget(app(db));
          await t.pumpAndSettle();
          await tap(find.text('Records').last);
          expect(find.text('Qada'), findsNothing);
          expect(find.text('History'), findsNothing);
          final action = find.byKey(
            const ValueKey('complete-qada-2026-11-15-subuh'),
          );
          await t.scrollUntilVisible(
            action,
            180,
            scrollable: find.byType(Scrollable).first,
          );
          await tap(action);
          expect((await db.load(now)).outstanding, 0);
          expect(find.text('Qada completed'), findsWidgets);
          await capture(t, 'records-completed-${theme.name}');
          await tap(find.byTooltip('Update Subuh'));
          await tap(find.text('Mark performed'));
          await tap(find.widgetWithText(FilledButton, 'Confirm'));
          final j = await db.load(now);
          expect(j.outstanding, 0);
          expect(j.status(day, Prayer.subuh), PrayerStatus.performed);
          expect(j.replacements, isEmpty);
          expect(t.takeException(), isNull);
        } finally {
          await t.pumpWidget(const SizedBox());
          await db.close();
        }
      },
    );
  }
  testWidgets(
    'legacy completion links from a missed prayer without a second deduction',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final db = JournalDatabase(NativeDatabase.memory());
      await db.save(missed().complete(Prayer.subuh, 1, now, 'old'));
      try {
        await t.pumpWidget(app(db));
        await t.pumpAndSettle();
        await t.tap(find.text('Records').last);
        await t.pumpAndSettle();
        final action = find.byKey(
          const ValueKey('complete-qada-2026-11-15-subuh'),
        );
        await t.scrollUntilVisible(
          action,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await t.ensureVisible(action);
        await t.pumpAndSettle();
        await t.tap(action);
        await t.pumpAndSettle();
        expect(find.text('Record new completion'), findsNothing);
        await t.tap(find.textContaining('Use existing replacement:'));
        await t.pumpAndSettle();
        final j = await db.load(now);
        expect(j.outstanding, 0);
        expect(j.replacements.length, 1);
        expect(j.replacementFor(day, Prayer.subuh)!.id, 'old');
        expect(t.takeException(), isNull);
      } finally {
        await t.pumpWidget(const SizedBox());
        await db.close();
      }
    },
  );
}
