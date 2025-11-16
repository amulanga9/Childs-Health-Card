import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../data/database/database.dart';
import '../../data/database/daos/episode_dao.dart';
import '../../data/database/daos/prescription_dao.dart';
import '../../data/database/daos/intake_dao.dart';
import '../../data/database/daos/test_dao.dart';
import '../../data/database/daos/procedure_dao.dart';
import '../../data/database/daos/attachment_dao.dart';
import '../../services/api_service.dart';

/// Provider для управления состоянием экрана деталей эпизода
class EpisodeDetailProvider with ChangeNotifier {
  final AppDatabase _database;
  final ApiService? _apiService;
  final int episodeId;

  late final EpisodeDao _episodeDao;
  late final PrescriptionDao _prescriptionDao;
  late final IntakeDao _intakeDao;
  late final TestDao _testDao;
  late final ProcedureDao _procedureDao;
  late final AttachmentDao _attachmentDao;

  /// Эпизод
  Episode? _episode;
  Episode? get episode => _episode;

  /// Цепочка эпизодов
  List<Episode>? _episodeChain;
  List<Episode>? get episodeChain => _episodeChain;

  /// Назначения
  List<Prescription> _prescriptions = [];
  List<Prescription> get prescriptions => _prescriptions;

  /// Приёмы лекарств на сегодня
  Map<int, List<Intake>> _intakesByPrescription = {};
  Map<int, List<Intake>> get intakesByPrescription => _intakesByPrescription;

  /// Анализы
  List<Test> _tests = [];
  List<Test> get tests => _tests;

  /// Процедуры
  List<Procedure> _procedures = [];
  List<Procedure> get procedures => _procedures;

  /// Вложения
  List<Attachment> _attachments = [];
  List<Attachment> get attachments => _attachments;

  /// Состояние загрузки
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Состояние загрузки файла
  bool _isUploadingFile = false;
  bool get isUploadingFile => _isUploadingFile;

  EpisodeDetailProvider(
    this._database,
    this.episodeId, {
    ApiService? apiService,
  }) : _apiService = apiService {
    _episodeDao = _database.episodeDao;
    _prescriptionDao = _database.prescriptionDao;
    _intakeDao = _database.intakeDao;
    _testDao = _database.testDao;
    _procedureDao = _database.procedureDao;
    _attachmentDao = _database.attachmentDao;
    _loadData();
  }

  /// Загрузить все данные эпизода
  Future<void> _loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Загружаем эпизод
      _episode = await _episodeDao.getEpisodeById(episodeId);

