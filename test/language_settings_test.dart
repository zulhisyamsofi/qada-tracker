import 'dart:convert';
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

final now = DateTime(2026, 11, 16, 12);
Widget app(JournalDatabase db) => ProviderScope(
  overrides: [
    databaseProvider.overrideWith((ref) async => db),
    clockProvider.overrideWithValue(() => now),
    fakePrayerTimes,
  ],
  child: RepaintBoundary(key: captureKey, child: const QadaApp()),
);
Future<void> tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

void main() {
  setUpAll(fonts);
  test(
    'language defaults and validated backup round trips preserve prayer data',
    () {
      final j = Journal(startDate: now)
          .setStatuses(now, {Prayer.subuh: PrayerStatus.performed}, now)
          .copy(language: AppLanguage.ms);
      expect(Journal.decode(j.export(), now).toJson(), j.toJson());
      final legacy = j.toJson()..remove('language');
      expect(Journal.decode(jsonEncode(legacy), now).language, AppLanguage.en);
      legacy['language'] = 'invalid';
      expect(
        () => Journal.decode(jsonEncode(legacy), now),
        throwsFormatException,
      );
    },
  );
  for (final mode in [AppTheme.light, AppTheme.dark]) {
    testWidgets(
      'language switch translates navigation and dialogs and persists ${mode.name}',
      (t) async {
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final db = JournalDatabase(NativeDatabase.memory());
        await db.save(Journal(startDate: DateTime(2026, 11, 15), theme: mode));
        try {
          await t.pumpWidget(app(db));
          await t.pumpAndSettle();
          final nav = find.byType(GlassNavigationBar);
          final outer = t.widget<GlassCard>(
            find.ancestor(of: nav, matching: find.byType(GlassCard)).first,
          );
          final item = t.widget<AnimatedContainer>(
            find
                .descendant(of: nav, matching: find.byType(AnimatedContainer))
                .first,
          );
          expect(
            (item.decoration! as BoxDecoration).borderRadius,
            BorderRadius.circular(outer.radius - 5),
          );
          final labels = find.descendant(of: nav, matching: find.byType(Text));
          expect(
            labels
                .evaluate()
                .map((e) => (e.widget as Text).data)
                .where((s) => ['Today', 'Records', 'Progress'].contains(s))
                .toList(),
            ['Today', 'Records', 'Progress'],
          );
          expect(find.textContaining('Starts at'), findsNothing);
          await tap(t, find.byTooltip('Settings'));
          await tap(t, find.byKey(const ValueKey('app-language')));
          await t.tap(find.text('Bahasa Melayu').last);
          await t.pumpAndSettle();
          expect((await db.load(now)).language, AppLanguage.ms);
          await t.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 100));
          });
          await t.pumpAndSettle();
          expect(find.text('Jurnal mengikut cara anda'), findsOneWidget);
          await capture(t, 'language-settings-${mode.name}');
          Navigator.of(t.element(find.text('Jurnal mengikut cara anda'))).pop();
          await t.pumpAndSettle();
          for (final tab in ['Rekod', 'Kemajuan', 'Hari Ini']) {
            await tap(t, find.text(tab).last);
            expect(t.takeException(), isNull);
            await capture(
              t,
              'language-${tab.replaceAll(' ', '-')}-${mode.name}',
            );
          }
          await tap(t, find.byTooltip('Tetapan'));
          await tap(t, find.text('Tempoh haid & jeda rekod'));
          expect(find.text('Tambah tarikh haid'), findsOneWidget);
          await capture(t, 'language-period-${mode.name}');
          Navigator.of(t.element(find.text('Tambah tarikh haid'))).pop();
          await t.pumpAndSettle();
          await tap(t, find.byTooltip('Tetapan'));
          await tap(t, find.text('Panduan aplikasi'));
          for (var step = 0; step < 7; step++) {
            expect(t.takeException(), isNull);
            await tap(
              t,
              find.widgetWithText(
                FilledButton,
                step == 6 ? 'Mula' : 'Seterusnya',
              ),
            );
          }
          await t.pumpWidget(const SizedBox());
          await t.pumpWidget(app(db));
          await t.pumpAndSettle();
          expect(find.text('Hari Ini').last, findsOneWidget);
          expect((await db.load(now)).language, AppLanguage.ms);
          expect((await db.load(now)).records, isEmpty);
        } finally {
          await t.pumpWidget(const SizedBox());
          await db.close();
        }
      },
    );
  }
}
