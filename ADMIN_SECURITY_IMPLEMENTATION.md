# Admin Panel Security Implementation Guide

Полное руководство по реализации улучшенной безопасности админ-панели с ролями, 2FA и rate limiting.

## Обзор изменений

Данная реализация добавляет следующие функции безопасности:

✅ **Система ролей**: Admin, Moderator, Viewer
✅ **Rate Limiting**: Защита от брутфорса (5 попыток / 15 мин)
✅ **2FA (TOTP)**: Двухфакторная аутентификация
✅ **Логи безопасности**: Детальный аудит всех действий
✅ **UI/UX**: Отображение ролей, блокировка недоступных действий

---

## 1. Новые файлы

### 1.1. `lib/data/models/admin_role.dart`

Роли и права доступа:

```dart
enum AdminRole {
  admin,      // Полный доступ
  moderator,  // Просмотр + ограниченный CRUD
  viewer,     // Только просмотр
}

class AdminPermissions {
  // Права на основе роли
  bool get canDeleteChild => role == AdminRole.admin;
  bool get canExport => role == AdminRole.admin || role == AdminRole.moderator;
  // ... другие права
}
```

**Права по ролям:**

| Действие | Admin | Moderator | Viewer |
|----------|-------|-----------|--------|
| Просмотр данных | ✅ | ✅ | ✅ |
| Создание/Редактирование | ✅ | ✅ | ❌ |
| Удаление | ✅ | ❌ | ❌ |
| Экспорт данных | ✅ | ✅ | ❌ |
| Управление 2FA | ✅ | ❌ | ❌ |
| Смена ролей | ✅ | ❌ | ❌ |

### 1.2. `lib/data/models/two_factor_auth.dart`

2FA и rate limiting:

```dart
class TwoFactorAuth {
  final String secretKey;
  final bool isEnabled;
  final List<String> backupCodes;

  bool verifyCode(String code);  // Проверка TOTP или резервного кода
  String getCurrentCode();        // Текущий TOTP код
}

class RateLimiter {
  static const int maxAttempts = 5;
  static const Duration lockoutDuration = Duration(minutes: 15);

  bool get isLockedOut;
  int get remainingAttempts;
  RateLimiter recordFailedAttempt();
}
```

---

## 2. Обновленные providers

### 2.1. `AdminAuthProvider`

**Новые методы:**

```dart
// Роли
Future<void> setRole(AdminRole newRole);
AdminRole getRole();
bool get isAdmin;
bool get isModerator;
bool get isViewer;
AdminPermissions get permissions;

// 2FA
Future<TwoFactorAuth> enable2FA();
Future<void> disable2FA();
Future<String> get2FASecretKey();
List<String> get2FABackupCodes();
Future<List<String>> regenerate2FABackupCodes();

// Rate Limiting
bool get isLockedOut;
int get remainingAttempts;
Duration? get remainingLockoutTime;
Future<void> resetRateLimiter();

// Улучшенный login
Future<LoginResult> login(String password, {String? twoFactorCode});
```

**LoginResult enum:**

```dart
enum LoginResult {
  success,        // Успешный вход
  wrongPassword,  // Неверный пароль
  need2FA,        // Требуется 2FA код
  wrong2FA,       // Неверный 2FA код
  lockedOut,      // Заблокирован
  error,          // Ошибка
}
```

### 2.2. `AdminLogsProvider`

**Новые методы для безопасности:**

```dart
// Логи безопасности
Future<void> addFailedLoginLog(String adminName, {String? reason});
Future<void> addLockoutLog(String adminName, Duration lockoutDuration);
Future<void> addEnable2FALog(String adminName);
Future<void> addDisable2FALog(String adminName);
Future<void> addChangeRoleLog(String adminName, String oldRole, String newRole);
Future<void> addChangePasswordLog(String adminName);
Future<void> addResetPasswordLog(String adminName);
Future<void> addBackupCodeUsedLog(String adminName);

// Фильтры
List<ActivityLog> getSecurityLogs();
List<ActivityLog> getFailedLoginLogs({int days = 7});
bool hasSuspiciousActivity({int threshold = 10, int hours = 24});

// Экспорт
String exportSecurityLogsToJson();
String exportSecurityLogsToCsv();
```

### 2.3. `AdminProvider`

**Добавить проверку прав перед CRUD:**

```dart
Future<void> deleteChildWithAllData(int childId) async {
  // Проверка прав
  final authProvider = context.read<AdminAuthProvider>();
  if (!authProvider.permissions.canDeleteChild) {
    throw PermissionDeniedException('Недостаточно прав для удаления');
  }

  // ... существующая логика
}
```