      if (_episode != null) {
        // Загружаем цепочку эпизодов
        _episodeChain = await _episodeDao.getEpisodesChain(episodeId);

        // Загружаем назначения
        _prescriptions = await _prescriptionDao.getPrescriptionsByEpisodeId(episodeId);

        // Загружаем приёмы для каждого назначения
        await _loadIntakes();

        // Загружаем анализы
        _tests = await _testDao.getTestsByEpisodeId(episodeId);

        // Загружаем процедуры
        _procedures = await _procedureDao.getProceduresByEpisodeId(episodeId);

        // Загружаем вложения
        _attachments = await _attachmentDao.getAttachmentsByEpisodeId(episodeId);
      }
    } catch (e) {
      debugPrint('Ошибка загрузки данных эпизода: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Загрузить приёмы лекарств
  Future<void> _loadIntakes() async {
    _intakesByPrescription.clear();

    for (final prescription in _prescriptions) {
      final intakes = await _intakeDao.getIntakesByPrescriptionId(prescription.id);
      _intakesByPrescription[prescription.id] = intakes;
    }
  }

  /// Отметить приём лекарства
  Future<void> markIntake({
    required int prescriptionId,
    required DateTime atDatetime,
    required bool taken,
    String? reasonSkip,
  }) async {
    try {
      // Проверяем, есть ли уже запись о приёме в это время
      final existingIntakes = _intakesByPrescription[prescriptionId] ?? [];
      final existing = existingIntakes.where((intake) {
        return intake.atDatetime.year == atDatetime.year &&
            intake.atDatetime.month == atDatetime.month &&
            intake.atDatetime.day == atDatetime.day &&
            intake.atDatetime.hour == atDatetime.hour &&
            intake.atDatetime.minute == atDatetime.minute;
      }).firstOrNull;

      if (existing != null) {
        // Обновляем существующую запись
        final updated = existing.copyWith(
          taken: taken,
          reasonSkip: reasonSkip ?? '',
        );
        await _intakeDao.updateIntake(updated);
      } else {
        // Создаём новую запись
        await _intakeDao.createIntake(
          IntakesCompanion.insert(
            prescriptionId: prescriptionId,
            atDatetime: atDatetime,
            taken: taken,
            reasonSkip: reasonSkip ?? '',
          ),
        );
      }

      // Перезагружаем приёмы
      await _loadIntakes();
      notifyListeners();
    } catch (e) {
      debugPrint('Ошибка отметки приёма: $e');
    }
  }

  /// Удалить отметку о приёме
  Future<void> deleteIntake(int intakeId) async {
    try {
      await _intakeDao.deleteIntake(intakeId);
      await _loadIntakes();
      notifyListeners();
    } catch (e) {
      debugPrint('Ошибка удаления отметки: $e');
    }
  }

  /// Закрыть эпизод
  Future<bool> closeEpisode() async {
    if (_episode == null) return false;

    try {
      final updatedEpisode = _episode!.copyWith(
        status: 'closed',
        endDate: DateTime.now(),
      );

      await _episodeDao.updateEpisode(updatedEpisode);
      _episode = updatedEpisode;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Ошибка закрытия эпизода: $e');
      return false;
    }
  }

  /// Создать дочерний эпизод (болезнь переросла в новую)
  Future<int?> createChildEpisode({
    required String diagnosis,
    required String notes,
  }) async {
    if (_episode == null) return null;

    try {
      final newEpisodeId = await _episodeDao.createEpisodeWithParent(
        childId: _episode!.childId,
        parentEpisodeId: episodeId,
        diagnosis: diagnosis,
        startDate: DateTime.now(),
        notes: notes,
      );

      return newEpisodeId;
    } catch (e) {
      debugPrint('Ошибка создания дочернего эпизода: $e');
      return null;
    }
  }

  /// Обновить заметки эпизода
  Future<void> updateNotes(String notes) async {
    if (_episode == null) return;

    try {
      final updatedEpisode = _episode!.copyWith(notes: notes);
      await _episodeDao.updateEpisode(updatedEpisode);
      _episode = updatedEpisode;
      notifyListeners();
    } catch (e) {
      debugPrint('Ошибка обновления заметок: $e');
    }
  }

  /// Добавить вложение
  Future<void> addAttachment({
    required String kind,
    required String localPath,
    String? cloudKey,
  }) async {
    try {
      await _attachmentDao.createAttachment(
        AttachmentsCompanion.insert(
          episodeId: episodeId,
          kind: kind,
          localPath: localPath,
          cloudKey: cloudKey ?? '',
          atDatetime: DateTime.now(),
        ),
      );

      _attachments = await _attachmentDao.getAttachmentsByEpisodeId(episodeId);
      notifyListeners();
    } catch (e) {
      debugPrint('Ошибка добавления вложения: $e');
    }
  }

  /// Удалить вложение
  Future<void> deleteAttachment(int attachmentId) async {
    try {
      await _attachmentDao.deleteAttachment(attachmentId);
      _attachments = await _attachmentDao.getAttachmentsByEpisodeId(episodeId);
      notifyListeners();
    } catch (e) {
      debugPrint('Ошибка удаления вложения: $e');
    }
  }

  /// Добавить вложение с загрузкой в облако
  Future<bool> addAttachmentWithUpload({
    required File file,
    required String kind,
  }) async {
    if (_apiService == null) {
      // Если нет API сервиса, сохраняем только локально
      await addAttachment(
        kind: kind,
        localPath: file.path,
      );
      return true;
    }

    _isUploadingFile = true;
    notifyListeners();

    try {
      // Загружаем файл в Object Storage
      final uploadResponse = await _apiService!.uploadFile(
        episodeId: episodeId,
        file: file,
      );

      if (uploadResponse.success) {
        // Создаём запись о вложении с cloud_key
        await _attachmentDao.createAttachment(
          AttachmentsCompanion.insert(
            episodeId: episodeId,
            kind: kind,
            localPath: file.path,
            cloudKey: uploadResponse.cloudKey,
            atDatetime: DateTime.now(),
          ),
        );

        _attachments = await _attachmentDao.getAttachmentsByEpisodeId(episodeId);
        _isUploadingFile = false;
        notifyListeners();
        return true;
      } else {
        _isUploadingFile = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('Ошибка загрузки файла: $e');
      _isUploadingFile = false;
      notifyListeners();

      // В случае ошибки сохраняем локально
      await addAttachment(
        kind: kind,
        localPath: file.path,
      );
      return false;
    }
  }

  /// Обновить данные
  Future<void> refresh() async {
    await _loadData();
  }
}
