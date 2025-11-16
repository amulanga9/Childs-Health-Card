# 🏥 Карта Здоровья Ребёнка (Child's Health Card)

Кроссплатформенное мобильное приложение для учёта здоровья детей на Flutter.

## 📱 Описание

Приложение для ведения медицинской карты ребёнка с возможностью отслеживания:
- 🦠 Болезней и эпизодов заболеваний
- 👨‍⚕️ Визитов к врачу
- 🔬 Анализов и тестов
- 💊 Назначений лекарств
- 🏥 Медицинских процедур
- 📅 Календаря медицинских событий
- 📊 Статистики здоровья

**Особенности:**
- Поддержка до 5 детей
- Локализация: 🇷🇺 Русский, 🇺🇿 Узбекский, 🇬🇧 Английский
- Защита данных PIN-кодом
- Локальное хранение данных (Hive)
- Облачная синхронизация (планируется)

## 🏗️ Архитектура проекта

### Структура папок

```
childs_health_card/
├── lib/
│   ├── core/                          # Ядро приложения
│   │   ├── constants/                 # Константы
│   │   ├── theme/                     # Темы оформления
│   │   │   └── app_theme.dart         # Светлая и тёмная темы
│   │   ├── utils/                     # Утилиты
│   │   └── localization/              # Вспомогательные функции локализации
│   │
│   ├── data/                          # Слой данных
│   │   └── database/                  # База данных Drift
│   │       ├── tables.dart            # Определения таблиц
│   │       ├── database.dart          # Конфигурация БД
│   │       └── daos/                  # Data Access Objects
│   │           ├── child_dao.dart     # DAO для детей
│   │           ├── episode_dao.dart   # DAO для эпизодов
│   │           ├── prescription_dao.dart
│   │           ├── intake_dao.dart
│   │           ├── test_dao.dart
│   │           ├── procedure_dao.dart
│   │           └── attachment_dao.dart
│   │
│   ├── presentation/                  # Слой представления (UI)
│   │   ├── screens/                   # Экраны приложения
│   │   │   ├── home/                  # Главный экран
│   │   │   │   └── home_screen.dart
│   │   │   ├── illness/               # Экран болезни
│   │   │   │   └── illness_detail_screen.dart
│   │   │   ├── settings/              # Экран настроек
│   │   │   │   └── settings_screen.dart
│   │   │   ├── children/              # Управление профилями детей
│   │   │   │   └── child_profile_screen.dart
│   │   │   ├── calendar/              # Календарь событий
│   │   │   │   └── calendar_screen.dart
│   │   │   └── statistics/            # Статистика
│   │   │       └── statistics_screen.dart
│   │   ├── widgets/                   # Переиспользуемые виджеты
│   │   └── providers/                 # State management (Provider)
│   │
│   ├── routes/                        # Навигация
│   │   └── app_router.dart            # Настройка маршрутов (GoRouter)
│   │
│   └── main.dart                      # Точка входа в приложение
│
├── l10n/                              # Локализация
│   ├── app_en.arb                     # Английский
│   ├── app_ru.arb                     # Русский
│   └── app_uz.arb                     # Узбекский
│
├── assets/                            # Ресурсы
│   ├── images/                        # Изображения
│   ├── icons/                         # Иконки
│   └── fonts/                         # Шрифты
│
├── test/                              # Тесты
├── pubspec.yaml                       # Зависимости проекта
├── l10n.yaml                          # Конфигурация локализации
├── analysis_options.yaml              # Настройки линтера
└── README.md                          # Документация
```

## 📊 Модели данных (SQLite + Drift)

Приложение использует **SQLite** с ORM **Drift** для типобезопасного доступа к данным.

### Children (Дети)
```dart
- id: int (PRIMARY KEY)
- name: String (1-100 chars)
- birthDate: DateTime
- bloodGroup: String? (A+, B-, O+, AB- и т.д.)
- allergies: JSON array (список аллергий)
- chronicConditions: JSON array (хронические заболевания)
- avatar: String? (путь к файлу)
```

### Episodes (Эпизоды болезни)
```dart
- id: int (PRIMARY KEY)
- childId: int (FK → Children)
- diagnosis: String (название болезни)
- startDate: DateTime
- endDate: DateTime? (null = активная)
- status: String (active/recovered/chronic)
- notes: String (описание)
```

### Prescriptions (Назначения лекарств)
```dart
- id: int (PRIMARY KEY)
- episodeId: int (FK → Episodes)
- drugName: String (название препарата)
- dose: String (дозировка)
- schedule: String (расписание приёма)
- startDate: DateTime
- endDate: DateTime?
```

### Intakes (Приёмы лекарств)
```dart
- id: int (PRIMARY KEY)
- prescriptionId: int (FK → Prescriptions)
- atDatetime: DateTime (дата и время приёма)
- taken: bool (принято или нет)
- reasonSkip: String? (причина пропуска)
```

