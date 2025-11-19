import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';
import '../data/database/database.dart';

/// Сервис для резервного копирования и восстановления данных
///
/// SECURITY: Все backup файлы зашифрованы AES-256
class BackupService {
  final AppDatabase database;

  BackupService({required this.database});

  /// Создать зашифрованную резервную копию
  ///
  /// [password] - пароль для шифрования (минимум 6 символов)
  /// Возвращает путь к созданному зашифрованному файлу
  Future<String?> createBackup({required String password}) async {
    try {
      // Валидация пароля
      if (password.length < 6) {
        throw Exception('Пароль должен содержать минимум 6 символов');
      }

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
        debugPrint('✅ Database copied');
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
            if (attachment.localPath.isEmpty) continue;

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
        'encrypted': true,  // Маркер что backup зашифрован
      };

      final metadataFile = File(path.join(backupTempDir.path, 'metadata.json'));
      await metadataFile.writeAsString(jsonEncode(metadata));

      // 6. Создаем ZIP архив в памяти
      final encoder = ZipFileEncoder();
      final tempZipPath = path.join(tempDir.path, 'temp_backup_$timestamp.zip');

      encoder.create(tempZipPath);
      await encoder.addDirectory(backupTempDir);
      encoder.close();

      // 7. Читаем ZIP в память и шифруем
      final zipBytes = await File(tempZipPath).readAsBytes();
      final encryptedBytes = _encryptData(zipBytes, password);

      // 8. Сохраняем зашифрованный backup
      final downloadsDir = await _getDownloadsDirectory();
      final encryptedPath = path.join(
        downloadsDir.path,
        'childs_health_backup_$timestamp.chb',  // .chb = Child's Health Backup (encrypted)
      );

      await File(encryptedPath).writeAsBytes(encryptedBytes);

      // 9. Очистка временных файлов
      await backupTempDir.delete(recursive: true);
      await File(tempZipPath).delete();

      debugPrint('✅ Encrypted backup created: $encryptedPath');
      debugPrint('📦 Size: ${(encryptedBytes.length / 1024 / 1024).toStringAsFixed(2)} MB');
      return encryptedPath;
    } catch (e, stackTrace) {
      debugPrint('❌ Error creating backup: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Восстановить из зашифрованной резервной копии
  ///
  /// [backupPath] - путь к зашифрованному backup файлу
  /// [password] - пароль для расшифровки
  Future<bool> restoreBackup({
    required String backupPath,
    required String password,
  }) async {
    try {
      final backupFile = File(backupPath);
      if (!await backupFile.exists()) {
        throw Exception('Backup file not found');
      }

      // Проверяем расширение файла
      final isEncrypted = backupPath.endsWith('.chb');

      // Получаем директории
      final appDir = await getApplicationDocumentsDirectory();
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Создаем временную директорию для распаковки
      final restoreTempDir = Directory('${tempDir.path}/restore_$timestamp');
      if (!await restoreTempDir.exists()) {
        await restoreTempDir.create(recursive: true);
      }

      List<int> zipBytes;

      if (isEncrypted) {
        // 1. Читаем и расшифровываем
        final encryptedBytes = await backupFile.readAsBytes();

        try {
          zipBytes = _decryptData(encryptedBytes, password);
        } catch (e) {
          throw Exception('Неверный пароль или поврежденный backup');
        }
      } else {
        // Старый формат (незашифрованный) - для обратной совместимости
        debugPrint('⚠️  Warning: Restoring from unencrypted backup');
        zipBytes = await backupFile.readAsBytes();
      }

      // 2. Распаковываем ZIP архив
      final archive = ZipDecoder().decodeBytes(zipBytes);

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

      // 3. Проверяем metadata
      final metadataFile = File(path.join(restoreTempDir.path, 'metadata.json'));
      if (!await metadataFile.exists()) {
        throw Exception('Invalid backup: metadata.json not found');
      }

      // 4. Закрываем текущую базу данных
      await database.close();

      // 5. Восстанавливаем файл базы данных
      final restoredDb = File(path.join(restoreTempDir.path, 'database.db'));
      if (await restoredDb.exists()) {
        final targetDbPath = path.join(appDir.path, 'app_database.sqlite');
        await restoredDb.copy(targetDbPath);
        debugPrint('✅ Database restored');
      }

      // 6. Восстанавливаем WAL файл если есть
      final restoredWal = File(path.join(restoreTempDir.path, 'database.db-wal'));
      if (await restoredWal.exists()) {
        final targetWalPath = path.join(appDir.path, 'app_database.sqlite-wal');
        await restoredWal.copy(targetWalPath);
      }

      // 7. Восстанавливаем SHM файл если есть
      final restoredShm = File(path.join(restoreTempDir.path, 'database.db-shm'));
      if (await restoredShm.exists()) {
        final targetShmPath = path.join(appDir.path, 'app_database.sqlite-shm');
        await restoredShm.copy(targetShmPath);
      }

      // 8. Восстанавливаем файлы вложений
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
        debugPrint('✅ Attachments restored');
      }

      // 9. Удаляем временную директорию
      await restoreTempDir.delete(recursive: true);

      debugPrint('✅ Restore completed successfully');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Error restoring backup: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Зашифровать данные с использованием AES-256
  ///
  /// [data] - данные для шифрования
  /// [password] - пароль пользователя
  Uint8List _encryptData(List<int> data, String password) {
    try {
      // Генерируем ключ из пароля (PBKDF2-like через SHA-256)
      final key = _deriveKey(password);

      // Генерируем случайный IV (Initialization Vector)
      final iv = encrypt.IV.fromSecureRandom(16);

      // Создаем encrypter с AES-256
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.cbc),
      );

      // Шифруем данные
      final encrypted = encrypter.encryptBytes(data, iv: iv);

      // Формат: [IV (16 bytes)][Encrypted Data]
      // IV нужен для расшифровки, но его можно хранить открыто
      final result = Uint8List(16 + encrypted.bytes.length);
      result.setRange(0, 16, iv.bytes);
      result.setRange(16, result.length, encrypted.bytes);

      return result;
    } catch (e) {
      debugPrint('❌ Encryption error: $e');
      rethrow;
    }
  }

  /// Расшифровать данные AES-256
  ///
  /// [encryptedData] - зашифрованные данные
  /// [password] - пароль пользователя
  List<int> _decryptData(List<int> encryptedData, String password) {
    try {
      if (encryptedData.length < 17) {
        throw Exception('Invalid encrypted data: too short');
      }

      // Извлекаем IV (первые 16 bytes)
      final ivBytes = encryptedData.sublist(0, 16);
      final iv = encrypt.IV(Uint8List.fromList(ivBytes));

      // Извлекаем зашифрованные данные
      final cipherBytes = encryptedData.sublist(16);

      // Генерируем ключ из пароля (тот же что при шифровании)
      final key = _deriveKey(password);

      // Создаем encrypter
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.cbc),
      );

      // Расшифровываем
      final encrypted = encrypt.Encrypted(Uint8List.fromList(cipherBytes));
      final decrypted = encrypter.decryptBytes(encrypted, iv: iv);

      return decrypted;
    } catch (e) {
      debugPrint('❌ Decryption error: $e');
      throw Exception('Decryption failed: wrong password or corrupted file');
    }
  }

  /// Генерация ключа из пароля (Key Derivation Function)
  ///
  /// Использует SHA-256 для создания 256-битного ключа из пароля
  /// SECURITY: В production рекомендуется PBKDF2, Argon2 или scrypt
  encrypt.Key _deriveKey(String password) {
    // Используем соль для усиления (в production хранить отдельно)
    const salt = 'ChildsHealthCard2025'; // Application-specific salt

    // Комбинируем пароль с солью
    final passwordWithSalt = password + salt;

    // Генерируем 256-битный ключ через SHA-256
    final bytes = utf8.encode(passwordWithSalt);
    final digest = sha256.convert(bytes);

    return encrypt.Key(Uint8List.fromList(digest.bytes));
  }

  /// Получить список доступных резервных копий
  Future<List<BackupFile>> getBackupFiles() async {
    try {
      final downloadsDir = await _getDownloadsDirectory();
      final backupFiles = <BackupFile>[];

      await for (final entity in downloadsDir.list()) {
        if (entity is File) {
          final filename = path.basename(entity.path);

          // Поддерживаем как зашифрованные (.chb), так и старые (.zip)
          if (filename.startsWith('childs_health_backup') &&
              (filename.endsWith('.chb') || filename.endsWith('.zip'))) {

            final stat = await entity.stat();
            final isEncrypted = filename.endsWith('.chb');

            backupFiles.add(BackupFile(
              path: entity.path,
              name: filename,
              size: stat.size,
              created: stat.modified,
              isEncrypted: isEncrypted,
            ));
          }
        }
      }

      // Сортируем по дате (новые первыми)
      backupFiles.sort((a, b) => b.created.compareTo(a.created));

      return backupFiles;
    } catch (e) {
      debugPrint('❌ Error getting backup files: $e');
      return [];
    }
  }

  /// Удалить резервную копию
  Future<bool> deleteBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('✅ Backup deleted: $filePath');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error deleting backup: $e');
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
      debugPrint('❌ Error getting backup size: $e');
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
}

/// Информация о backup файле
class BackupFile {
  final String path;
  final String name;
  final int size;
  final DateTime created;
  final bool isEncrypted;

  BackupFile({
    required this.path,
    required this.name,
    required this.size,
    required this.created,
    required this.isEncrypted,
  });

  String get sizeFormatted {
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(size / 1024 / 1024).toStringAsFixed(2)} MB';
    }
  }
}
