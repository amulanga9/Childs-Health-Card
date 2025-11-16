import 'package:drift/drift.dart';
import '../database.dart';
import '../tables.dart';

part 'intake_dao.g.dart';

/// DAO для работы с приёмами лекарств
@DriftAccessor(tables: [Intakes, Prescriptions])
class IntakeDao extends DatabaseAccessor<AppDatabase> with _$IntakeDaoMixin {
  IntakeDao(AppDatabase db) : super(db);

  /// Получить все приёмы
  Future<List<Intake>> getAllIntakes() => select(intakes).get();

  /// Получить приём по ID
  Future<Intake?> getIntakeById(int id) =>
      (select(intakes)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Получить приёмы для назначения
  Future<List<Intake>> getIntakesByPrescriptionId(int prescriptionId) {
    return (select(intakes)
          ..where((t) => t.prescriptionId.equals(prescriptionId))
          ..orderBy([(t) => OrderingTerm(expression: t.atDatetime, mode: OrderingMode.desc)]))
        .get();
  }

  /// Получить приёмы за период
  Future<List<Intake>> getIntakesByDateRange(DateTime startDate, DateTime endDate) {
    return (select(intakes)
          ..where((t) => t.atDatetime.isBetweenValues(startDate, endDate))
          ..orderBy([(t) => OrderingTerm(expression: t.atDatetime, mode: OrderingMode.desc)]))
        .get();
  }

  /// Получить пропущенные приёмы
  Future<List<Intake>> getMissedIntakes() {
    return (select(intakes)
          ..where((t) => t.taken.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.atDatetime, mode: OrderingMode.desc)]))
        .get();
  }

  /// Создать приём
  Future<int> createIntake(IntakesCompanion entry) => into(intakes).insert(entry);

  /// Обновить приём
  Future<bool> updateIntake(Intake intake) => update(intakes).replace(intake);

  /// Удалить приём
  Future<int> deleteIntake(int id) => (delete(intakes)..where((t) => t.id.equals(id))).go();

  /// Отметить приём как принятый
  Future<void> markIntakeAsTaken(int id) {
    return (update(intakes)..where((t) => t.id.equals(id))).write(
      const IntakesCompanion(taken: Value(true), reasonSkip: Value(null)),
    );
  }

  /// Отметить приём как пропущенный
  Future<void> markIntakeAsMissed(int id, String reason) {
    return (update(intakes)..where((t) => t.id.equals(id))).write(
      IntakesCompanion(taken: const Value(false), reasonSkip: Value(reason)),
    );
  }

  /// Статистика приёмов для назначения
  Future<Map<String, int>> getIntakeStatsByPrescriptionId(int prescriptionId) async {
    final allIntakes = await getIntakesByPrescriptionId(prescriptionId);
    final taken = allIntakes.where((i) => i.taken).length;
    final missed = allIntakes.where((i) => !i.taken).length;

    return {'total': allIntakes.length, 'taken': taken, 'missed': missed};
  }

  /// Stream приёмов для назначения
  Stream<List<Intake>> watchIntakesByPrescriptionId(int prescriptionId) {
    return (select(intakes)
          ..where((t) => t.prescriptionId.equals(prescriptionId))
          ..orderBy([(t) => OrderingTerm(expression: t.atDatetime, mode: OrderingMode.desc)]))
        .watch();
  }
}
