import 'package:drift/drift.dart';
import '../database.dart';
import '../tables.dart';

part 'prescription_dao.g.dart';

/// DAO для работы с назначениями лекарств
@DriftAccessor(tables: [Prescriptions, Episodes])
class PrescriptionDao extends DatabaseAccessor<AppDatabase> with _$PrescriptionDaoMixin {
  PrescriptionDao(AppDatabase db) : super(db);

  /// Получить все назначения
  Future<List<Prescription>> getAllPrescriptions() => select(prescriptions).get();

  /// Получить назначение по ID
  Future<Prescription?> getPrescriptionById(int id) =>
      (select(prescriptions)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Получить назначения для эпизода
  Future<List<Prescription>> getPrescriptionsByEpisodeId(int episodeId) {
    return (select(prescriptions)
          ..where((t) => t.episodeId.equals(episodeId))
          ..orderBy([(t) => OrderingTerm(expression: t.startDate, mode: OrderingMode.desc)]))
        .get();
  }

  /// Получить активные назначения (без даты окончания или будущей датой окончания)
  Future<List<Prescription>> getActivePrescriptions() {
    final now = DateTime.now();
    return (select(prescriptions)
          ..where((t) => t.endDate.isNull() | t.endDate.isBiggerThanValue(now))
          ..orderBy([(t) => OrderingTerm(expression: t.startDate, mode: OrderingMode.desc)]))
        .get();
  }

  /// Получить активные назначения для эпизода
  Future<List<Prescription>> getActivePrescriptionsByEpisodeId(int episodeId) {
    final now = DateTime.now();
    return (select(prescriptions)
          ..where((t) =>
              t.episodeId.equals(episodeId) &
              (t.endDate.isNull() | t.endDate.isBiggerThanValue(now)))
          ..orderBy([(t) => OrderingTerm(expression: t.startDate, mode: OrderingMode.desc)]))
        .get();
  }

  /// Создать назначение
  Future<int> createPrescription(PrescriptionsCompanion entry) =>
      into(prescriptions).insert(entry);

  /// Обновить назначение
  Future<bool> updatePrescription(Prescription prescription) =>
      update(prescriptions).replace(prescription);

  /// Удалить назначение
  Future<int> deletePrescription(int id) =>
      (delete(prescriptions)..where((t) => t.id.equals(id))).go();

  /// Stream назначений для эпизода
  Stream<List<Prescription>> watchPrescriptionsByEpisodeId(int episodeId) {
    return (select(prescriptions)
          ..where((t) => t.episodeId.equals(episodeId))
          ..orderBy([(t) => OrderingTerm(expression: t.startDate, mode: OrderingMode.desc)]))
        .watch();
  }

  /// Stream активных назначений
  Stream<List<Prescription>> watchActivePrescriptions() {
    final now = DateTime.now();
    return (select(prescriptions)
          ..where((t) => t.endDate.isNull() | t.endDate.isBiggerThanValue(now))
          ..orderBy([(t) => OrderingTerm(expression: t.startDate, mode: OrderingMode.desc)]))
        .watch();
  }
}
