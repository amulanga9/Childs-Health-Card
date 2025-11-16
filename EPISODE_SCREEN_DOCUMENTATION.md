# Документация экрана эпизода болезни

## Обзор

Экран деталей эпизода (`episode_detail_screen_new.dart`) представляет собой полнофункциональный интерфейс для управления эпизодом болезни ребёнка с интерактивными секциями, анимациями и возможностью отслеживания приёма лекарств в реальном времени.

## Структура экрана

### 1. Шапка (SliverAppBar + Hero)

**Компоненты:**
- Gradient фон (красный для активных, зелёный для закрытых)
- Hero transition с тегом `episode_card_{episodeId}`
- Диагноз в качестве заголовка
- Индикатор статуса ("Активный эпизод" / "Завершён")
- Высота: 200px
- Pinned: true (остаётся при скролле)

**Анимации:**
- Hero transition от карточки эпизода (из списка)
- Gradient animation при открытии

---

### 2. Основная информация

**Расположение:** `lib/presentation/screens/episode_detail_screen_new.dart:298-354`

**Содержимое:**
- Дата начала (dd.MM.yyyy)
- Дата окончания (если эпизод закрыт)
- Длительность в днях (с цветовым акцентом)

**Дизайн:**
- Белая карточка с тенью
- Скругление: 16px
- Иконки слева от каждого поля
- Выравнивание: label слева, value справа

---

### 3. История развития болезни (Цепочка эпизодов)

**Показывается:** Только если цепочка содержит больше 1 эпизода

**Компоненты:**
- Нумерованный список эпизодов (от корня к текущему)
- Стрелки вниз между эпизодами
- Выделение текущего эпизода (primary color)
- Даты начала каждого эпизода

**Пример цепочки:**
```
1. ОРВИ → 15.11.2025
   ↓
2. Бронхит → 18.11.2025
   ↓
3. Пневмония → 22.11.2025 (текущий)
```

**Расположение:** `lib/presentation/screens/episode_detail_screen_new.dart:386-456`

---

### 4. Секция назначений лекарств

**Расположение:** `lib/presentation/widgets/episode_sections/prescriptions_section.dart`

#### 4.1. Карточка назначения

**Компоненты:**
- Иконка лекарства (48x48px, primaryContainer)
- Название препарата (titleMedium, жирный)
- Доза
- Кнопка раскрытия (поворачивается на 180°)

**Состояния:**
- Свёрнута: показывает только основную информацию
- Развёрнута: показывает график приёма на сегодня

#### 4.2. График приёма

**Парсинг расписания:**
```dart
// Формат: "08:00, 14:00, 20:00"
final schedule = prescription.schedule;
final timePattern = RegExp(r'(\d{1,2}):(\d{2})');
```

**Каждая запись содержит:**
- Время приёма (HH:mm)
- Чекбокс "Принял" (зелёный при отметке)
- Кнопка "Пропустил" (оранжевый при отметке)

#### 4.3. Анимированный чекбокс

**Расположение:** `lib/presentation/widgets/animated_check_box.dart`

**Анимации:**
1. **Scale animation** при клике (150мс)
   - From: 1.0
   - To: 0.9
   - Curve: easeInOut

2. **Check appearance** (300мс)
   - Curve: elasticOut
   - Эффект "пружины" при появлении галочки

**Параметры:**
```dart
AnimatedCheckBox(
  value: taken,
  onChanged: (value) { ... },
  activeColor: Colors.green,
  checkColor: Colors.white,
  size: 28,
)
```

#### 4.4. Диалог причины пропуска

**Вызов:** Нажатие на кнопку "Пропустил"

**Содержимое:**
- TextField для ввода причины (3 строки)
- Кнопки: "Отмена" и "Сохранить"

**Сохранение:**
```dart
widget.onMarkIntake(time, false, controller.text);
```

---

### 5. Секция анализов

**Расположение:** `lib/presentation/widgets/episode_sections/tests_section.dart`

#### 5.1. Типы анализов

| Тип         | Иконка        | Цвет   |
|-------------|---------------|--------|
| Кровь/Blood | bloodtype     | red    |
| Моча/Urine  | opacity       | amber  |
| Рентген/XRay| medical_services| blue   |
| Другое      | science       | purple |

#### 5.2. Карточка анализа

**Компоненты:**
- Цветная иконка типа (56x56px)
- Название анализа
- Дата и время (dd.MM.yyyy HH:mm)
- Результат (текст, максимум 2 строки)
- Индикатор прикреплённого файла (если есть)

