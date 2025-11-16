# 🗄️ Структура базы данных

## Технологии

- **SQLite** - локальная реляционная база данных
- **Drift** (v2.14.1) - типобезопасный ORM для Flutter
- **DAO** (Data Access Object) - паттерн для работы с данными

## Схема базы данных

### Диаграмма связей

```
┌─────────────┐
│  Children   │
└──────┬──────┘
       │ 1
       │
       │ N
┌──────▼──────┐      ┌──────────────┐
│  Episodes   ├──────┤ Attachments  │
└──────┬──────┘  N   └──────────────┘
       │
       ├─────────┬─────────┬──────────┐
       │ N       │ N       │ N        │ N
┌──────▼──────┐ │ ┌───────▼────┐ ┌───▼──────┐
│Prescriptions│ │ │   Tests    │ │Procedures│
└──────┬──────┘ │ └────────────┘ └──────────┘
       │ N      │
┌──────▼──────┐ │
│   Intakes   │ │
└─────────────┘ │
                │
```

## Таблицы

### 1. Children (Дети)

Основная таблица профилей детей.

| Поле               | Тип       | Описание                                    | Ограничения            |
|--------------------|-----------|---------------------------------------------|------------------------|
| id                 | INTEGER   | Уникальный идентификатор                    | PRIMARY KEY, AUTO INC  |
| name               | TEXT      | Имя ребёнка                                 | NOT NULL, 1-100 chars  |
| birth_date         | DATETIME  | Дата рождения                               | NOT NULL               |
| blood_group        | TEXT      | Группа крови (A+, B-, O+, AB- и т.д.)       | NULLABLE, max 10 chars |
| allergies          | TEXT      | JSON массив аллергий                        | DEFAULT '[]'           |
| chronic_conditions | TEXT      | JSON массив хронических заболеваний         | DEFAULT '[]'           |
| avatar             | TEXT      | Путь к аватару (локальный)                  | NULLABLE               |
| created_at         | DATETIME  | Дата создания записи                        | DEFAULT CURRENT_TIME   |
| updated_at         | DATETIME  | Дата последнего обновления                  | DEFAULT CURRENT_TIME   |

**Пример JSON:**
```json
{
  "allergies": ["Цитрусовые", "Пыльца берёзы"],
  "chronic_conditions": ["Астма"]
}
```

### 2. Episodes (Эпизоды болезни)

Таблица эпизодов заболеваний.

| Поле       | Тип       | Описание                                  | Ограничения             |
|------------|-----------|-------------------------------------------|-------------------------|
| id         | INTEGER   | Уникальный идентификатор                  | PRIMARY KEY, AUTO INC   |
| child_id   | INTEGER   | Внешний ключ на ребёнка                   | NOT NULL, FK→Children   |
| diagnosis  | TEXT      | Диагноз (название болезни)                | NOT NULL, 1-200 chars   |
| start_date | DATETIME  | Дата начала болезни                       | NOT NULL                |
| end_date   | DATETIME  | Дата окончания (null = активная)          | NULLABLE                |
| status     | TEXT      | Статус: active/recovered/chronic          | DEFAULT 'active'        |
| notes      | TEXT      | Заметки и описание                        | DEFAULT ''              |
| created_at | DATETIME  | Дата создания записи                      | DEFAULT CURRENT_TIME    |
| updated_at | DATETIME  | Дата последнего обновления                | DEFAULT CURRENT_TIME    |

**Статусы:**
- `active` - активная болезнь (в процессе лечения)
- `recovered` - выздоровел
- `chronic` - хроническое заболевание

**Cascade Delete:** При удалении ребёнка удаляются все его эпизоды.

### 3. Prescriptions (Назначения лекарств)

Таблица назначенных препаратов.

| Поле       | Тип       | Описание                                 | Ограничения             |
|------------|-----------|------------------------------------------|-------------------------|
| id         | INTEGER   | Уникальный идентификатор                 | PRIMARY KEY, AUTO INC   |
| episode_id | INTEGER   | Внешний ключ на эпизод                   | NOT NULL, FK→Episodes   |
| drug_name  | TEXT      | Название препарата                       | NOT NULL, 1-200 chars   |
| dose       | TEXT      | Дозировка (например, "500 мг")           | NOT NULL, 1-100 chars   |
| schedule   | TEXT      | Расписание приёма                        | NOT NULL, 1-200 chars   |
| start_date | DATETIME  | Дата начала приёма                       | NOT NULL                |
| end_date   | DATETIME  | Дата окончания (null = длительный)       | NULLABLE                |
| created_at | DATETIME  | Дата создания записи                     | DEFAULT CURRENT_TIME    |
| updated_at | DATETIME  | Дата последнего обновления               | DEFAULT CURRENT_TIME    |

