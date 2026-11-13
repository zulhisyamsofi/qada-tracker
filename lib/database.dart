import 'dart:io';
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
  int get schemaVersion => 1;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      await customStatement(
        'CREATE TABLE journal (id INTEGER PRIMARY KEY CHECK (id = 1), document TEXT NOT NULL)',
      );
    },
  );
  Future<Journal> load(DateTime now) async {
    final row = await customSelect(
      'SELECT document FROM journal WHERE id = 1',
    ).getSingleOrNull();
    if (row != null) return Journal.decode(row.read<String>('document'), now);
    final initial = Journal(startDate: dayOnly(now));
    await save(initial);
    return initial;
  }

  Future<void> save(Journal journal) => transaction(() async {
    await customStatement(
      'INSERT INTO journal(id, document) VALUES(1, ?) ON CONFLICT(id) DO UPDATE SET document = excluded.document',
      [journal.export()],
    );
  });
}
