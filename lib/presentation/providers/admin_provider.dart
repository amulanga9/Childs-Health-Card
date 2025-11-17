import 'package:flutter/foundation.dart';
import '../../data/database/database.dart';
import 'admin_logs_provider.dart';

/// Провайдер для управления админской частью приложения
///
/// Предоставляет CRUD операции для всех сущностей с логированием
class AdminProvider with ChangeNotifier {
  final AppDatabase _database;
  final AdminLogsProvider? _logsProvider;

  String _adminName = 'Администратор';

  // Статистика
  int _childrenCount = 0;
  int _episodesCount = 0;
  int _prescriptionsCount = 0;
  int _testsCount = 0;
  int _proceduresCount = 0;
  int _attachmentsCount = 0;

  bool _isLoading = false;

  AdminProvider({
    required AppDatabase database,
    AdminLogsProvider? logsProvider,
  })  : _database = database,
        _logsProvider = logsProvider {
    _loadStatistics();
  }

  // Getters
  int get childrenCount => _childrenCount;
  int get episodesCount => _episodesCount;
  int get prescriptionsCount => _prescriptionsCount;
  int get testsCount => _testsCount;
  int get proceduresCount => _proceduresCount;
  int get attachmentsCount => _attachmentsCount;
  bool get isLoading => _isLoading;

  int get totalRecords =>
      _childrenCount +
      _episodesCount +
      _prescriptionsCount +
      _testsCount +
      _proceduresCount +
      _attachmentsCount;

  /// Установка имени администратора для логирования
  void setAdminName(String name) {
    _adminName = name;
  }

