import 'dart:convert';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:drift/drift.dart';
import 'database.dart';
import 'auth_repository.dart';

class GoogleDriveRepository {
  final AppDatabase _db;
  final AuthRepository _authRepo;

  GoogleDriveRepository(this._db, this._authRepo);

  Future<drive.DriveApi?> _getDriveApi() async {
    final httpClient = await _authRepo.authenticatedClient;
    if (httpClient == null) return null;

    return drive.DriveApi(httpClient);
  }

  Future<void> backupToDrive() async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) return;

    final sessions = await _db.allSessions;
    final jsonContent = jsonEncode(
      sessions
          .map(
            (s) => {
              'startTime': s.startTime.toIso8601String(),
              'durationSeconds': s.durationSeconds,
              'type': s.type,
              'completed': s.completed,
            },
          )
          .toList(),
    );

    final content = utf8.encode(jsonContent);
    final media = drive.Media(Stream.value(content), content.length);

    final fileList = await driveApi.files.list(
      spaces: 'appDataFolder',
      q: "name = 'podomoro_backup.json'",
    );

    if (fileList.files != null && fileList.files!.isNotEmpty) {
      final fileId = fileList.files!.first.id!;
      await driveApi.files.update(drive.File(), fileId, uploadMedia: media);
    } else {
      final driveFile = drive.File()
        ..name = 'podomoro_backup.json'
        ..parents = ['appDataFolder'];
      await driveApi.files.create(driveFile, uploadMedia: media);
    }
  }

  Future<void> restoreFromDrive() async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) return;

    final fileList = await driveApi.files.list(
      spaces: 'appDataFolder',
      q: "name = 'podomoro_backup.json'",
    );

    if (fileList.files == null || fileList.files!.isEmpty) return;

    final fileId = fileList.files!.first.id!;

    final media =
        await driveApi.files.get(
              fileId,
              downloadOptions: drive.DownloadOptions.fullMedia,
            )
            as drive.Media;

    final List<int> data = [];
    await for (final chunk in media.stream) {
      data.addAll(chunk);
    }

    final jsonString = utf8.decode(data);
    final List<dynamic> jsonList = jsonDecode(jsonString);

    for (var item in jsonList) {
      final startTime = DateTime.parse(item['startTime']);
      final exists = await _db.checkSessionExists(startTime);
      if (!exists) {
        await _db.addSession(
          SessionsCompanion.insert(
            startTime: startTime,
            durationSeconds: item['durationSeconds'] as int,
            type: Value(item['type'] as String),
            completed: Value(item['completed'] as bool),
          ),
        );
      }
    }
  }
}
