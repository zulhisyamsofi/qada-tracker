import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:sqlite3/wasm.dart';

// A distinct browser-only database; never connected to Android/private data.
Future<QueryExecutor> openExecutor() async {
  final sqlite = await WasmSqlite3.loadFromUrl(
    Uri.base.resolve('sqlite3.wasm'),
  );
  final files = await IndexedDbFileSystem.open(dbName: 'qada-portfolio-demo');
  sqlite.registerVirtualFileSystem(files, makeDefault: true);
  return WasmDatabase(sqlite3: sqlite, path: '/demo.sqlite', fileSystem: files);
}
