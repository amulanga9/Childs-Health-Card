import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:permission_handler/permission_handler.dart';
import '../data/database/database.dart';

/// Сервис для резервного копирования и восстановления данных
class BackupService {
  final AppDatabase database;

  BackupService({required this.database});

  /// Создать резервную копию
  /// Возвращает путь к созданному ZIP файлу
  Future<String?> createBackup() async {
    try {
      // Проверяем разрешения
      if (!await _checkPermissions()) {
        throw Exception('Storage permission denied');
      }

      // Получаем директории
      final appDir = await getApplicationDocumentsDirectory();
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Создаем временную директорию для бэкапа
      final backupTempDir = Directory('${tempDir.path}/backup_$timestamp');
      if (!await backupTempDir.exists()) {
        await backupTempDir.create(recursive: true);
      }

      // 1. Копируем файл базы данных
      final dbFile = File(path.join(appDir.path, 'app_database.sqlite'));
      if (await dbFile.exists()) {
        await dbFile.copy(path.join(backupTempDir.path, 'database.db'));
        debugPrint('Database copied');
      }

      // 2. Копируем WAL файл если есть
      final walFile = File(path.join(appDir.path, 'app_database.sqlite-wal'));
      if (await walFile.exists()) {
        await walFile.copy(path.join(backupTempDir.path, 'database.db-wal'));
      }

      // 3. Копируем SHM файл если есть
      final shmFile = File(path.join(appDir.path, 'app_database.sqlite-shm'));
      if (await shmFile.exists()) {
        await shmFile.copy(path.join(backupTempDir.path, 'database.db-shm'));
      }

      // 4. Собираем все файлы вложений
      final attachmentsDir = Directory(path.join(backupTempDir.path, 'attachments'));
      await attachmentsDir.create(recursive: true);

      final children = await database.childDao.getAllChildren();
      for (final child in children) {
        final episodes = await database.episodeDao.getEpisodesByChild(child.id);
        for (final episode in episodes) {
          final attachments = await database.attachmentDao
              .getAttachmentsByEpisodeId(episode.id);

          for (final attachment in attachments) {
            final attachmentFile = File(attachment.localPath);
            if (await attachmentFile.exists()) {
              final fileName = path.basename(attachment.localPath);
              final destPath = path.join(
                attachmentsDir.path,
                'episode_${episode.id}_$fileName',
              );
              await attachmentFile.copy(destPath);
            }
          }
        }
      }

      // 5. Создаем metadata файл
      final metadata = {
        'version': '1.0.0',
        'created_at': DateTime.now().toIso8601String(),
        'children_count': children.length,
        'database_file': 'database.db',
        'attachments_dir': 'attachments',
      };

      final metadataFile = File(path.join(backupTempDir.path, 'metadata.json'));
      await metadataFile.writeAsString(_encodeJson(metadata));

      // 6. Создаем ZIP архив
      final encoder = ZipFileEncoder();
      final downloadsDir = await _getDownloadsDirectory();
      final zipPath = path.join(
        downloadsDir.path,
        'childs_health_backup_$timestamp.zip',
      );

      encoder.create(zipPath);
      await encoder.addDirectory(backupTempDir);
      encoder.close();

      // 7. Удаляем временную директорию
      await backupTempDir.delete(recursive: true);

      debugPrint('Backup created: $zipPath');
      return zipPath;
    } catch (e) {
      debugPrint('Error creating backup: $e');
      return null;
    }
  }

