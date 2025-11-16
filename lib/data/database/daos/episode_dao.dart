import 'package:drift/drift.dart';
import '../database.dart';
import '../tables.dart';

part 'episode_dao.g.dart';

/// DAO для работы с эпизодами болезни
/// Предоставляет методы для CRUD операций с эпизодами заболеваний
@DriftAccessor(tables: [Episodes, Children])
class EpisodeDao extends DatabaseAccessor<AppDatabase> with _$EpisodeDaoMixin {
  EpisodeDao(AppDatabase db) : super(db);

  /// Получить все эпизоды
  Future<List<Episode>> getAllEpisodes() {
    return (select(episodes)
          ..orderBy([(t) => OrderingTerm(expression: t.startDate, mode: OrderingMode.desc)]))
        .get();
  }

  /// Получить эпизод по ID
  Future<Episode?> getEpisodeById(int id) {
    return (select(episodes)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Получить эпизоды конкретного ребёнка
  Future<List<Episode>> getEpisodesByChildId(int childId) {
    return (select(episodes)
          ..where((t) => t.childId.equals(childId))
          ..orderBy([(t) => OrderingTerm(expression: t.startDate, mode: OrderingMode.desc)]))
        .get();
  }

  /// Получить активные эпизоды
  Future<List<Episode>> getActiveEpisodes() {
    return (select(episodes)
          ..where((t) => t.status.equals('active'))
          ..orderBy([(t) => OrderingTerm(expression: t.startDate, mode: OrderingMode.desc)]))
        .get();
  }

  /// Получить активные эпизоды для ребёнка
  Future<List<Episode>> getActiveEpisodesByChildId(int childId) {
    return (select(episodes)
          ..where((t) => t.childId.equals(childId) & t.status.equals('active'))
          ..orderBy([(t) => OrderingTerm(expression: t.startDate, mode: OrderingMode.desc)]))
        .get();
  }

  /// Получить эпизоды по статусу
  Future<List<Episode>> getEpisodesByStatus(String status) {
    return (select(episodes)
          ..where((t) => t.status.equals(status))
          ..orderBy([(t) => OrderingTerm(expression: t.startDate, mode: OrderingMode.desc)]))
        .get();
  }

  /// Получить эпизоды за период
  Future<List<Episode>> getEpisodesByDateRange(DateTime startDate, DateTime endDate) {
    return (select(episodes)
          ..where((t) => t.startDate.isBetweenValues(startDate, endDate))
          ..orderBy([(t) => OrderingTerm(expression: t.startDate, mode: OrderingMode.desc)]))
        .get();
  }

  /// Поиск эпизодов по диагнозу
  Future<List<Episode>> searchEpisodesByDiagnosis(String query) {
    return (select(episodes)
          ..where((t) => t.diagnosis.like('%$query%'))
          ..orderBy([(t) => OrderingTerm(expression: t.startDate, mode: OrderingMode.desc)]))
        .get();
  }

  /// Создать новый эпизод
  Future<int> createEpisode(EpisodesCompanion entry) {
    return into(episodes).insert(entry);
  }

  /// Обновить эпизод
  Future<bool> updateEpisode(Episode episode) {
    return update(episodes).replace(episode);
  }

  /// Удалить эпизод
  Future<int> deleteEpisode(int id) {
    return (delete(episodes)..where((t) => t.id.equals(id))).go();
  }

  /// Завершить эпизод (установить дату окончания и статус)
  Future<void> completeEpisode(int id, DateTime endDate) {
    return (update(episodes)..where((t) => t.id.equals(id))).write(
      EpisodesCompanion(
        endDate: Value(endDate),
        status: const Value('recovered'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Получить статистику по эпизодам для ребёнка
  Future<Map<String, int>> getEpisodeStatsByChildId(int childId) async {
    final total = await (select(episodes)
          ..where((t) => t.childId.equals(childId)))
        .get();

    final active = total.where((e) => e.status == 'active').length;
    final recovered = total.where((e) => e.status == 'recovered').length;
    final chronic = total.where((e) => e.status == 'chronic').length;

    return {
      'total': total.length,
      'active': active,
      'recovered': recovered,
      'chronic': chronic,
    };
  }

  /// Stream всех эпизодов
  Stream<List<Episode>> watchAllEpisodes() {
    return (select(episodes)
          ..orderBy([(t) => OrderingTerm(expression: t.startDate, mode: OrderingMode.desc)]))
        .watch();
  }

  /// Stream эпизодов ребёнка
  Stream<List<Episode>> watchEpisodesByChildId(int childId) {
    return (select(episodes)
          ..where((t) => t.childId.equals(childId))
          ..orderBy([(t) => OrderingTerm(expression: t.startDate, mode: OrderingMode.desc)]))
        .watch();
  }

  /// Stream активных эпизодов
  Stream<List<Episode>> watchActiveEpisodes() {
    return (select(episodes)
          ..where((t) => t.status.equals('active'))
          ..orderBy([(t) => OrderingTerm(expression: t.startDate, mode: OrderingMode.desc)]))
        .watch();
  }

  // ============================================
  // МЕТОДЫ ДЛЯ РАБОТЫ С ЦЕПОЧКАМИ ЭПИЗОДОВ
  // ============================================

  /// Создать эпизод с родительским эпизодом
  /// Используется когда одна болезнь переросла в другую
  ///
  /// Пример: ОРВИ → Бронхит → Пневмония
  Future<int> createEpisodeWithParent({
    required int childId,
    required int parentEpisodeId,
    required String diagnosis,
    required DateTime startDate,
    String notes = '',
  }) async {
    // Проверяем что родительский эпизод существует
    final parent = await getEpisodeById(parentEpisodeId);
    if (parent == null) {
      throw Exception('Родительский эпизод не найден');
    }

    // Проверяем что родитель относится к тому же ребёнку
    if (parent.childId != childId) {
      throw Exception('Родительский эпизод принадлежит другому ребёнку');
    }

    return await createEpisode(
      EpisodesCompanion.insert(
        childId: childId,
        parentEpisodeId: Value(parentEpisodeId),
        diagnosis: diagnosis,
        startDate: startDate,
        notes: Value(notes),
      ),
    );
  }

  /// Получить всю цепочку эпизодов для данного эпизода
  /// Возвращает список от самого раннего до текущего
  ///
  /// Пример: [ОРВИ, Бронхит, Пневмония]
  Future<List<Episode>> getEpisodesChain(int episodeId) async {
    final chain = <Episode>[];
    Episode? current = await getEpisodeById(episodeId);

    // Двигаемся вверх по цепочке к корню
    while (current != null) {
      chain.insert(0, current); // Добавляем в начало
      if (current.parentEpisodeId != null) {
        current = await getEpisodeById(current.parentEpisodeId!);
      } else {
        current = null;
      }
    }

    return chain;
  }

  /// Получить дочерние эпизоды (те, что переросли из данного)
  Future<List<Episode>> getChildEpisodes(int parentEpisodeId) {
    return (select(episodes)
          ..where((t) => t.parentEpisodeId.equals(parentEpisodeId))
          ..orderBy([(t) => OrderingTerm(expression: t.startDate)]))
        .get();
  }

  /// Получить корневой эпизод цепочки
  Future<Episode> getRootEpisode(int episodeId) async {
    final chain = await getEpisodesChain(episodeId);
    return chain.first;
  }

  /// Проверить, является ли эпизод частью цепочки
  Future<bool> isPartOfChain(int episodeId) async {
    final episode = await getEpisodeById(episodeId);
    if (episode == null) return false;

    // Есть родитель или есть дети
    if (episode.parentEpisodeId != null) return true;

    final children = await getChildEpisodes(episodeId);
    return children.isNotEmpty;
  }

  // ============================================
  // РАСШИРЕННАЯ СТАТИСТИКА
  // ============================================

  /// Получить годовую статистику по эпизодам для ребёнка
  ///
  /// Возвращает:
  /// - count: количество эпизодов за год
  /// - averageDuration: средняя длительность в днях
  /// - topDiagnoses: топ диагнозов с количеством
  Future<Map<String, dynamic>> getYearlyStatsByChildId(int childId, int year) async {
    final startOfYear = DateTime(year, 1, 1);
    final endOfYear = DateTime(year, 12, 31, 23, 59, 59);

    // Получаем все эпизоды за год
    final yearEpisodes = await (select(episodes)
          ..where((t) =>
              t.childId.equals(childId) &
              t.startDate.isBetweenValues(startOfYear, endOfYear)))
        .get();

    if (yearEpisodes.isEmpty) {
      return {
        'count': 0,
        'averageDuration': 0.0,
        'topDiagnoses': <Map<String, dynamic>>[],
      };
    }

    // Средняя длительность
    double totalDuration = 0;
    int completedCount = 0;

    for (final episode in yearEpisodes) {
      if (episode.endDate != null) {
        final duration = episode.endDate!.difference(episode.startDate).inDays;
        totalDuration += duration;
        completedCount++;
      }
    }

    final averageDuration = completedCount > 0 ? totalDuration / completedCount : 0.0;

    // Топ диагнозов
    final diagnosisCount = <String, int>{};
    for (final episode in yearEpisodes) {
      diagnosisCount[episode.diagnosis] = (diagnosisCount[episode.diagnosis] ?? 0) + 1;
    }

    // Сортируем по количеству
    final topDiagnoses = diagnosisCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topDiagnosesList = topDiagnoses
        .take(10)
        .map((e) => {'diagnosis': e.key, 'count': e.value})
        .toList();

    return {
      'count': yearEpisodes.length,
      'averageDuration': averageDuration,
      'topDiagnoses': topDiagnosesList,
    };
  }

  /// Получить статистику по месяцам за год
  /// Возвращает количество эпизодов по месяцам
  Future<Map<int, int>> getMonthlyStatsForYear(int childId, int year) async {
    final startOfYear = DateTime(year, 1, 1);
    final endOfYear = DateTime(year, 12, 31, 23, 59, 59);

    final yearEpisodes = await (select(episodes)
          ..where((t) =>
              t.childId.equals(childId) &
              t.startDate.isBetweenValues(startOfYear, endOfYear)))
        .get();

    final monthlyStats = <int, int>{};
    for (int month = 1; month <= 12; month++) {
      monthlyStats[month] = 0;
    }

    for (final episode in yearEpisodes) {
      final month = episode.startDate.month;
      monthlyStats[month] = (monthlyStats[month] ?? 0) + 1;
    }

    return monthlyStats;
  }

  /// Получить статистику по всем годам для ребёнка
  Future<List<Map<String, dynamic>>> getAllYearsStats(int childId) async {
    final allEpisodes = await getEpisodesByChildId(childId);

    if (allEpisodes.isEmpty) return [];

    // Определяем диапазон лет
    final years = allEpisodes.map((e) => e.startDate.year).toSet().toList()..sort();

    final yearlyStats = <Map<String, dynamic>>[];

    for (final year in years) {
      final stats = await getYearlyStatsByChildId(childId, year);
      yearlyStats.add({
        'year': year,
        ...stats,
      });
    }

    return yearlyStats;
  }
}