**Примеры расписания:**
- "3 раза в день после еды"
- "Утром и вечером"
- "Каждые 6 часов"

**Cascade Delete:** При удалении эпизода удаляются все назначения.

### 4. Intakes (Приёмы лекарств)

Таблица фактических приёмов препаратов.

| Поле            | Тип       | Описание                              | Ограничения               |
|-----------------|-----------|---------------------------------------|---------------------------|
| id              | INTEGER   | Уникальный идентификатор              | PRIMARY KEY, AUTO INC     |
| prescription_id | INTEGER   | Внешний ключ на назначение            | NOT NULL, FK→Prescriptions|
| at_datetime     | DATETIME  | Дата и время приёма                   | NOT NULL                  |
| taken           | BOOLEAN   | Принято или нет                       | DEFAULT false             |
| reason_skip     | TEXT      | Причина пропуска (если не принято)    | NULLABLE                  |
| created_at      | DATETIME  | Дата создания записи                  | DEFAULT CURRENT_TIME      |

**Cascade Delete:** При удалении назначения удаляются все приёмы.

### 5. Tests (Анализы и тесты)

Таблица результатов медицинских анализов.

| Поле          | Тип       | Описание                               | Ограничения             |
|---------------|-----------|----------------------------------------|-------------------------|
| id            | INTEGER   | Уникальный идентификатор               | PRIMARY KEY, AUTO INC   |
| episode_id    | INTEGER   | Внешний ключ на эпизод                 | NOT NULL, FK→Episodes   |
| kind          | TEXT      | Тип анализа (кровь, моча, рентген)     | NOT NULL, 1-100 chars   |
| at_datetime   | DATETIME  | Дата и время проведения                | NOT NULL                |
| result_text   | TEXT      | Результаты (текстовое описание)        | DEFAULT ''              |
| attachment_id | INTEGER   | Вложение с результатами                | NULLABLE, FK→Attachments|
| created_at    | DATETIME  | Дата создания записи                   | DEFAULT CURRENT_TIME    |

**Типы анализов:**
- Общий анализ крови
- Биохимический анализ крови
- Общий анализ мочи
- Мазок из горла
- Рентген
- УЗИ
- И т.д.

**Cascade Delete:** При удалении эпизода удаляются все тесты.

### 6. Procedures (Медицинские процедуры)

Таблица процедур (физиотерапия, операции и т.д.).

| Поле        | Тип       | Описание                                 | Ограничения             |
|-------------|-----------|------------------------------------------|-------------------------|
| id          | INTEGER   | Уникальный идентификатор                 | PRIMARY KEY, AUTO INC   |
| episode_id  | INTEGER   | Внешний ключ на эпизод                   | NOT NULL, FK→Episodes   |
| kind        | TEXT      | Тип процедуры                            | NOT NULL, 1-100 chars   |
| at_datetime | DATETIME  | Дата и время процедуры                   | NOT NULL                |
| status      | TEXT      | Статус: scheduled/completed/cancelled    | DEFAULT 'scheduled'     |
| note        | TEXT      | Заметки и описание                       | DEFAULT ''              |
| created_at  | DATETIME  | Дата создания записи                     | DEFAULT CURRENT_TIME    |

**Статусы:**
- `scheduled` - запланирована
- `completed` - завершена
- `cancelled` - отменена

**Типы процедур:**
- Физиотерапия
- Ингаляция
- Массаж
- Операция
- Прививка
- И т.д.

**Cascade Delete:** При удалении эпизода удаляются все процедуры.

### 7. Attachments (Вложения)

Таблица вложений (фото, документы, результаты).

| Поле        | Тип       | Описание                                   | Ограничения             |
|-------------|-----------|-------------------------------------------|-------------------------|
| id          | INTEGER   | Уникальный идентификатор                  | PRIMARY KEY, AUTO INC   |
| episode_id  | INTEGER   | Внешний ключ на эпизод                    | NOT NULL, FK→Episodes   |
| kind        | TEXT      | Тип: photo/document/test_result/...       | NOT NULL, 1-50 chars    |
| local_path  | TEXT      | Локальный путь к файлу                    | NOT NULL                |
| cloud_key   | TEXT      | Ключ в облаке (для синхронизации)         | NULLABLE                |
| at_datetime | DATETIME  | Дата и время создания                     | DEFAULT CURRENT_TIME    |
| created_at  | DATETIME  | Дата создания записи                      | DEFAULT CURRENT_TIME    |