**Взаимодействие:**
- onTap: открыть детали анализа
- Показывает связанное вложение (attachment)

---

### 6. Секция процедур

**Расположение:** `lib/presentation/widgets/episode_sections/procedures_section.dart`

#### 6.1. Статусы процедур

| Статус       | Цвет   | Текст         |
|--------------|--------|---------------|
| completed    | green  | Выполнена     |
| scheduled    | blue   | Запланирована |
| cancelled    | red    | Отменена      |

#### 6.2. Типы процедур

| Тип          | Иконка     |
|--------------|-----------|
| Укол/Injection| vaccines   |
| Капельница/IV| water_drop |
| Ингаляция    | air        |
| Физиотерапия | accessible |
| Другое       | medical_services |

#### 6.3. Карточка процедуры

**Компоненты:**
- Иконка процедуры (56x56px, фон цвета статуса)
- Название процедуры
- Статус (чип справа сверху)
- Дата и время
- Заметка (если есть, максимум 2 строки)

---

### 7. Секция вложений

**Расположение:** `lib/presentation/widgets/episode_sections/attachments_section.dart`

#### 7.1. Сетка вложений

**Layout:**
- GridView с 3 колонками
- crossAxisSpacing: 8px
- mainAxisSpacing: 8px
- childAspectRatio: 1 (квадратные карточки)

#### 7.2. Карточка вложения

**Типы файлов:**

| Тип         | Иконка           | Цвет  | Превью       |
|-------------|------------------|-------|--------------|
| Photo/Image | image            | blue  | Да (File)    |
| PDF         | picture_as_pdf   | red   | Нет (иконка) |
| Document    | insert_drive_file| grey  | Нет (иконка) |

**Компоненты:**
- Превью изображения (если фото) или иконка типа
- Дата внизу (dd.MM.yy)
- Меню удаления (при long press)

**Взаимодействие:**
1. **Tap:** Открыть файл
2. **Long press:** Показать меню удаления
   - Иконка удаления
   - Иконка закрытия
   - Полупрозрачный чёрный оверлей (opacity: 0.7)

**Анимации:**
- Scale animation при тапе (150мс, 1.0 → 0.95)

#### 7.3. Empty state

**Содержимое:**
- Иконка attach_file (48px)
- Текст "Нет вложений"
- Кнопка "Добавить файл" (если onAddAttachment != null)

---

### 8. Секция заметок

**Компоненты:**
- Заголовок "Заметки"
- Кнопка редактирования (иконка edit)
- Текст заметок в карточке
- Placeholder "Нет заметок" если пусто

**Диалог редактирования:**
- TextField с 5 строками
- Кнопки: "Отмена" и "Сохранить"
- Автосохранение в provider

---

### 9. Кнопки действий (Bottom Bar)

**Расположение:** Внизу экрана, SafeArea

**Для активных эпизодов:**
1. **Закрыть эпизод** (зелёная кнопка)
   - Иконка: check_circle_outline
   - Действие: Подтверждение → closeEpisode()
   - Устанавливает status='closed', endDate=now()

2. **Создать новый эпизод** (оранжевая кнопка)
   - Текст: "Новый"
   - Иконка: add_circle_outline
   - Диалог с полями:
     - Новый диагноз (обязательно)
     - Заметки (опционально)
   - Создаёт дочерний эпизод через createChildEpisode()

3. **Показать QR** (outlined кнопка)
   - Иконка: qr_code
   - Текст: "QR"
   - Показывает диалог с QR-кодом (заглушка)

**Для закрытых эпизодов:**
- Только кнопка "QR"

---

## Provider (State Management)

**Расположение:** `lib/presentation/providers/episode_detail_provider.dart`

### Управляемое состояние:

```dart
class EpisodeDetailProvider {
  Episode? episode;                              // Текущий эпизод
  List<Episode>? episodeChain;                   // Цепочка эпизодов
  List<Prescription> prescriptions;              // Назначения
  Map<int, List<Intake>> intakesByPrescription;  // Приёмы по назначениям
  List<Test> tests;                              // Анализы
  List<Procedure> procedures;                    // Процедуры
  List<Attachment> attachments;                  // Вложения
  bool isLoading;                                // Состояние загрузки
}
```

### Методы:

