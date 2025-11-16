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
│   │   ├── models/                    # Модели данных
│   │   │   ├── child.dart             # Модель ребёнка
│   │   │   ├── illness.dart           # Модель болезни
│   │   │   ├── doctor_visit.dart      # Модель визита к врачу
│   │   │   ├── medical_test.dart      # Модель анализа
│   │   │   ├── procedure.dart         # Модель процедуры
│   │   │   └── medication.dart        # Модель лекарства
│   │   ├── repositories/              # Репозитории (работа с данными)
│   │   └── datasources/               # Источники данных (Hive, API)
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

## 📊 Модели данных

### Child (Ребёнок)
```dart
- id: String
- name: String
- birthDate: DateTime
- gender: Gender (male/female)
- photoPath: String?
- createdAt: DateTime
- updatedAt: DateTime
```

### Illness (Болезнь)
```dart
- id: String
- childId: String
- title: String
- description: String
- startDate: DateTime
- endDate: DateTime?
- status: IllnessStatus (active/recovered/chronic)
- symptoms: List<String>
```

### DoctorVisit (Визит к врачу)
```dart
- id: String
- illnessId: String
- visitDate: DateTime
- doctorName: String
- specialization: String
- diagnosis: String
- recommendations: String
```

### MedicalTest (Анализ)
```dart
- id: String
- illnessId: String
- testType: String
- testDate: DateTime
- results: Map<String, String>
- laboratory: String?
```

### MedicalProcedure (Процедура)
```dart
- id: String
- illnessId: String
- title: String
- procedureDate: DateTime
- location: String?
- performedBy: String?
```

### Medication (Лекарство)
```dart
- id: String
- illnessId: String
- name: String
- dosage: String
- frequency: String
- startDate: DateTime
- endDate: DateTime?
- isActive: bool
```

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
- **hive** ^2.2.3 - Локальная база данных
- **hive_flutter** ^1.1.0 - Flutter интеграция Hive

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

3. Сгенерировать код (для Hive адаптеров):
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

- [ ] Реализовать Provider для state management
- [ ] Добавить репозитории для работы с данными
- [ ] Настроить Hive адаптеры
- [ ] Реализовать облачную синхронизацию
- [ ] Добавить экспорт данных в PDF
- [ ] Реализовать уведомления о приёме лекарств
- [ ] Добавить поддержку вложений (фото результатов анализов)
- [ ] Реализовать поиск по медицинским записям
- [ ] Добавить фильтры и сортировку
- [ ] Написать unit и widget тесты

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
