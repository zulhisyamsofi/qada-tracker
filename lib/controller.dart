import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database.dart';
import 'model.dart';
import 'reminders.dart';

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
    return journal;
  }

  Future<void> refreshReminders() async {
    final journal = state.asData?.value;
    if (journal == null) return;
    await ref.read(reminderServiceProvider).sync(journal.reminderEnabled);
    if (ref.mounted) ref.invalidate(reminderAccessProvider);
  }

  // Serialize rapid taps and restores; failed disk writes never update the UI.
  Future<void> change(Journal Function(Journal) update) {
    final operation = _queue.then((_) async {
      final current = state.requireValue;
      final next = update(current).checked();
      await (await ref.read(databaseProvider.future)).save(next);
      state = AsyncData(next);
      await refreshReminders();
    });
    _queue = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> statuses(DateTime day, Map<Prayer, PrayerStatus> changes) =>
      change((j) => j.setStatuses(day, changes, ref.read(clockProvider)()));
  Future<void> complete(Prayer p, int count) => change((j) {
    final now = ref.read(clockProvider)();
    return j.complete(
      p,
      count,
      now,
      '${now.microsecondsSinceEpoch}-${j.replacements.length}',
    );
  });
  Future<void> restore(Journal validated) => change((_) => validated);
}