#### markIntake()
Отметить приём или пропуск лекарства
```dart
Future<void> markIntake({
  required int prescriptionId,
  required DateTime atDatetime,
  required bool taken,
  String? reasonSkip,
})
```

**Логика:**
1. Проверить существующую запись для этого времени
2. Если есть → обновить
3. Если нет → создать новую
4. Перезагрузить intakes
5. Вызвать notifyListeners()

#### closeEpisode()
Закрыть эпизод
```dart
Future<bool> closeEpisode()
```

**Действия:**
- Установить status = 'closed'
- Установить endDate = DateTime.now()
- Обновить в БД
- Вернуть true при успехе

#### createChildEpisode()
Создать дочерний эпизод ("болезнь переросла в...")
```dart
Future<int?> createChildEpisode({
  required String diagnosis,
  required String notes,
})
```

**Использует:** `episodeDao.createEpisodeWithParent()`

**Возвращает:** ID нового эпизода или null

#### updateNotes()
Обновить заметки эпизода
```dart
Future<void> updateNotes(String notes)
```

#### addAttachment()
Добавить вложение
```dart
Future<void> addAttachment({
  required String kind,
  required String localPath,
  String? cloudKey,
})
```

#### deleteAttachment()
Удалить вложение
```dart
Future<void> deleteAttachment(int attachmentId)
```

---

## Анимации

### 1. Hero Transition
**Тег:** `episode_card_{episodeId}`
**Элементы:** От карточки в списке → шапка экрана
**Длительность:** Системная (~300мс)

### 2. Content Animations

**Fade + Slide:**
```dart
_fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
  .animate(CurvedAnimation(parent: controller, curve: Curves.easeIn));

_slideAnimation = Tween<Offset>(begin: Offset(0, 0.3), end: Offset.zero)
  .animate(CurvedAnimation(parent: controller, curve: Curves.easeOut));
```

**Применение:** Весь контент экрана появляется с fade + slide снизу

### 3. Animated CheckBox

**Scale на tap:**
- Duration: 150ms
- Scale: 1.0 → 0.9 → 1.0
- Curve: easeInOut

**Check appearance:**
- Duration: 300ms
- Scale: 0.0 → 1.0
- Curve: elasticOut (эффект пружины)

### 4. Prescription Card Expansion

**Rotation (стрелка):**
- Duration: 300ms
- Turns: 0.0 → 0.5 (180°)
- Curve: easeInOut

**Size transition:**
- Duration: 300ms
- Curve: easeInOut

### 5. Attachment Card Animations

**Scale на tap:**
- Duration: 150ms
- Scale: 1.0 → 0.95 → 1.0
- Curve: easeInOut

---

## Цветовая схема

### Статусы эпизодов:
- **Активный:** `Colors.red.shade600`
- **Закрытый:** `Colors.green.shade600`

### Типы анализов:
- **Кровь:** `Colors.red`
- **Моча:** `Colors.amber`
- **Рентген:** `Colors.blue`
- **Другое:** `Colors.purple`

### Статусы процедур:
- **Выполнена:** `Colors.green`
- **Запланирована:** `Colors.blue`
- **Отменена:** `Colors.red`

### Типы вложений:
- **Фото:** `Colors.blue`
- **PDF:** `Colors.red`
- **Документ:** `Colors.grey`

### Приёмы лекарств:
- **Принял:** `Colors.green`
- **Пропустил:** `Colors.orange`

---

## Диалоги

### 1. Подтверждение закрытия эпизода
**Заголовок:** "Закрыть эпизод?"
**Текст:** "Эпизод будет отмечен как завершённый..."
**Кнопки:** "Отмена" / "Закрыть"

### 2. Создание дочернего эпизода
**Заголовок:** "Болезнь переросла в новое заболевание"
**Поля:**
- Новый диагноз (TextField)
- Заметки (TextField, 3 строки)
**Кнопки:** "Отмена" / "Создать"
**После создания:** Переход на новый эпизод (context.go)

### 3. Редактирование заметок
**Заголовок:** "Редактировать заметки"
**Содержимое:** TextField (5 строк)
**Кнопки:** "Отмена" / "Сохранить"

### 4. Причина пропуска лекарства
**Заголовок:** "Причина пропуска"
**Содержимое:** TextField (3 строки)
**Кнопки:** "Отмена" / "Сохранить"

### 5. Подтверждение удаления
**Заголовок:** Передаётся параметром
**Текст:** "Это действие нельзя отменить."
**Кнопки:** "Отмена" / "Удалить" (красная)

