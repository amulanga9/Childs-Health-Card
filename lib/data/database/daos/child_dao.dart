import 'package:drift/drift.dart';
import '../database.dart';
import '../tables.dart';

part 'child_dao.g.dart';

/// DAO для работы с детьми
/// Предоставляет методы для CRUD операций с профилями детей
@DriftAccessor(tables: [Children])
class ChildDao extends DatabaseAccessor<AppDatabase> with _$ChildDaoMixin {
  ChildDao(AppDatabase db) : super(db);

  /// Получить всех детей
  Future<List<Child>> getAllChildren() {
    return select(children).get();
  }

  /// Получить ребёнка по ID
  Future<Child?> getChildById(int id) {
    return (select(children)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Получить количество детей
  Future<int> getChildrenCount() async {
    final count = countAll();
    final query = selectOnly(children)..addColumns([count]);
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  /// Создать нового ребёнка
  Future<int> createChild(ChildrenCompanion entry) {
    return into(children).insert(entry);
  }

  /// Обновить ребёнка
  Future<bool> updateChild(Child child) {
    return update(children).replace(child);
  }

  /// Удалить ребёнка
  Future<int> deleteChild(int id) {
    return (delete(children)..where((t) => t.id.equals(id))).go();
  }

  /// Поиск детей по имени
  Future<List<Child>> searchChildrenByName(String query) {
    return (select(children)
          ..where((t) => t.name.like('%$query%'))
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .get();
  }

  /// Получить детей с аллергиями
  Future<List<Child>> getChildrenWithAllergies() {
    return (select(children)..where((t) => t.allergies.equals('[]').not()))
        .get();
  }

  /// Получить детей с хроническими заболеваниями
  Future<List<Child>> getChildrenWithChronicConditions() {
    return (select(children)
          ..where((t) => t.chronicConditions.equals('[]').not()))
        .get();
  }

  /// Получить детей по возрастному диапазону
  Future<List<Child>> getChildrenByAgeRange(DateTime minBirthDate, DateTime maxBirthDate) {
    return (select(children)
          ..where((t) => t.birthDate.isBetweenValues(maxBirthDate, minBirthDate))
          ..orderBy([(t) => OrderingTerm(expression: t.birthDate, mode: OrderingMode.desc)]))
        .get();
  }

  /// Stream всех детей (для реактивных обновлений UI)
  Stream<List<Child>> watchAllChildren() {
    return select(children).watch();
  }

  /// Stream ребёнка по ID
  Stream<Child?> watchChildById(int id) {
    return (select(children)..where((t) => t.id.equals(id))).watchSingleOrNull();
  }
}
