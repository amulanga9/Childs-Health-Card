# 🆕 База данных v2 - Новые возможности

Документ описывает новые возможности добавленные в версию 2 базы данных.

## 📋 Изменения в схеме

### 1. Episodes - Цепочки эпизодов

Добавлено поле **parent_episode_id** для связывания эпизодов болезни.

**Пример использования:**
```
ОРВИ (id: 1, parent_episode_id: null)
  └── Бронхит (id: 2, parent_episode_id: 1)
        └── Пневмония (id: 3, parent_episode_id: 2)
```

**Новое поле:**

| Поле             | Тип       | Описание                                  | Ограничения             |
|------------------|-----------|-------------------------------------------|-------------------------|
| parent_episode_id| INTEGER   | Родительский эпизод (для цепочек)         | NULLABLE, FK→Episodes   |

**Cascade Delete:** `onDelete: KeyAction.setNull` - при удалении родителя, дочерние эпизоды сохраняются, но связь обнуляется.

---

### 2. QRTokens - Новая таблица

Таблица для генерации QR-кодов с доступом к медицинским данным.

| Поле        | Тип       | Описание                                   | Ограничения             |
|-------------|-----------|-------------------------------------------|-------------------------|
| id          | INTEGER   | Уникальный идентификатор                  | PRIMARY KEY, AUTO INC   |
| child_id    | INTEGER   | Внешний ключ на ребёнка                   | NOT NULL, FK→Children   |
| episode_id  | INTEGER   | Конкретный эпизод (опционально)           | NULLABLE, FK→Episodes   |
| token       | TEXT      | Уникальный токен (UUID/хеш)               | NOT NULL, UNIQUE, 16-128|
| expires_at  | DATETIME  | Дата истечения токена                     | NOT NULL                |
| is_active   | BOOLEAN   | Флаг активности                           | DEFAULT true            |
| description | TEXT      | Описание (для чего создан)                | DEFAULT ''              |
| created_at  | DATETIME  | Дата создания                             | DEFAULT CURRENT_TIME    |

**Сценарии использования:**
- Передача данных врачу через QR-код
- Доступ к истории для детского сада
- Временный доступ для консультаций
- Экспорт данных в другие системы

**Cascade Delete:** При удалении ребёнка/эпизода удаляются все связанные токены.

---

## 🔧 Новые методы DAO

### EpisodeDao - Работа с цепочками

#### createEpisodeWithParent()

Создаёт эпизод, связанный с родительским эпизодом.

```dart
final bronchitisId = await db.episodeDao.createEpisodeWithParent(
  childId: childId,
  parentEpisodeId: orviEpisodeId, // ID эпизода ОРВИ
  diagnosis: 'Бронхит',
  startDate: DateTime.now(),
  notes: 'Осложнение после ОРВИ',
);
```

**Проверки:**
- Родительский эпизод должен существовать
- Родительский эпизод должен принадлежать тому же ребёнку

---

#### getEpisodesChain()

Получает всю цепочку эпизодов от корня до указанного.

```dart
final chain = await db.episodeDao.getEpisodesChain(pneumoniaId);
// Результат: [ОРВИ, Бронхит, Пневмония]

for (final episode in chain) {
  print('${episode.diagnosis} (${episode.startDate})');
}
```

**Возвращает:** `List<Episode>` отсортированный от самого раннего к текущему.

---

#### getChildEpisodes()

Получает дочерние эпизоды (те, что переросли из данного).

```dart
final children = await db.episodeDao.getChildEpisodes(orviEpisodeId);
// Результат: [Бронхит]
```

---

#### getRootEpisode()

Получает корневой эпизод цепочки (самый первый).

```dart
final root = await db.episodeDao.getRootEpisode(pneumoniaId);
// Результат: ОРВИ
```

---

#### isPartOfChain()

Проверяет, является ли эпизод частью цепочки.

```dart
final isChained = await db.episodeDao.isPartOfChain(episodeId);
// true - если есть родитель или дети
// false - если standalone эпизод
```

---

### EpisodeDao - Расширенная статистика

#### getYearlyStatsByChildId()

Получает статистику по эпизодам за год.

```dart
final stats = await db.episodeDao.getYearlyStatsByChildId(childId, 2024);

print('Количество эпизодов: ${stats['count']}');
print('Средняя длительность: ${stats['averageDuration']} дней');

final topDiagnoses = stats['topDiagnoses'] as List;
for (final diagnosis in topDiagnoses) {
  print('${diagnosis['diagnosis']}: ${diagnosis['count']} раз');
}
```

