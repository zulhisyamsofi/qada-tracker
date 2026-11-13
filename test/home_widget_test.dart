import 'support/prayer_times.dart';
import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qada_tracker/controller.dart';
import 'package:qada_tracker/backup.dart';
import 'package:qada_tracker/database.dart';
import 'package:qada_tracker/home_widget.dart';
import 'package:qada_tracker/main.dart';
import 'package:qada_tracker/model.dart';
import 'backup_widget_test.dart' show FakeBackupFiles;

class TestHomeWidget extends HomeWidgetService {
  TestHomeWidget({bool supported = false})
    : super(
        supported: supported,
        channel: const MethodChannel('test/widget_ui'),
      );
  int syncs = 0;
  int pinRequests = 0;
  @override
  Future<void> sync() async => syncs++;
  @override
  Future<bool> requestPin() async {
    pinRequests++;
    return false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 11, 13, 12);

  test(
    'app mutation rebases on widget records and refreshes the launcher',
    () async {
      final db = JournalDatabase(NativeDatabase.memory());
      await seedPrayerCalendar(db, now);
      final widget = TestHomeWidget();
      final container = ProviderContainer(
        overrides: [
          fakePrayerTimes,
          databaseProvider.overrideWith((ref) async => db),
          clockProvider.overrideWithValue(() => now),
          homeWidgetServiceProvider.overrideWithValue(widget),
        ],
      );
      final subscription = container.listen(journalProvider, (_, _) {});
      try {
        final cached = await container.read(journalProvider.future);
        // A native widget write bypasses the app's cached Riverpod snapshot.
        await db.save(
          cached.setStatuses(now, {Prayer.subuh: PrayerStatus.performed}, now),
        );
        final controller = container.read(journalProvider.notifier);
        await controller.change((j) => j.copy(theme: AppTheme.dark));
        await controller.statuses(now, {Prayer.zohor: PrayerStatus.performed});
        final journal = await db.load(now);
        expect(journal.status(now, Prayer.subuh), PrayerStatus.performed);
        expect(journal.status(now, Prayer.zohor), PrayerStatus.performed);
        expect(journal.theme, AppTheme.dark);
        expect(
          widget.syncs,
          3,
        ); // Initial load and both committed app mutations.
        await db.customStatement(
          "CREATE TRIGGER reject_widget_test BEFORE UPDATE ON journal BEGIN SELECT RAISE(ABORT, 'write failure'); END",
        );
        await expectLater(
          controller.statuses(now, {Prayer.asar: PrayerStatus.performed}),
          throwsA(anything),
        );
        expect(
          container.read(journalProvider).requireValue.toJson(),
          journal.toJson(),
        );
        expect(widget.syncs, 3);
      } finally {
        subscription.close();
        container.dispose();
        await db.close();
      }
    },
  );

  test(
    'compare-and-swap retries a conflicting native write without losing it',
    () async {
      final db = JournalDatabase(NativeDatabase.memory());
      try {
        await db.load(now);
        // Emulate a native writer winning between the read and guarded UPDATE.
        // The first write commits its mark and ignores the now-stale app UPDATE.
        await db.customStatement('''
        CREATE TRIGGER concurrent_widget BEFORE UPDATE ON journal
        WHEN json_extract(OLD.document, '\$.records."2026-11-13".subuh') IS NULL
        BEGIN
          UPDATE journal SET document = json_set(OLD.document,
            '\$.records."2026-11-13".subuh', 'performed') WHERE id = 1;
          SELECT RAISE(IGNORE);
        END
      ''');
        var attempts = 0;
        final journal = await db.change(now, (j) {
          attempts++;
          return j.copy(theme: AppTheme.dark);
        });
        expect(attempts, 2);
        expect(journal.theme, AppTheme.dark);
        expect(journal.status(now, Prayer.subuh), PrayerStatus.performed);
        expect((await db.load(now)).toJson(), journal.toJson());
      } finally {
        await db.close();
      }
    },
  );

