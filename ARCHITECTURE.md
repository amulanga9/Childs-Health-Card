# 🏗️ Архитектура приложения "Карта Здоровья Ребёнка"

## Общая архитектура

Проект использует **Feature-First + Clean Architecture** подход с разделением на слои:

```
┌─────────────────────────────────────────┐
│         Presentation Layer              │
│  (UI, Screens, Widgets, Providers)      │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│          Business Logic Layer           │
│      (Use Cases, State Management)      │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│            Data Layer                   │
│  (Models, Repositories, DataSources)    │
└─────────────────────────────────────────┘
```

## Слой данных (Data Layer)

### Модели (Models)

Все модели используют **Hive** для локального хранения:

```dart
@HiveType(typeId: 0)
class Child {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  // ... другие поля
}
```

**Важно:** Каждая модель должна иметь уникальный `typeId` для Hive.

### Репозитории (Repositories)

Репозитории инкапсулируют логику работы с данными:

```dart
class ChildRepository {
  final Box<Child> _childBox;

  Future<List<Child>> getAllChildren() async {
    return _childBox.values.toList();
  }

  Future<void> addChild(Child child) async {
    await _childBox.put(child.id, child);
  }

  Future<void> deleteChild(String id) async {
    await _childBox.delete(id);
  }
}
```

### Источники данных (DataSources)

- **LocalDataSource**: Работа с Hive (локальная БД)
- **RemoteDataSource**: API для облачной синхронизации (планируется)

## Слой бизнес-логики

### State Management - Provider

Используется паттерн **ChangeNotifier** через Provider:

```dart
class ChildrenProvider extends ChangeNotifier {
  final ChildRepository _repository;
  List<Child> _children = [];

  List<Child> get children => _children;

  Future<void> loadChildren() async {
    _children = await _repository.getAllChildren();
    notifyListeners();
  }

  Future<void> addChild(Child child) async {
    await _repository.addChild(child);
    await loadChildren();
  }
}
```

### Провайдеры приложения

1. **ChildrenProvider** - Управление профилями детей
2. **IllnessProvider** - Управление болезнями
3. **MedicationProvider** - Управление лекарствами
4. **SettingsProvider** - Настройки приложения
5. **LocalizationProvider** - Переключение языка

## Слой представления (Presentation Layer)

### Экраны (Screens)

Каждый экран - это StatefulWidget или StatelessWidget:

```dart
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<ChildrenProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          // UI код
        );
      },
    );
  }
}
```

### Переиспользуемые виджеты (Widgets)

Общие виджеты выносятся в папку `widgets/`:

- `custom_card.dart` - Кастомная карточка
- `loading_indicator.dart` - Индикатор загрузки
- `empty_state.dart` - Пустое состояние
- `error_widget.dart` - Виджет ошибки

## Навигация (Navigation)

Используется **GoRouter** для декларативной навигации:

```dart
final router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/illness/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return IllnessDetailScreen(illnessId: id);
      },
    ),
  ],
);
```

### Переходы между экранами

```dart
// Прямой переход
context.go('/settings');

// Переход с параметрами
context.push('/illness/${illness.id}');

// Возврат назад
context.pop();
```

## Локализация

### Файлы локализации (.arb)

```json
{
  "@@locale": "ru",
  "appTitle": "Карта здоровья ребёнка",
  "@appTitle": {
    "description": "Название приложения"
  }
}
```

### Использование в коде

```dart
final l10n = AppLocalizations.of(context)!;

Text(l10n.appTitle);
```

### Добавление нового перевода

1. Добавить ключ в `app_en.arb`
2. Добавить переводы в `app_ru.arb` и `app_uz.arb`
3. Запустить генерацию: `flutter gen-l10n`

## Темы (Theming)

### Структура темы

```dart
class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: primaryColor),
    // ... настройки компонентов
  );
}
```

### Использование темы

```dart
Container(
  color: Theme.of(context).colorScheme.primary,
  child: Text(
    'Текст',
    style: Theme.of(context).textTheme.bodyLarge,
  ),
);
```

## База данных (Hive)

### Инициализация

```dart
await Hive.initFlutter();
Hive.registerAdapter(ChildAdapter());
await Hive.openBox<Child>('children');
```

### CRUD операции

```dart
// Create
final box = Hive.box<Child>('children');
await box.put(child.id, child);

// Read
final child = box.get(childId);
final allChildren = box.values.toList();

// Update
final child = box.get(childId);
await box.put(childId, child.copyWith(name: 'Новое имя'));

// Delete
await box.delete(childId);
```

## Связи между сущностями

```
Child (1) ────< (N) Illness
                      │
                      ├──< (N) DoctorVisit
                      ├──< (N) MedicalTest
                      ├──< (N) MedicalProcedure
                      └──< (N) Medication
```