**Возвращаемая структура:**
```dart
{
  'count': 12,
  'averageDuration': 7.5,
  'topDiagnoses': [
    {'diagnosis': 'ОРВИ', 'count': 5},
    {'diagnosis': 'Ангина', 'count': 3},
    {'diagnosis': 'Бронхит', 'count': 2},
  ]
}
```

---

#### getMonthlyStatsForYear()

Статистика по месяцам за год.

```dart
final monthlyStats = await db.episodeDao.getMonthlyStatsForYear(childId, 2024);
// Результат: {1: 2, 2: 1, 3: 3, 4: 0, ..., 12: 1}

// Использование для графика
for (int month = 1; month <= 12; month++) {
  print('Месяц $month: ${monthlyStats[month]} эпизодов');
}
```

---

#### getAllYearsStats()

Статистика по всем годам для ребёнка.

```dart
final allYears = await db.episodeDao.getAllYearsStats(childId);

for (final yearStats in allYears) {
  print('Год: ${yearStats['year']}');
  print('Эпизодов: ${yearStats['count']}');
  print('Средняя длительность: ${yearStats['averageDuration']}');
}
```

---

### PrescriptionDao - Утренний список назначений

#### getDailyPrescriptions()

Получает все назначения на конкретный день.

```dart
final prescriptions = await db.prescriptionDao.getDailyPrescriptions(
  childId,
  DateTime(2024, 11, 16),
);

for (final item in prescriptions) {
  print('${item['drugName']} - ${item['dose']}');
  print('Расписание: ${item['schedule']}');
  print('Диагноз: ${item['diagnosis']}');
}
```

**Возвращает:** `List<Map<String, dynamic>>` с полями:
- `prescription`: объект Prescription
- `episode`: объект Episode
- `drugName`: название препарата
- `dose`: дозировка
- `schedule`: расписание приёма
- `diagnosis`: диагноз (из эпизода)

**Логика фильтрации:**
Назначение включается если:
- `startDate <= указанная дата`
- `endDate >= указанная дата` (или `endDate == null`)

---

#### getMorningPrescriptions()

Утренний список назначений на сегодня.

```dart
final morningList = await db.prescriptionDao.getMorningPrescriptions(childId);

// Использование для уведомлений
for (final item in morningList) {
  sendNotification('Принять: ${item['drugName']} ${item['dose']}');
}
```

---

#### getWeeklyPrescriptions()

Назначения на неделю вперёд.

```dart
final weeklyPrescriptions = await db.prescriptionDao.getWeeklyPrescriptions(
  childId,
  DateTime.now(),
);

weeklyPrescriptions.forEach((date, prescriptions) {
  print('${date.day}.${date.month}: ${prescriptions.length} назначений');
});
```

**Возвращает:** `Map<DateTime, List<Map<String, dynamic>>>`

---

### IntakeDao - Расширенная статистика

#### getIntakeStatsByChildId()

Получает статистику приёмов лекарств за период.

```dart
final stats = await db.intakeDao.getIntakeStatsByChildId(
  childId: childId,
  startDate: DateTime(2024, 1, 1),
  endDate: DateTime(2024, 12, 31),
);

print('Всего приёмов: ${stats['total']}');
print('Принято: ${stats['taken']}');
print('Пропущено: ${stats['missed']}');
print('Соблюдение: ${stats['adherence']}%');

final reasons = stats['missedReasons'] as List;
for (final reason in reasons) {
  print('${reason['reason']}: ${reason['count']} раз');
}
```

**Возвращаемая структура:**
```dart
{
  'total': 100,
  'taken': 85,
  'missed': 15,
  'adherence': 85.0,
  'missedReasons': [
    {'reason': 'Ребёнок спал', 'count': 8},
    {'reason': 'Забыли', 'count': 5},
    {'reason': 'Не указано', 'count': 2},
  ]
}
```

---

#### getRecentIntakeStats()

Статистика за последние N дней.

```dart
// За последнюю неделю
final weekStats = await db.intakeDao.getRecentIntakeStats(childId, 7);

// За последний месяц
final monthStats = await db.intakeDao.getRecentIntakeStats(childId, 30);
```

---