  testWidgets('widget event and app resume reload the latest native records', (
    tester,
  ) async {
    final db = JournalDatabase(NativeDatabase.memory());
    await seedPrayerCalendar(db, now);
    final widget = TestHomeWidget();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fakePrayerTimes,
          databaseProvider.overrideWith((ref) async => db),
          clockProvider.overrideWithValue(() => now),
          homeWidgetServiceProvider.overrideWithValue(widget),
        ],
        child: const QadaApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('0 of 5 prayers recorded today'), findsOneWidget);
    var journal = await db.load(now);
    await db.save(
      journal.setStatuses(now, {Prayer.subuh: PrayerStatus.performed}, now),
    );
    await widget.onJournalChanged!();
    await tester.pumpAndSettle();
    expect(find.text('1 of 5 prayers recorded today'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    journal = await db.load(now);
    await db.save(
      journal.setStatuses(now, {Prayer.zohor: PrayerStatus.performed}, now),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('2 of 5 prayers recorded today'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byWidgetPredicate(
        (w) => w is Checkbox && w.semanticLabel == 'Asar performed',
      ),
      150,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is Checkbox && w.semanticLabel == 'Asar performed',
      ),
    );
    await tester.pumpAndSettle();
    expect(
      (await db.load(now)).status(now, Prayer.asar),
      PrayerStatus.performed,
    );
    await tester.drag(find.byType(ListView), const Offset(0, 500));
    await tester.pumpAndSettle();
    expect(find.text('3 of 5 prayers recorded today'), findsOneWidget);
    journal = await db.load(now);
    await db.save(
      journal.setStatuses(now, {Prayer.subuh: PrayerStatus.unrecorded}, now),
    );
    await widget.onJournalChanged!();
    await tester.pumpAndSettle();
    expect(find.text('2 of 5 prayers recorded today'), findsOneWidget);
    expect(
      (await db.load(now)).status(now, Prayer.asar),
      PrayerStatus.performed,
    );
    await tester.pumpWidget(const SizedBox());
    expect(widget.onJournalChanged, isNull);
    await db.close();
  });

  test(
    'widget bridge handles unavailable launchers and refresh failures',
    () async {
      const channel = MethodChannel('test/home_widget');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        if (call.method == 'requestPin') return true;
        throw PlatformException(code: 'launcher');
      });
      try {
        final service = HomeWidgetService(channel: channel, supported: true);
        var reloads = 0;
        service.onJournalChanged = () async {
          reloads++;
        };
        final reply = Completer<void>();
        ServicesBinding.instance.channelBuffers.push(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('journalChanged'),
          ),
          (_) => reply.complete(),
        );
        await reply.future;
        expect(reloads, 1);
        await service.sync(); // Saved journal must survive launcher errors.
        expect(await service.requestPin(), isTrue);
        expect(calls, ['sync', 'requestPin']);
        messenger.setMockMethodCallHandler(
          channel,
          (_) async => throw MissingPluginException(),
        );
        expect(await service.requestPin(), isFalse);
        await service.sync();
      } finally {
        messenger.setMockMethodCallHandler(channel, null);
      }
    },
  );

  testWidgets(
    'Settings provides widget instructions when pinning is unavailable',
    (tester) async {
      final db = JournalDatabase(NativeDatabase.memory());
      final widget = TestHomeWidget(supported: true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fakePrayerTimes,
            databaseProvider.overrideWith((ref) async => db),
            clockProvider.overrideWithValue(() => now),
            homeWidgetServiceProvider.overrideWithValue(widget),
          ],
          child: const QadaApp(),
        ),
      );
      await tester.pumpAndSettle();
      final before = (await db.load(now)).export();
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Home-screen widget'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home-screen widget'));
      await tester.pumpAndSettle();
      expect(widget.pinRequests, 1);
      expect(find.text('Add your prayer widget'), findsOneWidget);
      expect(
        find.textContaining('Touch and hold an empty space'),
        findsOneWidget,
      );
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect((await db.load(now)).export(), before);
      await tester.pumpWidget(const SizedBox());
      await db.close();
    },
  );

  testWidgets('backup includes widget marks before its UI event arrives', (
    tester,
  ) async {
    final db = JournalDatabase(NativeDatabase.memory());
    final files = FakeBackupFiles();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fakePrayerTimes,
          databaseProvider.overrideWith((ref) async => db),
          clockProvider.overrideWithValue(() => now),
          backupFilesProvider.overrideWithValue(files),
        ],
        child: const QadaApp(),
      ),
    );
    await tester.pumpAndSettle();
    final original = await db.load(now);
    await db.save(
      original.setStatuses(now, {Prayer.maghrib: PrayerStatus.performed}, now),
    );
    // Leave Riverpod unchanged to emulate a delayed native broadcast.
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Export backup'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export backup'));
    await tester.pumpAndSettle();
    expect(
      Journal.decode(files.exported!, now).status(now, Prayer.maghrib),
      PrayerStatus.performed,
    );
    await tester.pumpWidget(const SizedBox());
    await db.close();
  });
}
