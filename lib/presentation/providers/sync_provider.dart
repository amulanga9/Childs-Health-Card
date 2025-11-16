import 'package:flutter/foundation.dart';
import '../../data/database/database.dart';
import '../../services/api_service.dart';

/// Состояние синхронизации
enum SyncState {
  idle,
  syncing,
  success,
  error,
}

/// Провайдер для синхронизации данных с backend
class SyncProvider with ChangeNotifier {
  final AppDatabase database;
  final ApiService apiService;

  SyncProvider({
    required this.database,
    required this.apiService,
  });

  SyncState _state = SyncState.idle;
  SyncState get state => _state;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Синхронизация всех данных с сервером
  Future<bool> syncAll() async {
    _state = SyncState.syncing;
    _errorMessage = null;
    notifyListeners();

    try {
      // Получаем все данные из локальной БД
      final children = await database.childDao.getAllChildren();
      final episodes = await _getAllEpisodes();
      final prescriptions = await _getAllPrescriptions();
      final intakes = await _getAllIntakes();
      final tests = await _getAllTests();
      final procedures = await _getAllProcedures();
      final attachments = await _getAllAttachments();

      // Отправляем на сервер
      final response = await apiService.syncData(
        children: children,
        episodes: episodes,
        prescriptions: prescriptions,
        intakes: intakes,
        tests: tests,
        procedures: procedures,
        attachments: attachments,
      );

      _lastSyncTime = DateTime.now();
      _state = SyncState.success;
      notifyListeners();

      debugPrint('Синхронизация успешна: $response');
      return true;
    } catch (e) {
      _state = SyncState.error;
      _errorMessage = 'Ошибка синхронизации: ${e.toString()}';
      notifyListeners();
      debugPrint('Ошибка синхронизации: $e');
      return false;
    }
  }

  /// Получить все эпизоды из БД
  Future<List<Episode>> _getAllEpisodes() async {
    final children = await database.childDao.getAllChildren();
    final List<Episode> allEpisodes = [];

    for (final child in children) {
      final episodes = await database.episodeDao.getEpisodesByChild(child.id);
      allEpisodes.addAll(episodes);
    }

    return allEpisodes;
  }

  /// Получить все назначения из БД
  Future<List<Prescription>> _getAllPrescriptions() async {
    final episodes = await _getAllEpisodes();
    final List<Prescription> allPrescriptions = [];

    for (final episode in episodes) {
      final prescriptions = await database.prescriptionDao
          .getPrescriptionsByEpisodeId(episode.id);
      allPrescriptions.addAll(prescriptions);
    }

    return allPrescriptions;
  }

  /// Получить все приёмы из БД
  Future<List<Intake>> _getAllIntakes() async {
    final prescriptions = await _getAllPrescriptions();
    final List<Intake> allIntakes = [];

    for (final prescription in prescriptions) {
      final intakes = await database.intakeDao
          .getIntakesByPrescriptionId(prescription.id);
      allIntakes.addAll(intakes);
    }

    return allIntakes;
  }

  /// Получить все анализы из БД
  Future<List<Test>> _getAllTests() async {
    final episodes = await _getAllEpisodes();
    final List<Test> allTests = [];

    for (final episode in episodes) {
      final tests = await database.testDao.getTestsByEpisodeId(episode.id);
      allTests.addAll(tests);
    }

    return allTests;
  }

  /// Получить все процедуры из БД
  Future<List<Procedure>> _getAllProcedures() async {
    final episodes = await _getAllEpisodes();
    final List<Procedure> allProcedures = [];

    for (final episode in episodes) {
      final procedures =
          await database.procedureDao.getProceduresByEpisodeId(episode.id);
      allProcedures.addAll(procedures);
    }

    return allProcedures;
  }

  /// Получить все вложения из БД
  Future<List<Attachment>> _getAllAttachments() async {
    final episodes = await _getAllEpisodes();
    final List<Attachment> allAttachments = [];

    for (final episode in episodes) {
      final attachments =
          await database.attachmentDao.getAttachmentsByEpisodeId(episode.id);
      allAttachments.addAll(attachments);
    }

    return allAttachments;
  }

  /// Сброс состояния
  void reset() {
    _state = SyncState.idle;
    _errorMessage = null;
    notifyListeners();
  }
}
