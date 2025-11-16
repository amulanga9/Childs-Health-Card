import 'package:drift/drift.dart';
import '../database.dart';
import '../tables.dart';

part 'procedure_dao.g.dart';

/// DAO для работы с процедурами
@DriftAccessor(tables: [Procedures, Episodes])
class ProcedureDao extends DatabaseAccessor<AppDatabase> with _$ProcedureDaoMixin {
  ProcedureDao(AppDatabase db) : super(db);

  /// Получить все процедуры
  Future<List<Procedure>> getAllProcedures() {
    return (select(procedures)
          ..orderBy([(t) => OrderingTerm(expression: t.atDatetime, mode: OrderingMode.desc)]))
        .get();
  }

  /// Получить процедуру по ID
  Future<Procedure?> getProcedureById(int id) =>
      (select(procedures)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Получить процедуры для эпизода
  Future<List<Procedure>> getProceduresByEpisodeId(int episodeId) {
    return (select(procedures)
          ..where((t) => t.episodeId.equals(episodeId))
          ..orderBy([(t) => OrderingTerm(expression: t.atDatetime, mode: OrderingMode.desc)]))
        .get();
  }

  /// Получить процедуры по статусу
  Future<List<Procedure>> getProceduresByStatus(String status) {
    return (select(procedures)
          ..where((t) => t.status.equals(status))
          ..orderBy([(t) => OrderingTerm(expression: t.atDatetime, mode: OrderingMode.desc)]))
        .get();
  }

  /// Получить запланированные процедуры
  Future<List<Procedure>> getScheduledProcedures() {
    return getProceduresByStatus('scheduled');
  }

  /// Получить завершённые процедуры
  Future<List<Procedure>> getCompletedProcedures() {
    return getProceduresByStatus('completed');
  }

  /// Создать процедуру
  Future<int> createProcedure(ProceduresCompanion entry) => into(procedures).insert(entry);

  /// Обновить процедуру
  Future<bool> updateProcedure(Procedure procedure) => update(procedures).replace(procedure);

  /// Удалить процедуру
  Future<int> deleteProcedure(int id) =>
      (delete(procedures)..where((t) => t.id.equals(id))).go();

  /// Отметить процедуру как завершённую
  Future<void> markProcedureAsCompleted(int id) {
    return (update(procedures)..where((t) => t.id.equals(id))).write(
      const ProceduresCompanion(status: Value('completed')),
    );
  }

  /// Отменить процедуру
  Future<void> cancelProcedure(int id) {
    return (update(procedures)..where((t) => t.id.equals(id))).write(
      const ProceduresCompanion(status: Value('cancelled')),
    );
  }

  /// Stream процедур для эпизода
  Stream<List<Procedure>> watchProceduresByEpisodeId(int episodeId) {
    return (select(procedures)
          ..where((t) => t.episodeId.equals(episodeId))
          ..orderBy([(t) => OrderingTerm(expression: t.atDatetime, mode: OrderingMode.desc)]))
        .watch();
  }

  /// Stream запланированных процедур
  Stream<List<Procedure>> watchScheduledProcedures() {
    return (select(procedures)
          ..where((t) => t.status.equals('scheduled'))
          ..orderBy([(t) => OrderingTerm(expression: t.atDatetime)]))
        .watch();
  }
}