#### getCurrentMonthIntakeStats()

Статистика за текущий месяц.

```dart
final monthStats = await db.intakeDao.getCurrentMonthIntakeStats(childId);
```

---

#### getDailyIntakeStats()

Ежедневная статистика за период.

```dart
final dailyStats = await db.intakeDao.getDailyIntakeStats(
  childId: childId,
  startDate: DateTime(2024, 11, 1),
  endDate: DateTime(2024, 11, 30),
);

dailyStats.forEach((date, stats) {
  print('${date.day}.${date.month}: ${stats['taken']}/${stats['total']}');
});
```

**Возвращает:** `Map<DateTime, Map<String, int>>`

---

### QrDao - Управление QR-токенами

#### createToken()

Создаёт новый токен (автоматически генерирует UUID).

```dart
final token = await db.qrDao.createToken(
  childId: childId,
  expiresAt: DateTime.now().add(Duration(days: 7)),
  description: 'Для врача Иванова',
);

print('Токен: ${token.token}');
// Генерация QR-кода с токеном
generateQRCode('https://app.com/view/${token.token}');
```

**Для конкретного эпизода:**
```dart
final token = await db.qrDao.createToken(
  childId: childId,
  episodeId: episodeId, // Доступ только к этому эпизоду
  expiresAt: DateTime.now().add(Duration(hours: 24)),
  description: 'Для скорой помощи',
);
```

---

#### getTokenByValue()

Получает токен по значению (для валидации при сканировании QR).

```dart
final token = await db.qrDao.getTokenByValue(scannedToken);
if (token != null) {
  // Показать данные
  showMedicalData(token.childId, token.episodeId);
}
```

---

#### isTokenValid()

Проверяет валидность токена.

```dart
final isValid = await db.qrDao.isTokenValid(scannedToken);
if (isValid) {
  // Токен действителен
} else {
  // Токен недействителен (не существует, истёк, или инвалидирован)
}
```

**Токен валиден если:**
1. Существует в БД
2. `isActive == true`
3. `expiresAt > текущее время`

---

#### invalidateToken()

Инвалидирует токен (устанавливает `isActive = false`).

```dart
await db.qrDao.invalidateToken(tokenId);
// или
await db.qrDao.invalidateTokenByValue(tokenValue);
```

**Использование:** Когда визит к врачу завершён и доступ больше не нужен.

---

#### getActiveTokensByChildId()

Получает все активные токены для ребёнка.

```dart
final activeTokens = await db.qrDao.getActiveTokensByChildId(childId);

for (final token in activeTokens) {
  print('${token.description}: истекает ${token.expiresAt}');
}
```

---

#### cleanupExpiredTokens()

Удаляет истекшие и неактивные токены (для очистки БД).

```dart
final deletedCount = await db.qrDao.cleanupExpiredTokens();
print('Удалено токенов: $deletedCount');
```

**Рекомендация:** Запускать периодически (раз в неделю/месяц).

---

#### extendToken()

Продлевает срок действия токена.

```dart
await db.qrDao.extendToken(
  tokenId,
  DateTime.now().add(Duration(days: 7)),
);
```

---

## 📊 Обновлённая схема связей

```
Children (1) ──< Episodes (N) ──self-ref→ Episodes (parent)
                    │
                    ├──< Prescriptions (N) ──< Intakes (N)
                    ├──< Tests (N)
                    ├──< Procedures (N)
                    ├──< Attachments (N)
                    └──< QRTokens (N)
                         │
Children (1) ───────────┘
```

## 🔄 Миграция с v1 на v2

Миграция выполняется автоматически при первом запуске после обновления.

**Что происходит:**
1. Добавляется поле `parent_episode_id` в таблицу `Episodes`
2. Создаётся таблица `QRTokens`
3. Существующие данные сохраняются
4. Версия схемы обновляется с 1 на 2

**Код миграции:**
```dart
@override
int get schemaVersion => 2;

@override
MigrationStrategy get migration => MigrationStrategy(
  onUpgrade: (Migrator m, int from, int to) async {
    if (from == 1 && to == 2) {
      await m.addColumn(episodes, episodes.parentEpisodeId);
      await m.createTable(qRTokens);
    }
  },
);
```

## 🎯 Примеры использования

### Пример 1: Цепочка болезней

