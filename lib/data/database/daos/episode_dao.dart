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
}