  /// Восстановить из резервной копии
  Future<bool> restoreBackup(String zipPath) async {
    try {
      final zipFile = File(zipPath);
      if (!await zipFile.exists()) {
        throw Exception('Backup file not found');
      }

      // Получаем директории
      final appDir = await getApplicationDocumentsDirectory();
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Создаем временную директорию для распаковки
      final restoreTempDir = Directory('${tempDir.path}/restore_$timestamp');
      if (!await restoreTempDir.exists()) {
        await restoreTempDir.create(recursive: true);
      }

      // 1. Распаковываем ZIP архив
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive) {
        final filename = file.name;
        final filePath = path.join(restoreTempDir.path, filename);

        if (file.isFile) {
          final outFile = File(filePath);
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
        } else {
          await Directory(filePath).create(recursive: true);
        }
      }

      // 2. Проверяем metadata
      final metadataFile = File(path.join(restoreTempDir.path, 'metadata.json'));
      if (!await metadataFile.exists()) {
        throw Exception('Invalid backup: metadata.json not found');
      }

      // 3. Закрываем текущую базу данных
      await database.close();

      // 4. Восстанавливаем файл базы данных
      final restoredDb = File(path.join(restoreTempDir.path, 'database.db'));
      if (await restoredDb.exists()) {
        final targetDbPath = path.join(appDir.path, 'app_database.sqlite');
        await restoredDb.copy(targetDbPath);
        debugPrint('Database restored');
      }

      // 5. Восстанавливаем WAL файл если есть
      final restoredWal = File(path.join(restoreTempDir.path, 'database.db-wal'));
      if (await restoredWal.exists()) {
        final targetWalPath = path.join(appDir.path, 'app_database.sqlite-wal');
        await restoredWal.copy(targetWalPath);
      }

      // 6. Восстанавливаем SHM файл если есть
      final restoredShm = File(path.join(restoreTempDir.path, 'database.db-shm'));
      if (await restoredShm.exists()) {
        final targetShmPath = path.join(appDir.path, 'app_database.sqlite-shm');
        await restoredShm.copy(targetShmPath);
      }

      // 7. Восстанавливаем файлы вложений
      final attachmentsDir = Directory(path.join(restoreTempDir.path, 'attachments'));
      if (await attachmentsDir.exists()) {
        final targetAttachmentsDir = Directory(path.join(appDir.path, 'attachments'));
        if (!await targetAttachmentsDir.exists()) {
          await targetAttachmentsDir.create(recursive: true);
        }

        await for (final entity in attachmentsDir.list()) {
          if (entity is File) {
            final fileName = path.basename(entity.path);
            final targetPath = path.join(targetAttachmentsDir.path, fileName);
            await entity.copy(targetPath);
          }
        }
        debugPrint('Attachments restored');
      }

      // 8. Удаляем временную директорию
      await restoreTempDir.delete(recursive: true);

      debugPrint('Restore completed successfully');
      return true;
    } catch (e) {
      debugPrint('Error restoring backup: $e');
      return false;
    }
  }

  /// Получить список доступных резервных копий
  Future<List<FileSystemEntity>> getBackupFiles() async {
    try {
      final downloadsDir = await _getDownloadsDirectory();
      final files = <FileSystemEntity>[];

      await for (final entity in downloadsDir.list()) {
        if (entity is File &&
            entity.path.endsWith('.zip') &&
            entity.path.contains('childs_health_backup')) {
          files.add(entity);
        }
      }

      // Сортируем по дате изменения (новые первыми)
      files.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });

      return files;
    } catch (e) {
      debugPrint('Error getting backup files: $e');
      return [];
    }
  }

  /// Удалить резервную копию
  Future<bool> deleteBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting backup: $e');
      return false;
    }
  }

  /// Получить размер резервной копии
  Future<int> getBackupSize(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      debugPrint('Error getting backup size: $e');
      return 0;
    }
  }

  /// Проверить разрешения на хранилище
  Future<bool> _checkPermissions() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.status;
      if (!status.isGranted) {
        final result = await Permission.storage.request();
        return result.isGranted;
      }
      return true;
    } else if (Platform.isIOS) {
      // iOS не требует явных разрешений для доступа к документам приложения
      return true;
    }
    return true;
  }

  /// Получить директорию Downloads
  Future<Directory> _getDownloadsDirectory() async {
    if (Platform.isAndroid) {
      // На Android используем внешнее хранилище
      final dir = Directory('/storage/emulated/0/Download/ChildsHealth');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    } else if (Platform.isIOS) {
      // На iOS используем директорию документов
      final appDir = await getApplicationDocumentsDirectory();
      final backupsDir = Directory(path.join(appDir.path, 'Backups'));
      if (!await backupsDir.exists()) {
        await backupsDir.create(recursive: true);
      }
      return backupsDir;
    } else {
      // Для других платформ используем Downloads системы
      return await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    }
  }

  /// Кодировать JSON
  String _encodeJson(Map<String, dynamic> data) {
    final buffer = StringBuffer();
    buffer.write('{');

    final entries = data.entries.toList();
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      buffer.write('"${entry.key}":"${entry.value}"');
      if (i < entries.length - 1) {
        buffer.write(',');
      }
    }

    buffer.write('}');
    return buffer.toString();
  }
}
