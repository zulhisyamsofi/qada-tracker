import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Platform boundary, injectable so cancellation and restore prompts can be tested.
abstract interface class BackupFiles {
  Future<String?> read();
  Future<bool> write(String filename, String contents);
}

class DocumentBackupFiles implements BackupFiles {
  @override
  Future<String?> read() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Choose prayer journal backup',
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null) return null;
    final file = result.files.single;
    if (file.size > 10 * 1024 * 1024 || file.bytes == null) {
      throw const FormatException(
        'Choose a readable backup smaller than 10 MB.',
      );
    }
    return utf8.decode(file.bytes!);
  }

  @override
  Future<bool> write(String filename, String contents) async =>
      await FilePicker.platform.saveFile(
        dialogTitle: 'Save prayer journal backup',
        fileName: filename,
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: Uint8List.fromList(utf8.encode(contents)),
      ) !=
      null;
}

final backupFilesProvider = Provider<BackupFiles>(
  (ref) => DocumentBackupFiles(),
);