## Потоки данных

### Загрузка данных

```
User Action → Provider → Repository → DataSource → Hive
                ↓
          notifyListeners()
                ↓
           UI Update
```

### Сохранение данных

```
User Input → Provider → Validation → Repository → DataSource → Hive
                                                                  ↓
                                              notifyListeners() ← ┘
                                                      ↓
                                                 UI Update
```

## Обработка ошибок

### Try-Catch в репозиториях

```dart
Future<List<Child>> getAllChildren() async {
  try {
    return _childBox.values.toList();
  } catch (e) {
    throw DatabaseException('Failed to load children: $e');
  }
}
```

### Отображение ошибок в UI

```dart
Consumer<ChildrenProvider>(
  builder: (context, provider, child) {
    if (provider.hasError) {
      return ErrorWidget(error: provider.error);
    }
    if (provider.isLoading) {
      return LoadingIndicator();
    }
    return ChildrenList(children: provider.children);
  },
)
```

## Валидация данных

### Валидация форм

```dart
final _formKey = GlobalKey<FormState>();

TextFormField(
  validator: (value) {
    if (value == null || value.isEmpty) {
      return 'Поле обязательно для заполнения';
    }
    return null;
  },
)

// Проверка формы
if (_formKey.currentState!.validate()) {
  // Сохранить данные
}
```

## Тестирование

### Unit тесты (модели и репозитории)

```dart
test('Child age calculation', () {
  final child = Child(
    id: '1',
    name: 'Test',
    birthDate: DateTime(2020, 1, 1),
    // ...
  );

  expect(child.age, greaterThanOrEqualTo(4));
});
```

### Widget тесты

```dart
testWidgets('HomeScreen displays children', (tester) async {
  await tester.pumpWidget(MyApp());

  expect(find.text('Карта здоровья ребёнка'), findsOneWidget);
});
```

## Лучшие практики

1. **Именование**
   - Классы: PascalCase (`ChildRepository`)
   - Переменные: camelCase (`childRepository`)
   - Константы: lowerCamelCase (`defaultPadding`)
   - Приватные поля: `_privateField`

2. **Структура файлов**
   - Один класс = один файл
   - Имя файла = snake_case (`child_repository.dart`)
   - Приватные виджеты в том же файле с префиксом `_`

3. **Комментарии**
   ```dart
   /// Репозиторий для работы с профилями детей
   ///
   /// Предоставляет методы для CRUD операций
   class ChildRepository {
     // ...
   }
   ```

4. **Использование const**
   ```dart
   const SizedBox(height: 16);
   const Text('Статический текст');
   ```

5. **Null Safety**
   ```dart
   String? nullableValue;
   String nonNullableValue = 'value';
   String value = nullableValue ?? 'default';
   ```

## Производительность

1. **Оптимизация списков**
   ```dart
   ListView.builder(
     itemCount: items.length,
     itemBuilder: (context, index) => ItemWidget(items[index]),
   );
   ```

2. **Ленивая загрузка**
   ```dart
   FutureBuilder(
     future: repository.getData(),
     builder: (context, snapshot) {
       // ...
     },
   );
   ```

3. **Мемоизация**
   ```dart
   class ExpensiveWidget extends StatelessWidget {
     const ExpensiveWidget({super.key});
     // Виджет будет пересобран только при изменении параметров
   }
   ```

## Безопасность

1. **Хранение чувствительных данных**
   ```dart
   final storage = FlutterSecureStorage();
   await storage.write(key: 'pin', value: userPin);
   ```

2. **PIN-код**
   - Хеширование перед сохранением
   - Ограничение попыток ввода
   - Блокировка после неудачных попыток

## Развёртывание

### Android

```bash
flutter build apk --release
flutter build appbundle --release
```

### iOS

```bash
flutter build ios --release
```

## Документация кода

Используйте DartDoc комментарии:

```dart
/// Модель данных ребёнка
///
/// Содержит основную информацию о ребёнке:
/// - Имя
/// - Дату рождения
/// - Пол
///
/// Пример использования:
/// ```dart
/// final child = Child(
///   id: uuid.v4(),
///   name: 'Иван',
///   birthDate: DateTime(2020, 1, 1),
///   gender: Gender.male,
/// );
/// ```
class Child {
  // ...
}
```

## Полезные команды

```bash
# Генерация Hive адаптеров
flutter pub run build_runner build --delete-conflicting-outputs

# Генерация локализации
flutter gen-l10n

# Анализ кода
flutter analyze

# Форматирование кода
dart format .

# Запуск тестов
flutter test

# Очистка кеша
flutter clean
flutter pub get
```
