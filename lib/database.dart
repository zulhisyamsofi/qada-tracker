import 'dart:io';
import 'dart:convert';
import 'prayer_times_models.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'model.dart';

// One versioned journal document is committed atomically. The domain model
// validates the entire document before any write, including backup restores.
class JournalDatabase extends GeneratedDatabase {
  JournalDatabase(super.executor);
  static Future<JournalDatabase> open() async {
    final directory = await getApplicationSupportDirectory();
    return JournalDatabase(
      NativeDatabase.createInBackground(
        File(path.join(directory.path, 'journal.sqlite')),
      ),
    );
  }

  @override
  int get schemaVersion => 2;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (_) => customStatement('PRAGMA busy_timeout = 3000'),
    onCreate: (_) async {
      await customStatement(
        'CREATE TABLE journal (id INTEGER PRIMARY KEY CHECK (id = 1), document TEXT NOT NULL)',
      );
      await _createCalendar();
    },
    onUpgrade: (_, from, to) async {
      if (from < 2) await _createCalendar();
    },
  );
  Future<void> _createCalendar() => customStatement(
    'CREATE TABLE prayer_calendar (id INTEGER PRIMARY KEY CHECK (id = 1), document TEXT NOT NULL)',
  );

  Future<PrayerCalendar?> loadCalendar() async {
    final row = await customSelect(
      'SELECT document FROM prayer_calendar WHERE id = 1',
    ).getSingleOrNull();
    if (row == null) return null;
    return _decodeCalendar(row.read<String>('document'));
  }

  PrayerCalendar? _decodeCalendar(String? document) {
    if (document == null) return null;
    try {
      return PrayerCalendar.fromJson(
        jsonDecode(document) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> saveCalendar(PrayerCalendar calendar, DateTime now) =>
      transaction(() async {
        final current = await load(now);
        if (current.prayerTimes.place.key != calendar.sourceKey) return false;
        await customStatement(
          'INSERT OR REPLACE INTO prayer_calendar(id, document) VALUES (1, ?)',
          [jsonEncode(calendar.toJson())],
        );
        return true;
      });

  Future<Journal> load(DateTime now) async {
    final row = await customSelect(
      'SELECT document FROM journal WHERE id = 1',
    ).getSingleOrNull();
    if (row != null) return Journal.decode(row.read<String>('document'), now);
    final initial = Journal(startDate: dayOnly(now));
    // Another connection (the home widget) may initialize/read concurrently.
    await customStatement(
      'INSERT OR IGNORE INTO journal(id, document) VALUES(1, ?)',
      [initial.export()],
    );
    return load(now);
  }

  /// Rebase each mutation on disk and compare-and-swap the complete document.
  /// Android widgets use a separate SQLite connection, so a cached UI snapshot
  /// must never overwrite a more recent tap. No read transaction is held while
  /// waiting for the native writer; a conflict retries the domain operation.
  Future<Journal> change(
    DateTime now,
    Journal Function(Journal) update, {
    void Function(Journal before, Journal after, PrayerCalendar? calendar)?
    validate,
  }) async {
    await load(now);
    for (var attempt = 0; attempt < 20; attempt++) {
      final row = await customSelect(
        'SELECT document, (SELECT document FROM prayer_calendar WHERE id = 1) AS calendar_document FROM journal WHERE id = 1',
      ).getSingle();
      final previous = row.read<String>('document');
      final calendarDocument = row.readNullable<String>('calendar_document');
      final current = Journal.decode(previous, now);
      final next = update(current).checked();
      validate?.call(current, next, _decodeCalendar(calendarDocument));
      final changed = await customUpdate(
        'UPDATE journal SET document = ? WHERE id = 1 AND document = ? AND (SELECT document FROM prayer_calendar WHERE id = 1) IS ?',
        variables: [
          Variable(next.export()),
          Variable(previous),
          Variable<String>(calendarDocument),
        ],
      );
      if (changed == 1) return next;
    }
    throw StateError('Your journal changed. Please try again.');
  }

  Future<void> save(Journal journal) => transaction(() async {
    await customStatement(
      'INSERT INTO journal(id, document) VALUES(1, ?) ON CONFLICT(id) DO UPDATE SET document = excluded.document',
      [journal.export()],
    );
  });
}
