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

  // ============================================
  // УТРЕННИЙ СПИСОК НАЗНАЧЕНИЙ
  // ============================================

  /// Получить дневные назначения для ребёнка на конкретную дату
  /// Возвращает все активные назначения, которые должны быть приняты в указанный день
  ///
  /// [childId] - ID ребёнка
  /// [date] - дата для которой нужно получить назначения
  ///
  /// Назначение считается активным для даты если:
  /// - startDate <= date
  /// - endDate >= date (или endDate == null)
  Future<List<Map<String, dynamic>>> getDailyPrescriptions(int childId, DateTime date) async {
    // Нормализуем дату до начала дня
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = DateTime(date.year, date.month, date.day, 23, 59, 59);

    // JOIN prescriptions с episodes для фильтрации по childId
    final query = select(prescriptions).join([
      innerJoin(episodes, episodes.id.equalsExp(prescriptions.episodeId)),
    ])
      ..where(
        episodes.childId.equals(childId) &
            prescriptions.startDate.isSmallerOrEqualValue(dayEnd) &
            (prescriptions.endDate.isNull() | prescriptions.endDate.isBiggerOrEqualValue(dayStart)),
      )
      ..orderBy([OrderingTerm(expression: prescriptions.drugName)]);

    final results = await query.get();

    return results.map((row) {
      final prescription = row.readTable(prescriptions);
      final episode = row.readTable(episodes);

      return {
        'prescription': prescription,
        'episode': episode,
        'drugName': prescription.drugName,
        'dose': prescription.dose,
        'schedule': prescription.schedule,
        'diagnosis': episode.diagnosis,
      };
    }).toList();
  }

  /// Получить утренний список назначений (на сегодня)
  Future<List<Map<String, dynamic>>> getMorningPrescriptions(int childId) {
    return getDailyPrescriptions(childId, DateTime.now());
  }

  /// Получить назначения на неделю для ребёнка
  /// Возвращает Map где ключ - дата, значение - список назначений
  Future<Map<DateTime, List<Map<String, dynamic>>>> getWeeklyPrescriptions(
    int childId,
    DateTime startDate,
  ) async {
    final weeklyPrescriptions = <DateTime, List<Map<String, dynamic>>>{};

    for (int i = 0; i < 7; i++) {
      final date = startDate.add(Duration(days: i));
      final dateNormalized = DateTime(date.year, date.month, date.day);
      final prescriptions = await getDailyPrescriptions(childId, date);
      weeklyPrescriptions[dateNormalized] = prescriptions;
    }

    return weeklyPrescriptions;
  }
}
