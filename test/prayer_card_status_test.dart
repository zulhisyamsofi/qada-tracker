import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qada_tracker/controller.dart';
import 'package:qada_tracker/database.dart';
import 'package:qada_tracker/main.dart';
import 'package:qada_tracker/model.dart';
import 'package:qada_tracker/ui/glass.dart';
import 'support/prayer_times.dart';
import 'theme_ui_test.dart' show fonts, capture, captureKey;
import 'walkthrough_test.dart' show phone;

void main() {
  setUpAll(fonts);
  final now = DateTime(2026, 11, 14, 12);
  final yesterday = DateTime(2026, 11, 13);
  for (final mode in [AppTheme.light, AppTheme.dark]) {
    testWidgets(
      '${mode.name} cards distinguish performed, missed, and past unrecorded and follow corrections',
      (tester) async {
        phone(tester);
        final db = JournalDatabase(NativeDatabase.memory());
        final original = Journal(startDate: yesterday, theme: mode)
            .setStatuses(now, {
              Prayer.subuh: PrayerStatus.performed,
              Prayer.zohor: PrayerStatus.missed,
            }, now)
            .setStatuses(yesterday, {
              Prayer.subuh: PrayerStatus.performed,
              Prayer.zohor: PrayerStatus.missed,
            }, now);
        await db.save(original);
        Finder card(DateTime day, Prayer p) =>
            find.byKey(ValueKey('prayer-card-${dateKey(day)}-${p.name}'));
        GlassCard appearance(DateTime day, Prayer p) =>
            tester.widget<GlassCard>(card(day, p));
        try {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                databaseProvider.overrideWith((ref) async => db),
                clockProvider.overrideWithValue(() => now),
                fakePrayerTimes,
              ],
              child: RepaintBoundary(key: captureKey, child: const QadaApp()),
            ),
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(card(now, Prayer.subuh));
          await tester.pumpAndSettle();
          final done = appearance(now, Prayer.subuh);
          expect(done.borderColor, isNotNull);
          expect(done.borderColor!.g, greaterThan(done.borderColor!.r));
          final title = tester.widget<Text>(
            find
                .descendant(
                  of: card(now, Prayer.subuh),
                  matching: find.byType(Text),
                )
                .first,
          );
          expect(title.style!.color!.a, lessThan(1));
          expect(
            appearance(now, Prayer.zohor).borderColor!.r,
            greaterThan(appearance(now, Prayer.zohor).borderColor!.g),
          );
          expect(appearance(now, Prayer.asar).borderColor, isNull);
          await capture(tester, 'prayer-status-today-${mode.name}');
          final checkbox = find.descendant(
            of: card(now, Prayer.subuh),
            matching: find.byType(Checkbox),
          );
          await tester.tap(checkbox);
          await tester.pumpAndSettle();
          expect(appearance(now, Prayer.subuh).borderColor, isNull);
          expect(
            (await db.load(now)).status(now, Prayer.subuh),
            PrayerStatus.unrecorded,
          );
          await tester.tap(checkbox);
          await tester.pumpAndSettle();
          expect(appearance(now, Prayer.subuh).borderColor, done.borderColor);
          await tester.tap(find.text('Records').last);
          await tester.pumpAndSettle();
          await tester.tap(find.text('13').first);
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            card(yesterday, Prayer.asar),
            150,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.ensureVisible(card(yesterday, Prayer.subuh));
          await tester.pumpAndSettle();
          expect(
            appearance(yesterday, Prayer.subuh).borderColor,
            done.borderColor,
          );
          final red = appearance(yesterday, Prayer.zohor).borderColor;
          final amber = appearance(yesterday, Prayer.asar).borderColor;
          expect(amber, isNot(red));
          expect(
            find.descendant(
              of: card(yesterday, Prayer.asar),
              matching: find.text('Unrecorded · needs review'),
            ),
            findsOneWidget,
          );
          expect((await db.load(now)).outstanding, 2);
          await capture(tester, 'prayer-status-history-${mode.name}');
          await tester.ensureVisible(find.byTooltip('Update Asar'));
          await tester.tap(find.byTooltip('Update Asar'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Mark missed'));
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
          await tester.pumpAndSettle();
          expect(appearance(yesterday, Prayer.asar).borderColor, red);
          final missed = find.descendant(
            of: card(yesterday, Prayer.asar),
            matching: find.text('Missed · added to qada'),
          );
          expect(
            tester.widget<Text>(missed).style!.fontWeight,
            FontWeight.w700,
          );
          expect((await db.load(now)).outstanding, 3);
          await tester.tap(find.byTooltip('Update Asar'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Leave unrecorded'));
          await tester.pumpAndSettle();
          expect(appearance(yesterday, Prayer.asar).borderColor, amber);
          expect((await db.load(now)).outstanding, 2);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await db.close();
        }
      },
    );
  }
}
