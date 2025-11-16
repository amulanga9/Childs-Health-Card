import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables.dart';
import 'daos/child_dao.dart';
import 'daos/episode_dao.dart';
import 'daos/prescription_dao.dart';
import 'daos/intake_dao.dart';
import 'daos/test_dao.dart';
import 'daos/procedure_dao.dart';
import 'daos/attachment_dao.dart';
import 'daos/qr_dao.dart';

part 'database.g.dart';

/// База данных приложения
/// Использует SQLite через Drift ORM
@DriftDatabase(
  tables: [
    Children,
    Episodes,
    Prescriptions,
    Intakes,
    Tests,
    Procedures,
    Attachments,
    QRTokens,
  ],
  daos: [
    ChildDao,
    EpisodeDao,
    PrescriptionDao,
    IntakeDao,
    TestDao,
    ProcedureDao,
    AttachmentDao,
    QrDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          // Создание всех таблиц
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // Миграция с версии 1 на 2
          if (from == 1 && to == 2) {
            // Добавляем поле parent_episode_id в Episodes
            await m.addColumn(episodes, episodes.parentEpisodeId);

            // Создаём таблицу QRTokens
            await m.createTable(qRTokens);
          }
        },
        beforeOpen: (details) async {
          // Включение внешних ключей в SQLite
          await customStatement('PRAGMA foreign_keys = ON');

          // Вставка тестовых данных при первом запуске
          if (details.wasCreated) {
            await _insertTestData();
          }
        },
      );

  /// Вставка тестовых данных
  Future<void> _insertTestData() async {
    // Создаём тестового ребёнка
    final childId = await childDao.createChild(
      ChildrenCompanion.insert(
        name: 'Александр',
        birthDate: DateTime(2020, 3, 15),
        bloodGroup: const Value('A+'),
        allergies: const Value('["Цитрусовые", "Пыльца берёзы"]'),
        chronicConditions: const Value('[]'),
      ),
    );

    // Эпизод 1: ОРВИ
    final orviEpisodeId = await episodeDao.createEpisode(
      EpisodesCompanion.insert(
        childId: childId,
        diagnosis: 'ОРВИ',
        startDate: DateTime(2024, 11, 10),
        endDate: Value(DateTime(2024, 11, 17)),
        status: const Value('recovered'),
        notes: const Value('Высокая температура 38.5°C, насморк, кашель. Лечение на дому.'),
      ),
    );

    // Назначения для ОРВИ
    final paracetamolId = await prescriptionDao.createPrescription(
      PrescriptionsCompanion.insert(
        episodeId: orviEpisodeId,
        drugName: 'Парацетамол',
        dose: '500 мг',
        schedule: '3 раза в день после еды',
        startDate: DateTime(2024, 11, 10),
        endDate: Value(DateTime(2024, 11, 15)),
      ),
    );

    // Приёмы Парацетамола
    await intakeDao.createIntake(
      IntakesCompanion.insert(
        prescriptionId: paracetamolId,
        atDatetime: DateTime(2024, 11, 10, 9, 0),
        taken: const Value(true),
      ),
    );

    await intakeDao.createIntake(
      IntakesCompanion.insert(
        prescriptionId: paracetamolId,
        atDatetime: DateTime(2024, 11, 10, 14, 0),
        taken: const Value(true),
      ),
    );

    await intakeDao.createIntake(
      IntakesCompanion.insert(
        prescriptionId: paracetamolId,
        atDatetime: DateTime(2024, 11, 10, 20, 0),
        taken: const Value(false),
        reasonSkip: const Value('Ребёнок спал'),
      ),
    );

    // Анализ крови для ОРВИ
    await testDao.createTest(
      TestsCompanion.insert(
        episodeId: orviEpisodeId,
        kind: 'Общий анализ крови',
        atDatetime: DateTime(2024, 11, 11, 10, 30),
        resultText: const Value(
          'Лейкоциты: 11.2 (норма 4-9)\nЭритроциты: 4.5\nГемоглобин: 135 г/л\nСОЭ: 15 мм/ч',
        ),
      ),
    );

    // Эпизод 2: Ангина
    final anginaEpisodeId = await episodeDao.createEpisode(
      EpisodesCompanion.insert(
        childId: childId,
        diagnosis: 'Ангина (острый тонзиллит)',
        startDate: DateTime(2024, 9, 5),
        endDate: Value(DateTime(2024, 9, 15)),
        status: const Value('recovered'),
        notes: const Value(
          'Боль в горле, температура 39°C, увеличены миндалины. Назначен антибиотик.',
        ),
      ),
    );

    // Назначения для ангины
    final amoxicillinId = await prescriptionDao.createPrescription(
      PrescriptionsCompanion.insert(
        episodeId: anginaEpisodeId,
        drugName: 'Амоксициллин',
        dose: '250 мг',
        schedule: '2 раза в день',
        startDate: DateTime(2024, 9, 5),
        endDate: Value(DateTime(2024, 9, 12)),
      ),
    );

    await prescriptionDao.createPrescription(
      PrescriptionsCompanion.insert(
        episodeId: anginaEpisodeId,
        drugName: 'Полоскание горла (Мирамистин)',
        dose: '10 мл',
        schedule: '4-5 раз в день',
        startDate: DateTime(2024, 9, 5),
        endDate: Value(DateTime(2024, 9, 15)),
      ),
    );

    // Приёмы антибиотика
    for (int day = 0; day < 7; day++) {
      await intakeDao.createIntake(
        IntakesCompanion.insert(
          prescriptionId: amoxicillinId,
          atDatetime: DateTime(2024, 9, 5 + day, 8, 0),
          taken: const Value(true),
        ),
      );
      await intakeDao.createIntake(
        IntakesCompanion.insert(
          prescriptionId: amoxicillinId,
          atDatetime: DateTime(2024, 9, 5 + day, 20, 0),
          taken: const Value(true),
        ),
      );
    }

    // Мазок из горла
    await testDao.createTest(
      TestsCompanion.insert(
        episodeId: anginaEpisodeId,
        kind: 'Мазок из горла',
        atDatetime: DateTime(2024, 9, 6, 11, 0),
        resultText: const Value(
          'Обнаружен стрептококк группы A. Чувствителен к пенициллинам.',
        ),
      ),
    );

    // Эпизод 3: Бронхит (активный)
    final bronchitisEpisodeId = await episodeDao.createEpisode(
      EpisodesCompanion.insert(
        childId: childId,
        diagnosis: 'Острый бронхит',
        startDate: DateTime(2024, 11, 14),
        status: const Value('active'),
        notes: const Value(
          'Сухой кашель, затруднённое дыхание, температура 37.8°C. Назначена ингаляционная терапия.',
        ),
      ),
    );

    // Назначения для бронхита
    await prescriptionDao.createPrescription(
      PrescriptionsCompanion.insert(
        episodeId: bronchitisEpisodeId,
        drugName: 'Амбробене',
        dose: '15 мг',
        schedule: '3 раза в день',
        startDate: DateTime(2024, 11, 14),
        endDate: Value(DateTime(2024, 11, 21)),
      ),
    );

    await prescriptionDao.createPrescription(
      PrescriptionsCompanion.insert(
        episodeId: bronchitisEpisodeId,
        drugName: 'Ингаляции с физраствором',
        dose: '2 мл',
        schedule: '2 раза в день',
        startDate: DateTime(2024, 11, 14),
        endDate: Value(DateTime(2024, 11, 21)),
      ),
    );

    // Процедура - ингаляция
    await procedureDao.createProcedure(
      ProceduresCompanion.insert(
        episodeId: bronchitisEpisodeId,
        kind: 'Ингаляция',
        atDatetime: DateTime(2024, 11, 15, 10, 0),
        status: const Value('completed'),
        note: const Value('Ингаляция с физраствором, длительность 10 минут'),
      ),
    );

    await procedureDao.createProcedure(
      ProceduresCompanion.insert(
        episodeId: bronchitisEpisodeId,
        kind: 'Ингаляция',
        atDatetime: DateTime(2024, 11, 15, 18, 0),
        status: const Value('scheduled'),
        note: const Value('Вечерняя ингаляция'),
      ),
    );

    // Рентген грудной клетки
    await testDao.createTest(
      TestsCompanion.insert(
        episodeId: bronchitisEpisodeId,
        kind: 'Рентген грудной клетки',
        atDatetime: DateTime(2024, 11, 15, 14, 0),
        resultText: const Value(
          'Усиление лёгочного рисунка в нижних отделах. Признаки бронхита.',
        ),
      ),
    );

    print('✅ Тестовые данные успешно добавлены в базу данных');
  }
}

/// Открытие соединения с базой данных SQLite
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'health_card.db'));
    return NativeDatabase(file);
  });
}