```dart
// Создаём ОРВИ
final orviId = await db.episodeDao.createEpisode(
  EpisodesCompanion.insert(
    childId: childId,
    diagnosis: 'ОРВИ',
    startDate: DateTime(2024, 11, 1),
  ),
);

// Через 5 дней ОРВИ переросла в бронхит
final bronchitisId = await db.episodeDao.createEpisodeWithParent(
  childId: childId,
  parentEpisodeId: orviId,
  diagnosis: 'Бронхит',
  startDate: DateTime(2024, 11, 6),
  notes: 'Осложнение после ОРВИ',
);

// Получаем цепочку
final chain = await db.episodeDao.getEpisodesChain(bronchitisId);
print('История болезни:');
for (final episode in chain) {
  print('- ${episode.diagnosis} (${episode.startDate})');
}
// Вывод:
// - ОРВИ (2024-11-01)
// - Бронхит (2024-11-06)
```

---

### Пример 2: Утренний список лекарств

```dart
// Получаем утренний список
final morningList = await db.prescriptionDao.getMorningPrescriptions(childId);

// Отображаем в UI
for (final item in morningList) {
  ListTile(
    title: Text('${item['drugName']} - ${item['dose']}'),
    subtitle: Text('${item['schedule']} (${item['diagnosis']})'),
    trailing: Checkbox(
      value: false,
      onChanged: (value) => markAsTaken(item['prescription']),
    ),
  );
}
```

---

### Пример 3: QR-код для врача

```dart
// Создаём токен на 24 часа
final token = await db.qrDao.createToken(
  childId: childId,
  expiresAt: DateTime.now().add(Duration(hours: 24)),
  description: 'Для приёма у педиатра',
);

// Генерируем QR-код
final qrCode = QrImage(
  data: 'https://healthcard.app/view/${token.token}',
);

// После приёма инвалидируем токен
await db.qrDao.invalidateToken(token.id);
```

---

### Пример 4: Годовая статистика

```dart
final stats = await db.episodeDao.getYearlyStatsByChildId(childId, 2024);

// Отображаем на экране статистики
Text('Болел ${stats['count']} раз в этом году');
Text('Средняя продолжительность: ${stats['averageDuration'].toStringAsFixed(1)} дней');

// Топ диагнозов
final topDiagnoses = stats['topDiagnoses'] as List;
ListView.builder(
  itemCount: topDiagnoses.length,
  itemBuilder: (context, index) {
    final diagnosis = topDiagnoses[index];
    return ListTile(
      title: Text(diagnosis['diagnosis']),
      trailing: Text('${diagnosis['count']} раз'),
    );
  },
);
```

---

### Пример 5: Соблюдение режима приёма лекарств

```dart
final stats = await db.intakeDao.getRecentIntakeStats(childId, 30);

// Процент соблюдения
final adherence = stats['adherence'] as double;

CircularProgressIndicator(
  value: adherence / 100,
  backgroundColor: Colors.grey[300],
  valueColor: AlwaysStoppedAnimation<Color>(
    adherence >= 90 ? Colors.green :
    adherence >= 70 ? Colors.orange :
    Colors.red,
  ),
);

Text('${adherence.toStringAsFixed(1)}%');
Text('${stats['taken']} из ${stats['total']} приёмов');

// Причины пропусков
final reasons = stats['missedReasons'] as List;
for (final reason in reasons) {
  Text('${reason['reason']}: ${reason['count']} раз');
}
```

## 📝 Рекомендации

### Цепочки эпизодов
- Используйте для связывания осложнений и перехода одной болезни в другую
- Не злоупотребляйте длинными цепочками (>3 эпизодов) - возможно это разные болезни
- Всегда завершайте (`endDate`) родительский эпизод перед созданием дочернего

### QR-токены
- Устанавливайте разумный срок действия (не более 7 дней для общего доступа)
- Для скорой помощи/экстренных случаев создавайте токены на 24 часа
- Регулярно очищайте истекшие токены (`cleanupExpiredTokens()`)
- Храните описание для понимания кому и зачем выдан токен

### Статистика
- Кешируйте результаты статистики для UI
- Используйте `Stream` для реактивных обновлений
- Для больших периодов (год и более) используйте пагинацию

### Производительность
- Добавьте индексы для часто используемых полей (см. раздел "Индексы" в DATABASE.md)
- Используйте `limit()` для ограничения результатов
- Предпочитайте JOIN вместо множественных запросов
