import 'package:drift/drift.dart';
import '../database.dart';
import '../tables.dart';

part 'test_dao.g.dart';

/// DAO для работы с анализами и тестами
@DriftAccessor(tables: [Tests, Episodes, Attachments])
class TestDao extends DatabaseAccessor<AppDatabase> with _$TestDaoMixin {
  TestDao(AppDatabase db) : super(db);

  /// Получить все тесты
  Future<List<Test>> getAllTests() {
    return (select(tests)
          ..orderBy([(t) => OrderingTerm(expression: t.atDatetime, mode: OrderingMode.desc)]))
        .get();
  }

  /// Получить тест по ID
  Future<Test?> getTestById(int id) =>
      (select(tests)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Получить тесты для эпизода
  Future<List<Test>> getTestsByEpisodeId(int episodeId) {
    return (select(tests)
          ..where((t) => t.episodeId.equals(episodeId))
          ..orderBy([(t) => OrderingTerm(expression: t.atDatetime, mode: OrderingMode.desc)]))
        .get();
  }

  /// Получить тесты по типу
  Future<List<Test>> getTestsByKind(String kind) {
    return (select(tests)
          ..where((t) => t.kind.equals(kind))
          ..orderBy([(t) => OrderingTerm(expression: t.atDatetime, mode: OrderingMode.desc)]))
        .get();
  }

  /// Получить тесты за период
  Future<List<Test>> getTestsByDateRange(DateTime startDate, DateTime endDate) {
    return (select(tests)
          ..where((t) => t.atDatetime.isBetweenValues(startDate, endDate))
          ..orderBy([(t) => OrderingTerm(expression: t.atDatetime, mode: OrderingMode.desc)]))
        .get();
  }

  /// Создать тест
  Future<int> createTest(TestsCompanion entry) => into(tests).insert(entry);

  /// Обновить тест
  Future<bool> updateTest(Test test) => update(tests).replace(test);

  /// Удалить тест
  Future<int> deleteTest(int id) => (delete(tests)..where((t) => t.id.equals(id))).go();

  /// Stream тестов для эпизода
  Stream<List<Test>> watchTestsByEpisodeId(int episodeId) {
    return (select(tests)
          ..where((t) => t.episodeId.equals(episodeId))
          ..orderBy([(t) => OrderingTerm(expression: t.atDatetime, mode: OrderingMode.desc)]))
        .watch();
  }
}