Аналогично для всех методов delete, create, update.

---

## 3. Обновление UI компонентов

### 3.1. `admin_login_screen.dart`

**Ключевые изменения:**

```dart
class _AdminLoginScreenState extends State<AdminLoginScreen> {
  bool _need2FA = false;  // Флаг для показа поля 2FA
  final _twoFactorController = TextEditingController();

  Future<void> _handleLogin() async {
    final adminAuth = context.read<AdminAuthProvider>();

    // Проверка блокировки
    if (adminAuth.isLockedOut) {
      // Показать сообщение о блокировке
      return;
    }

    // Попытка входа
    final result = await adminAuth.login(
      _passwordController.text,
      twoFactorCode: _need2FA ? _twoFactorController.text : null,
    );

    switch (result) {
      case LoginResult.success:
        // Успешный вход - переход в админку
        break;
      case LoginResult.need2FA:
        setState(() => _need2FA = true);
        break;
      case LoginResult.wrongPassword:
      case LoginResult.wrong2FA:
        // Показать ошибку + оставшиеся попытки
        await adminLogs.addFailedLoginLog(...);
        break;
      case LoginResult.lockedOut:
        // Показать блокировку
        await adminLogs.addLockoutLog(...);
        break;
    }
  }
}
```

**UI элементы:**

1. Информация о блокировке с таймером
2. Поле для 2FA кода (показывается после ввода пароля)
3. Счетчик оставшихся попыток
4. Информация о резервных кодах

### 3.2. `admin_dashboard_screen.dart`

**Добавить бейдж роли:**

```dart
Widget _buildWelcomeCard(AdminAuthProvider adminAuth) {
  return Card(
    child: Row(
      children: [
        CircleAvatar(...),
        Column(
          children: [
            Text('Добро пожаловать, ${adminAuth.adminName}!'),
            // Бейдж роли
            Chip(
              avatar: Icon(_getRoleIcon(adminAuth.role)),
              label: Text(adminAuth.role.displayName),
              backgroundColor: _getRoleColor(adminAuth.role),
            ),
          ],
        ),
      ],
    ),
  );
}

Color _getRoleColor(AdminRole role) {
  switch (role) {
    case AdminRole.admin:
      return Colors.red.shade100;
    case AdminRole.moderator:
      return Colors.orange.shade100;
    case AdminRole.viewer:
      return Colors.blue.shade100;
  }
}
```

### 3.3. `admin_drawer.dart`

**Скрыть недоступные пункты:**

```dart
Widget build(BuildContext context) {
  final adminAuth = context.watch<AdminAuthProvider>();
  final permissions = adminAuth.permissions;

  return Drawer(
    child: ListView(
      children: [
        DrawerHeader(
          child: Column(
            children: [
              Text(adminAuth.adminName),
              // Бейдж роли
              Chip(label: Text(adminAuth.role.displayName)),
            ],
          ),
        ),

        // Показываем только доступные пункты
        if (permissions.canView)
          ListTile(title: Text('Дети'), ...),

        if (permissions.canManageUsers)
          ListTile(title: Text('Пользователи'), ...),

        if (permissions.canManage2FA)
          ListTile(title: Text('Настройки'), ...),
      ],
    ),
  );
}
```

### 3.4. `admin_settings_screen.dart`

**Добавить управление 2FA и ролями:**

```dart
Widget _build2FASection() {
  return Card(
    child: Column(
      children: [
        SwitchListTile(
          title: Text('Двухфакторная аутентификация'),
          subtitle: Text(adminAuth.is2FAEnabled ? 'Включена' : 'Выключена'),
          value: adminAuth.is2FAEnabled,
          onChanged: (value) async {
            if (value) {
              await _enable2FA();
            } else {
              await _disable2FA();
            }
          },
        ),

        if (adminAuth.is2FAEnabled) ...[
          ListTile(
            title: Text('Резервные коды'),
            subtitle: Text('${adminAuth.get2FABackupCodes().length} кодов'),
            trailing: ElevatedButton(
              onPressed: _regenerateBackupCodes,
              child: Text('Регенерировать'),
            ),
          ),
        ],
      ],
    ),
  );
}

Future<void> _enable2FA() async {
  final twoFactorAuth = await adminAuth.enable2FA();

  // Показать диалог с секретным ключом и QR кодом
  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Настройка 2FA'),
      content: Column(
        children: [
          Text('Отсканируйте QR код или введите ключ вручную:'),
          Text(twoFactorAuth.secretKey),
          // QR код (можно использовать qr_flutter пакет)
          Text('Резервные коды:'),
          ...twoFactorAuth.backupCodes.map((code) => Text(code)),
        ],
      ),
    ),
  );

  await adminLogs.addEnable2FALog(adminAuth.adminName);
}

Widget _buildRoleSection() {
  // Только для Admin
  if (!adminAuth.permissions.canManageRoles) {
    return SizedBox.shrink();
  }

  return Card(
    child: Column(
      children: [
        ListTile(title: Text('Роль администратора')),
        ...AdminRole.values.map((role) => RadioListTile<AdminRole>(
          title: Text(role.displayName),
          subtitle: Text(AdminPermissions(role).roleDescription),
          value: role,
          groupValue: adminAuth.role,
          onChanged: (value) async {
            if (value != null) {
              final oldRole = adminAuth.role;
              await adminAuth.setRole(value);
              await adminLogs.addChangeRoleLog(
                adminAuth.adminName,
                oldRole.displayName,
                value.displayName,
              );
            }
          },
        )),
      ],
    ),
  );
}
```