### 6. QR код
**Заголовок:** "QR код эпизода"
**Содержимое:**
- Иконка QR (120px)
- ID эпизода
- Текст "Функция в разработке"
**Кнопка:** "Закрыть"

---

## Empty States

Все секции имеют красивые empty states:

**Дизайн:**
- Светлый фон (surfaceVariant с opacity 0.3)
- Граница (outline с opacity 0.2)
- Иконка (48px)
- Текст
- Кнопка действия (опционально)

**Примеры:**
- "Нет назначений" + иконка medication
- "Нет анализов" + иконка science
- "Нет процедур" + иконка medical_services
- "Нет вложений" + кнопка "Добавить файл"

---

## Взаимодействие с базой данных

### Загрузка данных (при открытии):
1. Episode (episodeDao.getEpisodeById)
2. Episode Chain (episodeDao.getEpisodesChain)
3. Prescriptions (prescriptionDao.getPrescriptionsByEpisodeId)
4. Intakes для каждого prescription (intakeDao.getIntakesByPrescriptionId)
5. Tests (testDao.getTestsByEpisodeId)
6. Procedures (procedureDao.getProceduresByEpisodeId)
7. Attachments (attachmentDao.getAttachmentsByEpisodeId)

### Обновление данных:
- **Real-time:** Отметки приёмов обновляются сразу
- **Optimistic UI:** Чекбоксы меняются до сохранения в БД
- **Error handling:** Ошибки выводятся через debugPrint

---

## Производительность

### Оптимизации:
1. **Lazy loading секций** - показываются только если есть данные
2. **shrinkWrap + NeverScrollableScrollPhysics** для GridView вложений
3. **const конструкторы** где возможно
4. **SingleTickerProviderStateMixin** вместо TickerProviderStateMixin
5. **Dispose контроллеров** анимаций

### Рекомендации:
- Использовать image caching для превью фото
- Добавить pagination для большого количества вложений
- Реализовать виртуальный скролл для длинных списков

---

## TODO (Будущие улучшения)

### Функциональность:
1. ✅ Генерация реальных QR-кодов для врача
2. ✅ Экспорт эпизода в PDF
3. ✅ Загрузка и сжатие изображений для вложений
4. ✅ Облачная синхронизация вложений
5. ✅ Напоминания о приёме лекарств (push notifications)
6. ✅ История изменений эпизода (audit log)
7. ✅ Поиск по заметкам и диагнозам
8. ✅ Фильтрация назначений по статусу (активные/завершённые)

### UI/UX:
1. ✅ Swipe-to-delete для вложений
2. ✅ Drag-and-drop для перестановки секций
3. ✅ Графики приёма лекарств (adherence chart)
4. ✅ Календарный вид для назначений
5. ✅ Темная тема с адаптацией цветов
6. ✅ Accessibility improvements (VoiceOver, TalkBack)

### Техническое:
1. ✅ Unit тесты для Provider
2. ✅ Widget тесты для секций
3. ✅ Integration тесты для workflow
4. ✅ Error boundary для graceful degradation
5. ✅ Offline-first architecture
6. ✅ Optimistic UI updates

---

## Примеры использования

### Открыть экран эпизода:
```dart
context.go('/episode/$episodeId');
// или
context.push('/episode/$episodeId');
```

### Отметить приём лекарства:
```dart
provider.markIntake(
  prescriptionId: 123,
  atDatetime: DateTime(2025, 11, 16, 8, 0),
  taken: true,
  reasonSkip: null,
);
```

### Закрыть эпизод:
```dart
final success = await provider.closeEpisode();
if (success) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Эпизод закрыт')),
  );
}
```

### Создать дочерний эпизод:
```dart
final newId = await provider.createChildEpisode(
  diagnosis: 'Бронхит',
  notes: 'Развилось на фоне ОРВИ',
);
if (newId != null) {
  context.go('/episode/$newId');
}
```

---

## Команды для запуска

```bash
# Генерация Drift кода
flutter pub run build_runner build --delete-conflicting-outputs

# Запуск приложения
flutter run

# Hot reload после изменений
r

# Restart приложения
R
```

---

## Зависимости

```yaml
dependencies:
  provider: ^6.1.1
  go_router: ^13.0.0
  drift: ^2.14.1
  intl: ^0.18.1
```

---

Все компоненты следуют Material Design 3 и адаптированы под российскую локализацию с правильными склонениями и форматами дат.