### Tests (Анализы)
```dart
- id: int (PRIMARY KEY)
- episodeId: int (FK → Episodes)
- kind: String (тип анализа)
- atDatetime: DateTime
- resultText: String (результаты)
- attachmentId: int? (FK → Attachments)
```

### Procedures (Процедуры)
```dart
- id: int (PRIMARY KEY)
- episodeId: int (FK → Episodes)
- kind: String (тип процедуры)
- atDatetime: DateTime
- status: String (scheduled/completed/cancelled)
- note: String
```

### Attachments (Вложения)
```dart
- id: int (PRIMARY KEY)
- episodeId: int (FK → Episodes)
- kind: String (photo/document/test_result/...)
- localPath: String (путь к файлу)
- cloudKey: String? (ключ в облаке)
- atDatetime: DateTime
```

📚 **Подробная документация:** см. [DATABASE.md](DATABASE.md)

## 🎨 Экраны приложения

### 1. Главный экран (Home Screen)
- Профиль выбранного ребёнка
- Лента активных болезней
- Быстрый доступ к календарю и статистике
- Навигация через нижнюю панель

### 2. Экран болезни (Illness Detail Screen)
- Детальная информация о болезни
- Вкладки:
  - Визиты к врачу
  - Анализы
  - Процедуры
  - Лекарства

### 3. Экран настроек (Settings Screen)
- Управление профилями детей (до 5)
- Выбор языка (RU/UZ/EN)
- Настройка PIN-кода
- Облачная синхронизация
- Резервное копирование

### 4. Календарь (Calendar Screen)
- Интерактивный календарь событий
- События: визиты, процедуры, приём лекарств
- Фильтрация по типу события

### 5. Статистика (Statistics Screen)
- Графики болезней по времени
- Типы болезней (круговая диаграмма)
- Средняя продолжительность болезней
- Общая статистика

### 6. Профиль ребёнка (Child Profile Screen)
- Детальная информация о ребёнке
- Статистика здоровья
- История болезней

## 🛠️ Технологический стек

### Основные зависимости
- **flutter** - Фреймворк для кроссплатформенной разработки
- **provider** ^6.1.1 - State management
- **go_router** ^13.0.0 - Навигация
- **drift** ^2.14.1 - SQLite ORM (типобезопасный)
- **sqlite3_flutter_libs** ^0.5.18 - SQLite библиотеки

### UI компоненты
- **table_calendar** ^3.0.9 - Календарь
- **fl_chart** ^0.66.0 - Графики и диаграммы
- **flutter_svg** ^2.0.9 - SVG иконки
- **cached_network_image** ^3.3.1 - Кеширование изображений

### Утилиты
- **intl** ^0.18.1 - Интернационализация
- **uuid** ^4.3.3 - Генерация ID
- **path_provider** ^2.1.2 - Пути к файлам
- **shared_preferences** ^2.2.2 - Настройки

### Безопасность
- **local_auth** ^2.1.8 - Биометрическая аутентификация
- **flutter_secure_storage** ^9.0.0 - Безопасное хранилище

## 🚀 Установка и запуск

### Требования
- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Android Studio / VS Code
- Android SDK / Xcode

### Шаги установки

1. Клонировать репозиторий:
```bash
git clone https://github.com/yourusername/childs-health-card.git
cd childs-health-card
```

2. Установить зависимости:
```bash
flutter pub get
```

3. Сгенерировать код (для Drift моделей и DAO):
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

4. Сгенерировать локализацию:
```bash
flutter gen-l10n
```

5. Запустить приложение:
```bash
flutter run
```

## 🌐 Локализация

Поддерживаемые языки:
- 🇷🇺 Русский (ru)
- 🇺🇿 Узбекский (uz)
- 🇬🇧 Английский (en)

Файлы локализации находятся в папке `l10n/`:
- `app_en.arb` - Английский
- `app_ru.arb` - Русский
- `app_uz.arb` - Узбекский

## 📝 TODO

- [x] Настроить SQLite + Drift ORM
- [x] Создать таблицы и DAO для всех сущностей
- [x] Добавить тестовые данные (ОРВИ, Ангина, Бронхит)
- [ ] Реализовать Provider для state management
- [ ] Интегрировать DAO с UI экранами
- [ ] Реализовать облачную синхронизацию (Firebase/AWS)
- [ ] Добавить экспорт данных в PDF
- [ ] Реализовать уведомления о приёме лекарств
- [ ] Добавить UI для загрузки вложений (фото, документы)
- [ ] Реализовать поиск по медицинским записям
- [ ] Добавить фильтры и сортировку
- [ ] Написать unit и widget тесты
- [ ] Добавить индексы БД для оптимизации

## 🤝 Участие в разработке

Приветствуются любые предложения и pull request'ы!

1. Fork проекта
2. Создайте feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit изменения (`git commit -m 'Add some AmazingFeature'`)
4. Push в branch (`git push origin feature/AmazingFeature`)
5. Откройте Pull Request

## 📄 Лицензия

MIT License

## 👥 Авторы

Разработано как проект для учёта здоровья детей

## 📧 Контакты

По всем вопросам: [email protected]