### 3.5. `admin_logs_screen.dart`

**Добавить фильтр безопасности:**

```dart
Widget build(BuildContext context) {
  return Scaffold(
    body: Column(
      children: [
        // Фильтры
        Row(
          children: [
            ChoiceChip(
              label: Text('Все'),
              selected: _filter == 'all',
              onSelected: (_) => setState(() => _filter = 'all'),
            ),
            ChoiceChip(
              label: Text('Безопасность'),
              selected: _filter == 'security',
              onSelected: (_) => setState(() => _filter = 'security'),
            ),
          ],
        ),

        // Список логов
        Expanded(
          child: ListView.builder(
            itemCount: _getFilteredLogs().length,
            itemBuilder: (context, index) {
              final log = _getFilteredLogs()[index];
              return LogTile(log: log);
            },
          ),
        ),
      ],
    ),

    // Экспорт логов безопасности
    floatingActionButton: _filter == 'security'
        ? FloatingActionButton(
            onPressed: _exportSecurityLogs,
            child: Icon(Icons.download),
          )
        : null,
  );
}

List<ActivityLog> _getFilteredLogs() {
  final logsProvider = context.watch<AdminLogsProvider>();

  switch (_filter) {
    case 'security':
      return logsProvider.getSecurityLogs();
    default:
      return logsProvider.logs;
  }
}

void _exportSecurityLogs() async {
  final logsProvider = context.read<AdminLogsProvider>();

  final format = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Экспорт логов безопасности'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, 'json'),
          child: Text('JSON'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, 'csv'),
          child: Text('CSV'),
        ),
      ],
    ),
  );

  if (format == 'json') {
    final data = logsProvider.exportSecurityLogsToJson();
    // Сохранить или показать
  } else if (format == 'csv') {
    final data = logsProvider.exportSecurityLogsToCsv();
    // Сохранить или показать
  }
}
```

### 3.6. `admin_children_screen.dart` и `admin_episodes_screen.dart`

**Проверка прав перед действиями:**

```dart
PopupMenuButton(
  itemBuilder: (context) {
    final permissions = context.read<AdminAuthProvider>().permissions;

    return [
      if (permissions.canUpdateChild)
        PopupMenuItem(value: 'edit', child: Text('Редактировать')),

      if (permissions.canDeleteChild)
        PopupMenuItem(value: 'delete', child: Text('Удалить')),
    ];
  },
  onSelected: (value) async {
    if (value == 'delete') {
      // Показать подтверждение
      final confirmed = await showDialog<bool>(...);

      if (confirmed == true) {
        try {
          await adminProvider.deleteChildWithAllData(child.id);
        } on PermissionDeniedException {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Недостаточно прав для этого действия'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  },
)
```

---

## 4. Обновление ADMIN_GUIDE.md

Добавить следующие разделы:

### 4.1. Раздел "Безопасность"

