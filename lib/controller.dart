import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database.dart';
import 'model.dart';
import 'reminders.dart';
import 'home_widget.dart';
import 'prayer_recording_policy.dart';

final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
final databaseProvider = FutureProvider<JournalDatabase>((ref) async {
  final database = await JournalDatabase.open();
  ref.onDispose(() {
    unawaited(database.close());
  });
  return database;
});
final journalProvider = AsyncNotifierProvider<JournalController, Journal>(
  JournalController.new,
);

class JournalController extends AsyncNotifier<Journal> {
  Future<void> _queue = Future.value();
  @override
  Future<Journal> build() async {
    final journal = await (await ref.watch(
      databaseProvider.future,
    )).load(ref.read(clockProvider)());
    await ref.read(reminderServiceProvider).sync(journal.reminderEnabled);
    await ref.read(reminderServiceProvider).syncPrayerTimes();
    await ref.read(homeWidgetServiceProvider).sync();
    return journal;
  }

  Future<void> refreshReminders({bool repairPrayerAlarms = false}) async {
    final journal = state.asData?.value;
    if (journal == null) return;
    await ref.read(reminderServiceProvider).sync(journal.reminderEnabled);
    if (repairPrayerAlarms && ref.mounted) {
      await ref.read(reminderServiceProvider).syncPrayerTimes();
    }
    if (ref.mounted) ref.invalidate(reminderAccessProvider);
  }

  // Serialize rapid taps and restores; failed disk writes never update the UI.
  Future<void> change(Journal Function(Journal) update) => _change(update);

  Future<void> _change(
    Journal Function(Journal) update, {
    bool restoring = false,
  }) {
    final operation = _queue.then((_) async {
      final db = await ref.read(databaseProvider.future);
      final next = await db.change(
        ref.read(clockProvider)(),
        update,
        validate: restoring
            ? null
            : (current, next, calendar) => PrayerRecordingPolicy.validate(
                current,
                next,
                calendar,
                ref.read(clockProvider)(),
              ),
      );
      if (!ref.mounted) return;
      state = AsyncData(next);
      await refreshReminders();
      await ref.read(homeWidgetServiceProvider).sync();
    });
    _queue = operation.catchError((Object _) {});
    return operation;
  }

  // Native widget changes do not pass through Riverpod. Queue reloads with
  // app writes so a slow resume read cannot publish an older UI snapshot.
  Future<void> reload() {
    final operation = _queue.then((_) async {
      if (!ref.mounted) return;
      if (!state.hasValue) await future;
      if (!ref.mounted) return;
      final next = await (await ref.read(
        databaseProvider.future,
      )).load(ref.read(clockProvider)());
      if (!ref.mounted) return;
      state = AsyncData(next);
      await refreshReminders(repairPrayerAlarms: true);
      await ref.read(homeWidgetServiceProvider).sync();
    });
    _queue = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> statuses(DateTime day, Map<Prayer, PrayerStatus> changes) =>
      change((j) => j.setStatuses(day, changes, ref.read(clockProvider)()));
  Future<String> complete(Prayer p, int count) async {
    // An Undo action must identify this entry even after earlier entries are
    // deleted or the phone clock changes.
    final random = Random.secure();
    final id = List.generate(
      4,
      (_) => random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0'),
    ).join();
    await change((j) => j.complete(p, count, ref.read(clockProvider)(), id));
    return id;
  }

  // Restores preserve already confirmed records; they are not new check-ins.
  Future<void> restore(Journal validated) =>
      _change((_) => validated, restoring: true);
}
