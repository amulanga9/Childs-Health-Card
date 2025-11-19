import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode
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
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          // Создание всех таблиц
          await m.createAll();

          // PERFORMANCE: Создание индексов для частых запросов
          await _createIndexes();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // Миграция с версии 1 на 2
          if (from == 1 && to == 2) {
            // Добавляем поле parent_episode_id в Episodes
            await m.addColumn(episodes, episodes.parentEpisodeId);

            // Создаём таблицу QRTokens
            await m.createTable(qRTokens);
          }

          // Миграция с версии 2 на 3
          if (from == 2 && to == 3) {
            // PERFORMANCE: Добавление индексов для оптимизации запросов
            await _createIndexes();
          }

          // Прямая миграция с 1 на 3
          if (from == 1 && to == 3) {
            await m.addColumn(episodes, episodes.parentEpisodeId);
            await m.createTable(qRTokens);
            await _createIndexes();
          }
        },
        beforeOpen: (details) async {
          // Включение внешних ключей в SQLite
          await customStatement('PRAGMA foreign_keys = ON');

          // PRODUCTION SAFETY: Тестовые данные только в debug режиме
          // В production build (release/profile) тестовые данные не вставляются
          if (kDebugMode && details.wasCreated) {
            await _insertTestData();
          }
        },
      );

  /// Вставка тестовых данных (ТОЛЬКО ДЛЯ DEBUG РЕЖИМА)
  ///
  /// PRODUCTION SAFETY: Эта функция вызывается только когда kDebugMode == true
  /// В release/profile builds тестовые данные не вставляются
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

  /// Создание индексов для оптимизации производительности
  ///
  /// PERFORMANCE: Индексы ускоряют часто используемые запросы:
  /// - Фильтрация эпизодов по child_id
  /// - Поиск активных/завершенных эпизодов по status
  /// - Сортировка эпизодов по дате (start_date)
  /// - Фильтрация связанных данных по episode_id
  /// - Поиск по датам (at_datetime)
  /// - Фильтрация процедур по статусу
  /// - Поиск QR токенов по child_id, expires_at, isActive
  Future<void> _createIndexes() async {
    // Episodes: фильтрация по child_id и status, сортировка по start_date
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_episodes_child_id ON episodes(child_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_episodes_status ON episodes(status)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_episodes_start_date ON episodes(start_date DESC)',
    );

    // Prescriptions: фильтрация по episode_id
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_prescriptions_episode_id ON prescriptions(episode_id)',
    );

    // Intakes: фильтрация по prescription_id и at_datetime
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_intakes_prescription_id ON intakes(prescription_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_intakes_at_datetime ON intakes(at_datetime)',
    );

    // Tests: фильтрация по episode_id и at_datetime
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_tests_episode_id ON tests(episode_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_tests_at_datetime ON tests(at_datetime)',
    );

    // Procedures: фильтрация по episode_id, at_datetime, status
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_procedures_episode_id ON procedures(episode_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_procedures_at_datetime ON procedures(at_datetime)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_procedures_status ON procedures(status)',
    );

    // Attachments: фильтрация по episode_id
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_attachments_episode_id ON attachments(episode_id)',
    );

    // QRTokens: фильтрация по child_id, episode_id, expires_at, isActive
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_qr_tokens_child_id ON qr_tokens(child_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_qr_tokens_episode_id ON qr_tokens(episode_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_qr_tokens_expires_at ON qr_tokens(expires_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_qr_tokens_is_active ON qr_tokens(is_active)',
    );

    if (kDebugMode) {
      print('✅ Database indexes created successfully');
    }
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