**Типы вложений:**
- `photo` - фотография
- `document` - документ (PDF, DOC)
- `test_result` - результат анализа
- `prescription` - рецепт
- `other` - другое

**Cascade Delete:** При удалении эпизода удаляются все вложения.

## DAO (Data Access Objects)

### ChildDao

**Основные методы:**
- `getAllChildren()` - получить всех детей
- `getChildById(int id)` - получить ребёнка по ID
- `createChild(ChildrenCompanion)` - создать ребёнка
- `updateChild(Child)` - обновить ребёнка
- `deleteChild(int id)` - удалить ребёнка
- `searchChildrenByName(String)` - поиск по имени
- `getChildrenWithAllergies()` - дети с аллергиями
- `watchAllChildren()` - Stream всех детей (reactive)

### EpisodeDao

**Основные методы:**
- `getAllEpisodes()` - все эпизоды
- `getEpisodesByChildId(int)` - эпизоды ребёнка
- `getActiveEpisodes()` - активные эпизоды
- `createEpisode(EpisodesCompanion)` - создать эпизод
- `completeEpisode(int id, DateTime)` - завершить эпизод
- `getEpisodeStatsByChildId(int)` - статистика по ребёнку
- `watchEpisodesByChildId(int)` - Stream эпизодов ребёнка

### PrescriptionDao

**Основные методы:**
- `getPrescriptionsByEpisodeId(int)` - назначения для эпизода
- `getActivePrescriptions()` - активные назначения
- `createPrescription(PrescriptionsCompanion)` - создать назначение
- `watchPrescriptionsByEpisodeId(int)` - Stream назначений

### IntakeDao

**Основные методы:**
- `getIntakesByPrescriptionId(int)` - приёмы для назначения
- `getMissedIntakes()` - пропущенные приёмы
- `markIntakeAsTaken(int)` - отметить как принятый
- `markIntakeAsMissed(int, String)` - отметить как пропущенный
- `getIntakeStatsByPrescriptionId(int)` - статистика приёмов

### TestDao

**Основные методы:**
- `getTestsByEpisodeId(int)` - тесты для эпизода
- `getTestsByKind(String)` - тесты по типу
- `createTest(TestsCompanion)` - создать тест
- `watchTestsByEpisodeId(int)` - Stream тестов

### ProcedureDao

**Основные методы:**
- `getProceduresByEpisodeId(int)` - процедуры для эпизода
- `getScheduledProcedures()` - запланированные процедуры
- `markProcedureAsCompleted(int)` - отметить как завершённую
- `cancelProcedure(int)` - отменить процедуру
- `watchScheduledProcedures()` - Stream запланированных

### AttachmentDao

**Основные методы:**
- `getAttachmentsByEpisodeId(int)` - вложения для эпизода
- `getAttachmentsByKind(String)` - вложения по типу
- `getUnsyncedAttachments()` - несинхронизированные
- `setCloudKey(int, String)` - установить облачный ключ
- `createAttachment(AttachmentsCompanion)` - создать вложение

## Миграции

### Версия 1 (текущая)

Начальная схема базы данных с 7 таблицами.

### Будущие миграции

Пример миграции для версии 2:

```dart
@override
MigrationStrategy get migration => MigrationStrategy(
  onUpgrade: (Migrator m, int from, int to) async {
    if (from == 1 && to == 2) {
      // Добавить новую колонку
      await m.addColumn(children, children.gender);
    }
  },
);
```

## Тестовые данные

При первом запуске приложения автоматически создаются тестовые данные:

### Ребёнок
- **Имя:** Александр
- **Дата рождения:** 15.03.2020
- **Группа крови:** A+
- **Аллергии:** Цитрусовые, Пыльца берёзы

### Эпизод 1: ОРВИ
- **Период:** 10.11.2024 - 17.11.2024
- **Статус:** recovered
- **Назначения:**
  - Парацетамол 500 мг (3 раза в день)
  - 3 приёма записаны (2 принятых, 1 пропущен)
- **Анализы:**
  - Общий анализ крови

