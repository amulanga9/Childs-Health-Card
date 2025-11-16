import 'package:drift/drift.dart';

/// Таблица детей
/// Хранит основную информацию о детях
class Children extends Table {
  /// Уникальный идентификатор
  IntColumn get id => integer().autoIncrement()();

  /// Имя ребёнка
  TextColumn get name => text().withLength(min: 1, max: 100)();

  /// Дата рождения
  DateTimeColumn get birthDate => dateTime()();

  /// Группа крови (A+, B-, O+, AB- и т.д.)
  TextColumn get bloodGroup => text().withLength(max: 10).nullable()();

  /// Аллергии (JSON массив строк)
  TextColumn get allergies => text().withDefault(const Constant('[]'))();

  /// Хронические заболевания (JSON массив строк)
  TextColumn get chronicConditions => text().withDefault(const Constant('[]'))();

  /// Путь к аватару (локальный файл)
  TextColumn get avatar => text().nullable()();

  /// Дата создания записи
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Дата последнего обновления
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Таблица эпизодов болезни
/// Хранит информацию о заболеваниях ребёнка
/// Поддерживает цепочки эпизодов через parent_episode_id
class Episodes extends Table {
  /// Уникальный идентификатор
  IntColumn get id => integer().autoIncrement()();

  /// Внешний ключ на ребёнка
  IntColumn get childId => integer().references(Children, #id, onDelete: KeyAction.cascade)();

  /// Родительский эпизод (если болезнь переросла в новое заболевание)
  /// Например: ОРВИ → Бронхит → Пневмония
  IntColumn get parentEpisodeId => integer().nullable().references(Episodes, #id, onDelete: KeyAction.setNull)();

  /// Диагноз (название болезни)
  TextColumn get diagnosis => text().withLength(min: 1, max: 200)();

  /// Дата начала болезни
  DateTimeColumn get startDate => dateTime()();

  /// Дата окончания болезни (null = активная болезнь)
  DateTimeColumn get endDate => dateTime().nullable()();

  /// Статус: active, recovered, chronic
  TextColumn get status => text().withDefault(const Constant('active'))();

  /// Заметки и описание
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// Дата создания записи
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Дата последнего обновления
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Таблица назначений лекарств
/// Хранит информацию о назначенных препаратах
class Prescriptions extends Table {
  /// Уникальный идентификатор
  IntColumn get id => integer().autoIncrement()();

  /// Внешний ключ на эпизод болезни
  IntColumn get episodeId => integer().references(Episodes, #id, onDelete: KeyAction.cascade)();

  /// Название препарата
  TextColumn get drugName => text().withLength(min: 1, max: 200)();

  /// Дозировка (например, "500 мг")
  TextColumn get dose => text().withLength(min: 1, max: 100)();

  /// Расписание приёма (например, "3 раза в день", "утром и вечером")
  TextColumn get schedule => text().withLength(min: 1, max: 200)();

  /// Дата начала приёма
  DateTimeColumn get startDate => dateTime()();

  /// Дата окончания приёма (null = длительный приём)
  DateTimeColumn get endDate => dateTime().nullable()();

  /// Дата создания записи
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Дата последнего обновления
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Таблица приёмов лекарств
/// Хранит информацию о фактических приёмах препаратов
class Intakes extends Table {
  /// Уникальный идентификатор
  IntColumn get id => integer().autoIncrement()();

  /// Внешний ключ на назначение
  IntColumn get prescriptionId => integer().references(Prescriptions, #id, onDelete: KeyAction.cascade)();

  /// Дата и время приёма
  DateTimeColumn get atDatetime => dateTime()();

  /// Принято или нет
  BoolColumn get taken => boolean().withDefault(const Constant(false))();

  /// Причина пропуска (если не принято)
  TextColumn get reasonSkip => text().nullable()();

  /// Дата создания записи
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Таблица анализов и тестов
/// Хранит результаты медицинских анализов
class Tests extends Table {
  /// Уникальный идентификатор
  IntColumn get id => integer().autoIncrement()();

  /// Внешний ключ на эпизод болезни
  IntColumn get episodeId => integer().references(Episodes, #id, onDelete: KeyAction.cascade)();

  /// Тип анализа (кровь, моча, рентген и т.д.)
  TextColumn get kind => text().withLength(min: 1, max: 100)();

  /// Дата и время проведения анализа
  DateTimeColumn get atDatetime => dateTime()();

  /// Результаты анализа (текстовое описание)
  TextColumn get resultText => text().withDefault(const Constant(''))();

  /// Внешний ключ на файл результатов (фото, PDF)
  IntColumn get attachmentId => integer().nullable().references(Attachments, #id, onDelete: KeyAction.setNull)();

  /// Дата создания записи
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Таблица медицинских процедур
/// Хранит информацию о процедурах (физиотерапия, операции и т.д.)
class Procedures extends Table {
  /// Уникальный идентификатор
  IntColumn get id => integer().autoIncrement()();

  /// Внешний ключ на эпизод болезни
  IntColumn get episodeId => integer().references(Episodes, #id, onDelete: KeyAction.cascade)();

  /// Тип процедуры (физиотерапия, операция, массаж и т.д.)
  TextColumn get kind => text().withLength(min: 1, max: 100)();

  /// Дата и время процедуры
  DateTimeColumn get atDatetime => dateTime()();

  /// Статус: scheduled, completed, cancelled
  TextColumn get status => text().withDefault(const Constant('scheduled'))();

  /// Заметки и описание
  TextColumn get note => text().withDefault(const Constant(''))();

  /// Дата создания записи
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Таблица вложений
/// Хранит информацию о файлах (фото, документы, результаты анализов)
class Attachments extends Table {
  /// Уникальный идентификатор
  IntColumn get id => integer().autoIncrement()();

  /// Внешний ключ на эпизод болезни
  IntColumn get episodeId => integer().references(Episodes, #id, onDelete: KeyAction.cascade)();

  /// Тип вложения: photo, document, test_result, prescription
  TextColumn get kind => text().withLength(min: 1, max: 50)();

  /// Локальный путь к файлу
  TextColumn get localPath => text()();

  /// Ключ в облачном хранилище (для синхронизации)
  TextColumn get cloudKey => text().nullable()();

  /// Дата и время создания вложения
  DateTimeColumn get atDatetime => dateTime().withDefault(currentDateAndTime)();

  /// Дата создания записи
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Таблица QR-токенов
/// Хранит токены для быстрого доступа к медицинской информации через QR-код
/// Используется для передачи врачам, медперсоналу
class QRTokens extends Table {
  /// Уникальный идентификатор
  IntColumn get id => integer().autoIncrement()();

  /// Внешний ключ на ребёнка
  IntColumn get childId => integer().references(Children, #id, onDelete: KeyAction.cascade)();

  /// Внешний ключ на конкретный эпизод (опционально)
  /// Если null - токен даёт доступ ко всей истории ребёнка
  IntColumn get episodeId => integer().nullable().references(Episodes, #id, onDelete: KeyAction.cascade)();

  /// Уникальный токен (UUID или хеш)
  /// Используется в URL или QR-коде для доступа к данным
  TextColumn get token => text().withLength(min: 16, max: 128).unique()();

  /// Дата и время истечения токена
  /// После этой даты токен становится недействительным
  DateTimeColumn get expiresAt => dateTime()();

  /// Флаг активности токена
  /// false = токен инвалидирован вручную
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// Описание токена (для чего создан)
  /// Например: "Для врача Иванова", "Для детского сада"
  TextColumn get description => text().withDefault(const Constant(''))();

  /// Дата создания записи
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
