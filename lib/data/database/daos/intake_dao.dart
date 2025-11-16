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

  // ============================================
  // РАСШИРЕННАЯ СТАТИСТИКА ПО ПРИЁМАМ
  // ============================================

  /// Получить статистику приёмов для ребёнка за период
  ///
  /// Возвращает:
  /// - total: всего приёмов
  /// - taken: принято
  /// - missed: пропущено
  /// - adherence: процент соблюдения (0-100)
  /// - missedReasons: причины пропусков с количеством
  Future<Map<String, dynamic>> getIntakeStatsByChildId({
    required int childId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // Используем текущую дату если не указано
    final start = startDate ?? DateTime(2000, 1, 1);
    final end = endDate ?? DateTime.now();

    // JOIN intakes -> prescriptions -> episodes для фильтрации по childId
    final query = select(intakes).join([
      innerJoin(prescriptions, prescriptions.id.equalsExp(intakes.prescriptionId)),
      innerJoin(episodes, episodes.id.equalsExp(prescriptions.episodeId)),
    ])
      ..where(
        episodes.childId.equals(childId) &
            intakes.atDatetime.isBetweenValues(start, end),
      );

    final results = await query.get();
    final allIntakes = results.map((row) => row.readTable(intakes)).toList();

    if (allIntakes.isEmpty) {
      return {
        'total': 0,
        'taken': 0,
        'missed': 0,
        'adherence': 0.0,
        'missedReasons': <Map<String, dynamic>>[],
      };
    }

    final taken = allIntakes.where((i) => i.taken).length;
    final missed = allIntakes.where((i) => !i.taken).length;
    final adherence = (taken / allIntakes.length * 100).toDouble();

    // Анализ причин пропусков
    final missedReasons = <String, int>{};
    for (final intake in allIntakes.where((i) => !i.taken)) {
      final reason = intake.reasonSkip ?? 'Не указано';
      missedReasons[reason] = (missedReasons[reason] ?? 0) + 1;
    }

    final missedReasonsList = missedReasons.entries
        .map((e) => {'reason': e.key, 'count': e.value})
        .toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    return {
      'total': allIntakes.length,
      'taken': taken,
      'missed': missed,
      'adherence': adherence,
      'missedReasons': missedReasonsList,
    };
  }

  /// Получить статистику за последние N дней
  Future<Map<String, dynamic>> getRecentIntakeStats(int childId, int days) {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));
    return getIntakeStatsByChildId(
      childId: childId,
      startDate: startDate,
      endDate: now,
    );
  }

  /// Получить статистику за текущий месяц
  Future<Map<String, dynamic>> getCurrentMonthIntakeStats(int childId) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    return getIntakeStatsByChildId(
      childId: childId,
      startDate: startOfMonth,
      endDate: endOfMonth,
    );
  }

  /// Получить ежедневную статистику за период
  /// Возвращает Map где ключ - дата, значение - статистика за день
  Future<Map<DateTime, Map<String, int>>> getDailyIntakeStats({
    required int childId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final query = select(intakes).join([
      innerJoin(prescriptions, prescriptions.id.equalsExp(intakes.prescriptionId)),
      innerJoin(episodes, episodes.id.equalsExp(prescriptions.episodeId)),
    ])
      ..where(
        episodes.childId.equals(childId) &
            intakes.atDatetime.isBetweenValues(startDate, endDate),
      );

    final results = await query.get();
    final allIntakes = results.map((row) => row.readTable(intakes)).toList();

    final dailyStats = <DateTime, Map<String, int>>{};

    for (final intake in allIntakes) {
      final date = DateTime(
        intake.atDatetime.year,
        intake.atDatetime.month,
        intake.atDatetime.day,
      );

      if (!dailyStats.containsKey(date)) {
        dailyStats[date] = {'total': 0, 'taken': 0, 'missed': 0};
      }

      dailyStats[date]!['total'] = (dailyStats[date]!['total'] ?? 0) + 1;
      if (intake.taken) {
        dailyStats[date]!['taken'] = (dailyStats[date]!['taken'] ?? 0) + 1;
      } else {
        dailyStats[date]!['missed'] = (dailyStats[date]!['missed'] ?? 0) + 1;
      }
    }

    return dailyStats;
  }
}