```markdown
## Безопасность

### Роли и права доступа

Система поддерживает 3 уровня доступа:

#### Admin (Администратор)
- ✅ Полный доступ ко всем функциям
- ✅ Создание, редактирование, удаление данных
- ✅ Управление ролями и 2FA
- ✅ Экспорт всех логов

#### Moderator (Модератор)
- ✅ Просмотр всех данных
- ✅ Создание и редактирование (без удаления)
- ✅ Экспорт данных
- ❌ Управление ролями и 2FA
- ❌ Удаление детей и эпизодов

#### Viewer (Наблюдатель)
- ✅ Только просмотр данных
- ❌ Любые изменения
- ❌ Экспорт данных
- ❌ Управление настройками

### Защита от брутфорса (Rate Limiting)

Система блокирует доступ после:
- **5 неудачных попыток** входа
- **Блокировка на 15 минут**
- Счетчик попыток сбрасывается после успешного входа

### Двухфакторная аутентификация (2FA)

#### Включение 2FA

1. Войдите в админку
2. Откройте **Настройки → Безопасность**
3. Включите переключатель **Двухфакторная аутентификация**
4. Отсканируйте QR код в приложении аутентификатора (Google Authenticator, Authy и т.д.)
5. Или введите секретный ключ вручную
6. **Сохраните резервные коды!**

#### Вход с 2FA

1. Введите пароль
2. Введите 6-значный код из приложения аутентификатора
3. Или используйте один из резервных кодов (8 цифр)

⚠️ **Важно:**
- Резервные коды можно использовать только один раз
- После использования резервного кода, регенерируйте новые коды
- Храните резервные коды в безопасном месте

#### Отключение 2FA

1. Настройки → Безопасность
2. Отключите переключатель **Двухфакторная аутентификация**
3. Введите текущий код 2FA для подтверждения

### Логи безопасности

Все действия, связанные с безопасностью, логируются:

- ❌ **failed_login** - Неудачные попытки входа
- 🔒 **lockout** - Блокировка из-за превышения попыток
- 🛡️ **enable_2fa** - Включение 2FA
- ⚠️ **disable_2fa** - Отключение 2FA
- 👤 **change_role** - Смена роли
- 🔐 **change_password** - Смена пароля
- 🔄 **reset_password** - Сброс пароля
- 🎫 **backup_code_used** - Использование резервного кода

#### Просмотр логов безопасности

1. Откройте **Журнал действий**
2. Выберите фильтр **Безопасность**
3. Все действия безопасности отображаются отдельно

#### Экспорт логов безопасности

1. Фильтр **Безопасность** → Кнопка **Экспорт**
2. Выберите формат:
   - **JSON** - для программной обработки
   - **CSV** - для анализа в Excel

### Смена роли

**Только для Admin!**

1. Настройки → Управление ролями
2. Выберите новую роль:
   - Admin
   - Moderator
   - Viewer
3. Система автоматически обновит права доступа

⚠️ **Предупреждение:**
- Смена роли с Admin на Moderator/Viewer ограничит ваш доступ
- Вы не сможете вернуть роль Admin самостоятельно

### Подозрительная активность

Система автоматически отслеживает:
- Частые неудачные попытки входа
- Множественные блокировки
- Использование резервных кодов

Проверяйте логи безопасности регулярно!
```

---

## 5. Тест-кейсы

### Test Case 1: Роль Admin - Полный доступ

**Цель:** Проверить, что Admin имеет полный доступ ко всем функциям

**Предусловия:**
- Пользователь с ролью Admin вошел в систему

**Шаги:**
1. Перейти в раздел "Дети"
2. Попытаться удалить ребенка
3. Перейти в "Настройки"
4. Попытаться изменить роль
5. Попытаться включить 2FA
6. Перейти в "Логи" и экспортировать логи безопасности

**Ожидаемый результат:**
- ✅ Все действия доступны
- ✅ Кнопка "Удалить" видна
- ✅ Раздел "Управление ролями" доступен
- ✅ Настройки 2FA доступны
- ✅ Экспорт логов безопасности работает

### Test Case 2: Роль Moderator - Ограниченный доступ

**Цель:** Проверить ограничения прав Moderator

**Предусловия:**
- Пользователь с ролью Moderator вошел в систему

**Шаги:**
1. Перейти в раздел "Дети"
2. Попытаться найти кнопку "Удалить"
3. Перейти в "Настройки"
4. Попытаться найти раздел "Управление ролями"
5. Попытаться найти настройки 2FA
6. Перейти в "Логи" и попытаться экспортировать данные

**Ожидаемый результат:**
- ✅ Кнопка "Удалить" скрыта
- ✅ Кнопка "Редактировать" видна
- ❌ Раздел "Управление ролями" не отображается
- ❌ Настройки 2FA не доступны
- ✅ Экспорт обычных логов работает
- ❌ Экспорт логов безопасности не доступен

### Test Case 3: Роль Viewer - Только просмотр

**Цель:** Проверить, что Viewer может только просматривать

**Предусловия:**
- Пользователь с ролью Viewer вошел в систему

**Шаги:**
1. Перейти в раздел "Дети"
2. Попытаться найти кнопки "Редактировать" и "Удалить"
3. Попытаться найти кнопку "Создать"
4. Перейти в "Логи"
5. Попытаться экспортировать логи

