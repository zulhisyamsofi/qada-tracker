import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qada_tracker/controller.dart';
import 'package:qada_tracker/database.dart';
import 'package:qada_tracker/main.dart';
import 'package:qada_tracker/model.dart';
import 'package:qada_tracker/prayer_times_controller.dart';
import 'package:qada_tracker/prayer_times_models.dart';
import 'prayer_times_controller_test.dart' show FakeTimesApi;
import 'support/prayer_actions.dart';
import 'theme_ui_test.dart' show fonts;

class SlowCalendarDatabase extends JournalDatabase {
  SlowCalendarDatabase() : super(NativeDatabase.memory());
  Completer<void>? readsHeld;
  int calendarReads = 0;
  @override
  Future<PrayerCalendar?> loadCalendar() async {
    calendarReads++;
    if (readsHeld != null) await readsHeld!.future;
    return super.loadCalendar();
  }
}

void main() {
  setUpAll(fonts);
  final now = DateTime.utc(2026, 11, 13, 14);
  for (final size in [const Size(390, 844), const Size(320, 640)]) {
    testWidgets(
      'Done preserves Today positions and scroll through slow calendar reads ${size.width.toInt()}',
      (t) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final db = SlowCalendarDatabase();
        final api = FakeTimesApi();
        await db.save(Journal(startDate: dayOnly(now)));
        try {
          await t.pumpWidget(
            ProviderScope(
              overrides: [
                databaseProvider.overrideWith((ref) async => db),
                clockProvider.overrideWithValue(() => now),
                prayerTimesApiProvider.overrideWithValue(api),
              ],
              child: const QadaApp(),
            ),
          );
          await t.pumpAndSettle();
          final initialReads = db.calendarReads;
          final initialRequests = api.requests;
          db.readsHeld = Completer<void>();
          final scope = ProviderScope.containerOf(
            t.element(find.byType(QadaApp)),
          );
          final calendar = scope
              .read(prayerTimesProvider)
              .requireValue
              .calendar;
          final viewport = find.byKey(const ValueKey('today-prayers'));
          final scroll = t.state<ScrollableState>(
            find.descendant(of: viewport, matching: find.byType(Scrollable)),
          );
          // Also cover a user who has scrolled down to a later prayer.
          for (final prayer in Prayer.values) {
            final button = doneButton(prayer, now);
            await t.ensureVisible(button);
            await t.pumpAndSettle();
            final offset = scroll.position.pixels;
            final rectangles = [
              for (final p in Prayer.values)
                t.getRect(
                  find.byKey(ValueKey('prayer-card-${dateKey(now)}-${p.name}')),
                ),
            ];
            await t.tap(button);
            for (var frame = 0; frame < 20; frame++) {
              await t.pump(const Duration(milliseconds: 16));
              expect(find.text('Loading prayer times…'), findsNothing);
              expect(scope.read(prayerTimesProvider).isLoading, isFalse);
              expect(
                scope.read(prayerTimesProvider).requireValue.calendar,
                same(calendar),
              );
              expect(
                scroll.position.pixels,
                closeTo(offset, .1),
                reason:
                    'after ${prayer.name}, card heights before: ${rectangles.map((r) => r.height).toList()}, after: ${[for (final p in Prayer.values) t.getRect(find.byKey(ValueKey('prayer-card-${dateKey(now)}-${p.name}'))).height]}',
              );
              for (var i = 0; i < Prayer.values.length; i++) {
                final rect = t.getRect(
                  find.byKey(
                    ValueKey(
                      'prayer-card-${dateKey(now)}-${Prayer.values[i].name}',
                    ),
                  ),
                );
                expect(rect.top, closeTo(rectangles[i].top, .1));
                expect(rect.height, closeTo(rectangles[i].height, .1));
              }
            }
            expect(
              (await db.load(now)).status(now, prayer),
              PrayerStatus.performed,
            );
            expect(db.calendarReads, initialReads);
            expect(api.requests, initialRequests);
          }
          expect(t.takeException(), isNull);
        } finally {
          db.readsHeld?.complete();
          await t.pumpAndSettle();
          await t.pumpWidget(const SizedBox());
          api.client.close();
          await db.close();
        }
      },
    );
  }
}
