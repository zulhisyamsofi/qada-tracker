import 'dart:io';
import 'dart:ui' as ui;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qada_tracker/controller.dart';
import 'package:qada_tracker/database.dart';
import 'package:qada_tracker/main.dart';
import 'package:qada_tracker/model.dart';
import 'package:qada_tracker/prayer_times_controller.dart';
import 'prayer_times_controller_test.dart' show FakeTimesApi;

final captureKey = GlobalKey();
final now = DateTime(2026, 11, 13, 12);
Future<void> fonts() async {
  final loader = FontLoader('Nunito');
  for (final weight in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
    loader.addFont(rootBundle.load('assets/fonts/Nunito-$weight.ttf'));
  }
  await loader.load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
}

Future<void> capture(WidgetTester tester, String name) async {
  if (Platform.environment['QADA_CAPTURE_UI'] != '1') return;
  await tester.runAsync(() async {
    final boundary =
        captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/visual-qa/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Widget app(JournalDatabase db, FakeTimesApi api) => ProviderScope(
  overrides: [
    databaseProvider.overrideWith((ref) async => db),
    clockProvider.overrideWithValue(() => now),
    prayerTimesApiProvider.overrideWithValue(api),
  ],
  child: RepaintBoundary(key: captureKey, child: const QadaApp()),
);
Journal seed(AppTheme theme) =>
    Journal(startDate: dayOnly(now), theme: theme).setStatuses(now, {
      Prayer.subuh: PrayerStatus.performed,
      Prayer.zohor: PrayerStatus.performed,
    }, now);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(fonts);
  testWidgets(
    'quick dark-mode toggle persists and Settings retains system mode',
    (tester) async {
      final db = JournalDatabase(NativeDatabase.memory());
      final api = FakeTimesApi();
      await db.save(seed(AppTheme.light));
      await tester.pumpWidget(app(db, api));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Switch to dark mode'));
      await tester.pumpAndSettle();
      expect((await db.load(now)).theme, AppTheme.dark);
      expect(
        Theme.of(tester.element(find.text('One prayer at a time.'))).brightness,
        Brightness.dark,
      );
      expect(
        (await db.load(now)).status(now, Prayer.subuh),
        PrayerStatus.performed,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app(db, api));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Switch to light mode'), findsOneWidget);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SwitchListTile, 'Dark mode'));
      await tester.pumpAndSettle();
      expect((await db.load(now)).theme, AppTheme.light);
      await tester.ensureVisible(
        find.byType(DropdownButtonFormField<AppTheme>),
      );
      await tester.tap(find.byType(DropdownButtonFormField<AppTheme>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Follow system').last);
      await tester.pumpAndSettle();
      expect((await db.load(now)).theme, AppTheme.system);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.text('Dark mode'))).brightness,
        Brightness.dark,
      );
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
      await tester.pumpWidget(const SizedBox());
      api.client.close();
      await db.close();
    },
  );
  for (final mode in [AppTheme.light, AppTheme.dark]) {
    testWidgets('glass screens render and interact in ${mode.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final oldShadows = debugDisableShadows;
      debugDisableShadows = false;
      final db = JournalDatabase(NativeDatabase.memory());
      final api = FakeTimesApi();
      await db.save(seed(mode));
      await tester.pumpWidget(app(db, api));
      await tester.pumpAndSettle();
      await capture(tester, 'today-${mode.name}');
      await tester.tap(find.byTooltip('Prayer times & location'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture(tester, 'prayer-settings-${mode.name}');
      Navigator.of(tester.element(find.text('Prayer times & location'))).pop();
      await tester.pumpAndSettle();
      for (final tab in ['History', 'Qada', 'Progress']) {
        await tester.tap(find.text(tab).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await capture(tester, '${tab.toLowerCase()}-${mode.name}');
        if (tab == 'History') {
          await tester.tap(find.text('12').first);
          await tester.pumpAndSettle();
          await capture(tester, 'history-backfill-${mode.name}');
        }
        if (tab == 'Qada') {
          await tester.tap(find.byKey(const ValueKey('qada-formula-info')));
          await tester.pumpAndSettle();
          await capture(tester, 'qada-tooltip-${mode.name}');
          Tooltip.dismissAllToolTips();
          await tester.pumpAndSettle();
        }
      }
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await capture(tester, 'settings-${mode.name}');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      debugDisableShadows = oldShadows;
      api.client.close();
      await db.close();
    });
  }
  testWidgets('narrow layout, large text and high contrast stay usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(
          highContrast: true,
          disableAnimations: true,
        );
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final db = JournalDatabase(NativeDatabase.memory());
    final api = FakeTimesApi();
    await db.save(seed(AppTheme.dark));
    await tester.pumpWidget(app(db, api));
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Switch to light mode'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await capture(tester, 'accessibility-320');
    for (final tab in ['Qada', 'Progress']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture(tester, '${tab.toLowerCase()}-accessibility-320');
    }
    await tester.pumpWidget(const SizedBox());
    api.client.close();
    await db.close();
  });
}