**Ожидаемый результат:**
- ✅ Просмотр данных работает
- ❌ Все кнопки редактирования скрыты
- ❌ Кнопка "Создать" скрыта
- ✅ Просмотр логов работает
- ❌ Экспорт логов не доступен

### Test Case 4: Rate Limiting - Блокировка после 5 попыток

**Цель:** Проверить защиту от брутфорса

**Предусловия:**
- Пользователь не вошел в систему
- Rate limiter сброшен

**Шаги:**
1. Ввести неверный пароль - 1 раз
2. Проверить сообщение об ошибке (должно показывать "Осталось попыток: 4")
3. Ввести неверный пароль - еще 4 раза
4. Проверить сообщение о блокировке
5. Попытаться войти с правильным паролем

**Ожидаемый результат:**
- ✅ После 5 неудачных попыток система блокирует доступ
- ✅ Сообщение показывает "Блокировка на 15 минут"
- ✅ Даже с правильным паролем вход невозможен
- ✅ Создан лог "lockout"
- ✅ Создано 5 логов "failed_login"

### Test Case 5: Rate Limiting - Сброс после успешного входа

**Цель:** Проверить сброс счетчика попыток

**Предусловия:**
- Пользователь не вошел в систему
- Есть 2 неудачные попытки

**Шаги:**
1. Ввести неверный пароль - 2 раза
2. Ввести правильный пароль
3. Выйти из системы
4. Проверить счетчик попыток (должен быть сброшен)

**Ожидаемый результат:**
- ✅ После успешного входа счетчик сбрасывается
- ✅ Новые попытки входа начинаются с 5 доступных попыток

### Test Case 6: 2FA - Успешный вход

**Цель:** Проверить вход с 2FA

**Предусловия:**
- 2FA включена для пользователя
- Есть валидный 2FA код

**Шаги:**
1. Ввести правильный пароль
2. Проверить появление поля для 2FA кода
3. Ввести правильный 2FA код
4. Проверить успешный вход

**Ожидаемый результат:**
- ✅ После ввода пароля появляется поле 2FA
- ✅ Правильный код позволяет войти
- ✅ Создан лог "login"
- ✅ Переход в админ-панель

---

## 6. Дополнительные рекомендации

### 6.1. Безопасность в продакшене

1. **Изменить дефолтный пароль:** Обязательно после первого входа
2. **Включить 2FA для Admin:** Всегда для роли Admin
3. **Регулярно проверять логи:** Минимум раз в неделю
4. **Резервные коды:** Хранить в безопасном месте (не на устройстве)
5. **Роли:** Назначать минимально необходимые права

### 6.2. Производительность

- Логи ограничены 1000 записями (автоматическая очистка)
- Rate limiter хранится в SharedPreferences (быстрый доступ)
- 2FA секреты в FlutterSecureStorage (зашифровано)

### 6.3. Совместимость

Все изменения обратно совместимы:
- Если роль не установлена → Admin по умолчанию
- Если 2FA не настроена → вход только по паролю
- Если rate limiter не загружен → новый экземпляр

---

## 7. Чеклист внедрения

- [ ] Создать `admin_role.dart` и `two_factor_auth.dart`
- [ ] Обновить `AdminAuthProvider` (роли, 2FA, rate limiting)
- [ ] Обновить `AdminLogsProvider` (логи безопасности)
- [ ] Обновить `ActivityLog` (новые иконки)
- [ ] Обновить `admin_login_screen.dart` (2FA UI, rate limiting)
- [ ] Обновить `admin_dashboard_screen.dart` (бейдж роли)
- [ ] Обновить `admin_drawer.dart` (скрыть недоступное)
- [ ] Обновить `admin_settings_screen.dart` (управление 2FA и ролями)
- [ ] Обновить `admin_logs_screen.dart` (фильтр безопасности)
- [ ] Обновить `admin_children_screen.dart` (проверка прав)
- [ ] Обновить `admin_episodes_screen.dart` (проверка прав)
- [ ] Обновить `ADMIN_GUIDE.md` (документация безопасности)
- [ ] Провести тестирование по всем тест-кейсам
- [ ] Обновить зависимости в `pubspec.yaml` (если нужно)

---

## 8. Поддержка

По вопросам реализации:
- Email: contact@childhealthcard.com
- GitHub Issues: https://github.com/amulanga9/Childs-Health-Card/issues
- Документация: `ADMIN_GUIDE.md`, `SECURITY.md`

---

**Версия документа:** 1.0.0
**Дата:** 2025-11-17
**Автор:** Child's Health Card Team