### Эпизод 2: Ангина
- **Период:** 05.09.2024 - 15.09.2024
- **Статус:** recovered
- **Назначения:**
  - Амоксициллин 250 мг (14 приёмов)
  - Полоскание Мирамистином
- **Анализы:**
  - Мазок из горла

### Эпизод 3: Острый бронхит (активный)
- **Период:** с 14.11.2024
- **Статус:** active
- **Назначения:**
  - Амбробене
  - Ингаляции с физраствором
- **Процедуры:**
  - Ингаляция (завершена)
  - Ингаляция (запланирована)
- **Анализы:**
  - Рентген грудной клетки

## Команды для работы с базой данных

### Генерация кода Drift

```bash
# Генерация моделей и DAO
flutter pub run build_runner build --delete-conflicting-outputs

# Генерация в режиме watch (автоматическая пересборка)
flutter pub run build_runner watch
```

### Очистка сгенерированных файлов

```bash
flutter pub run build_runner clean
```

## Примеры использования

### Создание ребёнка

```dart
final db = AppDatabase();

final childId = await db.childDao.createChild(
  ChildrenCompanion.insert(
    name: 'Мария',
    birthDate: DateTime(2021, 5, 10),
    bloodGroup: Value('O+'),
    allergies: Value('["Молоко"]'),
  ),
);
```

### Создание эпизода болезни

```dart
final episodeId = await db.episodeDao.createEpisode(
  EpisodesCompanion.insert(
    childId: childId,
    diagnosis: 'Ветряная оспа',
    startDate: DateTime.now(),
    notes: Value('Высыпания на коже, температура 38°C'),
  ),
);
```

### Получение активных эпизодов

```dart
final activeEpisodes = await db.episodeDao.getActiveEpisodes();
for (final episode in activeEpisodes) {
  print('${episode.diagnosis} - ${episode.startDate}');
}
```

### Reactive обновления (Stream)

```dart
// В UI (например, StreamBuilder)
StreamBuilder<List<Child>>(
  stream: db.childDao.watchAllChildren(),
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      final children = snapshot.data!;
      return ListView.builder(
        itemCount: children.length,
        itemBuilder: (context, index) {
          return ListTile(title: Text(children[index].name));
        },
      );
    }
    return CircularProgressIndicator();
  },
);
```

## Безопасность

### Внешние ключи

Все внешние ключи настроены с `PRAGMA foreign_keys = ON` для обеспечения целостности данных.

### Cascade Delete

При удалении родительской записи автоматически удаляются все зависимые записи:
- Ребёнок → Эпизоды → Назначения/Тесты/Процедуры/Вложения
- Назначения → Приёмы

### Типобезопасность

Drift обеспечивает типобезопасность на уровне компиляции:
- Все SQL запросы проверяются во время компиляции
- Невозможно вставить некорректные типы данных
- Автоматическая генерация типизированных моделей

## Производительность

### Индексы

Рекомендуется добавить индексы для часто используемых запросов:

```dart
@override
MigrationStrategy get migration => MigrationStrategy(
  onCreate: (Migrator m) async {
    await m.createAll();

    // Индексы для улучшения производительности
    await customStatement(
      'CREATE INDEX idx_episodes_child_id ON episodes(child_id)'
    );
    await customStatement(
      'CREATE INDEX idx_episodes_status ON episodes(status)'
    );
  },
);
```

### Оптимизация запросов

- Используйте `limit()` для ограничения результатов
- Используйте `where()` для фильтрации на уровне БД
- Используйте `orderBy()` для сортировки на уровне БД
- Избегайте загрузки больших объёмов данных в память

## Резервное копирование

Файл базы данных: `health_card.db`

Расположение:
- Android: `/data/data/com.yourapp.childs_health_card/app_flutter/health_card.db`
- iOS: `Documents/health_card.db`

### Создание резервной копии

```dart
final dbFile = File(p.join(
  (await getApplicationDocumentsDirectory()).path,
  'health_card.db',
));

final backup = File('/path/to/backup/health_card_backup.db');
await dbFile.copy(backup.path);
```

## Облачная синхронизация

Поле `cloud_key` в таблице Attachments предназначено для хранения ключа файла в облачном хранилище (Firebase Storage, AWS S3 и т.д.).

Логика синхронизации:
1. Файл сохраняется локально (`local_path`)
2. Файл загружается в облако
3. Ключ облака сохраняется в `cloud_key`
4. Метод `getUnsyncedAttachments()` возвращает файлы без `cloud_key`