  /// Загрузка статистики
  Future<void> _loadStatistics() async {
    _isLoading = true;
    notifyListeners();

    try {
      _childrenCount = await _database.getAllChildren().then((list) => list.length);
      _episodesCount = await _database.getAllEpisodes().then((list) => list.length);
      _prescriptionsCount =
          await _database.getAllPrescriptions().then((list) => list.length);
      _testsCount = await _database.getAllTests().then((list) => list.length);
      _proceduresCount = await _database.getAllProcedures().then((list) => list.length);
      _attachmentsCount =
          await _database.getAllAttachments().then((list) => list.length);

      debugPrint('📊 Statistics loaded: $totalRecords total records');
    } catch (e) {
      debugPrint('❌ Error loading statistics: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Обновление статистики
  Future<void> refreshStatistics() async {
    await _loadStatistics();
  }

  // ============ CRUD Операции для детей ============

  /// Получение всех детей
  Future<List<Child>> getAllChildren() async {
    return await _database.getAllChildren();
  }

  /// Получение ребенка по ID
  Future<Child?> getChild(int id) async {
    return await _database.getChildById(id);
  }

  /// Создание ребенка
  Future<int> createChild(Child child) async {
    final id = await _database.insertChild(child);

    await _logsProvider?.addLog(
      action: 'create',
      entityType: 'child',
      adminName: _adminName,
      entityId: id,
      entityName: child.name,
    );

    await _loadStatistics();
    return id;
  }

  /// Обновление ребенка
  Future<void> updateChild(Child child) async {
    await _database.updateChild(child);

    await _logsProvider?.addLog(
      action: 'update',
      entityType: 'child',
      adminName: _adminName,
      entityId: child.id,
      entityName: child.name,
    );

    notifyListeners();
  }

  /// Удаление ребенка
  Future<void> deleteChild(int id) async {
    final child = await _database.getChildById(id);

    await _database.deleteChild(id);

    await _logsProvider?.addLog(
      action: 'delete',
      entityType: 'child',
      adminName: _adminName,
      entityId: id,
      entityName: child?.name,
    );

    await _loadStatistics();
  }

  // ============ CRUD Операции для эпизодов ============

  /// Получение всех эпизодов
  Future<List<Episode>> getAllEpisodes() async {
    return await _database.getAllEpisodes();
  }

  /// Получение эпизодов по ребенку
  Future<List<Episode>> getEpisodesByChild(int childId) async {
    return await _database.getEpisodesByChild(childId);
  }

  /// Получение эпизода по ID
  Future<Episode?> getEpisode(int id) async {
    return await _database.getEpisodeById(id);
  }

  /// Создание эпизода
  Future<int> createEpisode(Episode episode) async {
    final id = await _database.insertEpisode(episode);

    await _logsProvider?.addLog(
      action: 'create',
      entityType: 'episode',
      adminName: _adminName,
      entityId: id,
      entityName: episode.diagnosis,
    );

    await _loadStatistics();
    return id;
  }

  /// Обновление эпизода
  Future<void> updateEpisode(Episode episode) async {
    await _database.updateEpisode(episode);

    await _logsProvider?.addLog(
      action: 'update',
      entityType: 'episode',
      adminName: _adminName,
      entityId: episode.id,
      entityName: episode.diagnosis,
    );

    notifyListeners();
  }

  /// Удаление эпизода
  Future<void> deleteEpisode(int id) async {
    final episode = await _database.getEpisodeById(id);

    await _database.deleteEpisode(id);

    await _logsProvider?.addLog(
      action: 'delete',
      entityType: 'episode',
      adminName: _adminName,
      entityId: id,
      entityName: episode?.diagnosis,
    );

    await _loadStatistics();
  }

  // ============ CRUD Операции для назначений ============

  /// Получение всех назначений
  Future<List<Prescription>> getAllPrescriptions() async {
    return await _database.getAllPrescriptions();
  }

  /// Получение назначений по эпизоду
  Future<List<Prescription>> getPrescriptionsByEpisode(int episodeId) async {
    return await _database.getPrescriptionsByEpisode(episodeId);
  }

  /// Удаление назначения
  Future<void> deletePrescription(int id) async {
    final prescription = await _database.getPrescriptionById(id);

    await _database.deletePrescription(id);

    await _logsProvider?.addLog(
      action: 'delete',
      entityType: 'prescription',
      adminName: _adminName,
      entityId: id,
      entityName: prescription?.drugName,
    );

    await _loadStatistics();
  }

  // ============ CRUD Операции для анализов ============

  /// Получение всех анализов
  Future<List<Test>> getAllTests() async {
    return await _database.getAllTests();
  }

  /// Удаление анализа
  Future<void> deleteTest(int id) async {
    final test = await _database.getTestById(id);

    await _database.deleteTest(id);

    await _logsProvider?.addLog(
      action: 'delete',
      entityType: 'test',
      adminName: _adminName,
      entityId: id,
      entityName: test?.kind,
    );

    await _loadStatistics();
  }

  // ============ CRUD Операции для процедур ============

  /// Получение всех процедур
  Future<List<Procedure>> getAllProcedures() async {
    return await _database.getAllProcedures();
  }

  /// Удаление процедуры
  Future<void> deleteProcedure(int id) async {
    final procedure = await _database.getProcedureById(id);

    await _database.deleteProcedure(id);

    await _logsProvider?.addLog(
      action: 'delete',
      entityType: 'procedure',
      adminName: _adminName,
      entityId: id,
      entityName: procedure?.kind,
    );

    await _loadStatistics();
  }

  // ============ CRUD Операции для файлов ============

  /// Получение всех файлов
  Future<List<Attachment>> getAllAttachments() async {
    return await _database.getAllAttachments();
  }

  /// Удаление файла
  Future<void> deleteAttachment(int id) async {
    await _database.deleteAttachment(id);

    await _logsProvider?.addLog(
      action: 'delete',
      entityType: 'attachment',
      adminName: _adminName,
      entityId: id,
    );

    await _loadStatistics();
  }

  // ============ Массовые операции ============

  /// Удаление всех данных ребенка
  Future<void> deleteChildWithAllData(int childId) async {
    final child = await _database.getChildById(childId);

    // Удаляем ребенка (CASCADE удалит связанные данные)
    await _database.deleteChild(childId);

    await _logsProvider?.addLog(
      action: 'delete',
      entityType: 'child',
      adminName: _adminName,
      entityId: childId,
      entityName: '${child?.name} (со всеми данными)',
    );

    await _loadStatistics();
  }

  /// Экспорт всех данных
  Future<void> exportAllData() async {
    await _logsProvider?.addLog(
      action: 'export',
      entityType: 'system',
      adminName: _adminName,
      entityName: 'Все данные',
    );
  }

  /// Импорт данных
  Future<void> importData() async {
    await _logsProvider?.addLog(
      action: 'import',
      entityType: 'system',
      adminName: _adminName,
      entityName: 'Импорт данных',
    );

    await _loadStatistics();
  }

  /// Очистка всей базы данных
  Future<void> clearAllData() async {
    // Здесь можно добавить логику очистки всей БД
    // Пока просто логируем

    await _logsProvider?.addLog(
      action: 'delete',
      entityType: 'system',
      adminName: _adminName,
      entityName: 'Очистка всей базы данных',
    );

    await _loadStatistics();
  }
}
