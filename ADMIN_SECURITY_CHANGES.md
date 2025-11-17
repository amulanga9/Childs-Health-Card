# Admin Security Features - Changes Summary

Краткий обзор всех изменений для улучшения безопасности админ-панели.

## Созданные файлы (3)

### 1. `lib/data/models/admin_role.dart` ✅
- Enum `AdminRole` (admin, moderator, viewer)
- Class `AdminPermissions` с методами проверки прав
- **Строк кода:** ~150

### 2. `lib/data/models/two_factor_auth.dart` ✅
- Class `TwoFactorAuth` (TOTP, резервные коды)
- Class `RateLimiter` (5 попыток / 15 мин)
- **Строк кода:** ~180

### 3. `lib/data/models/activity_log.dart` - Обновлен ✅
- Добавлены иконки для security actions
- Поддержка entityType = 'security'
- **Изменений:** +50 строк

---

## Обновленные Providers (3)

### 1. `lib/presentation/providers/admin_auth_provider.dart` ✅

**Добавлено:**
```dart
// Роли
AdminRole _role = AdminRole.admin;
AdminRole get role;
AdminPermissions get permissions;
Future<void> setRole(AdminRole newRole);

// 2FA
TwoFactorAuth? _twoFactorAuth;
bool get is2FAEnabled;
Future<TwoFactorAuth> enable2FA();
Future<void> disable2FA();

// Rate Limiting
RateLimiter _rateLimiter = RateLimiter();
bool get isLockedOut;
int get remainingAttempts;
Duration? get remainingLockoutTime;

// Улучшенный login
Future<LoginResult> login(String password, {String? twoFactorCode});
```

**Строк кода:** ~350 (+200)

### 2. `lib/presentation/providers/admin_logs_provider.dart` ✅

**Добавлено:**
```dart
// Специализированные методы для security logs
Future<void> addFailedLoginLog(...);
Future<void> addLockoutLog(...);
Future<void> addEnable2FALog(...);
Future<void> addDisable2FALog(...);
Future<void> addChangeRoleLog(...);
Future<void> addChangePasswordLog(...);
Future<void> addResetPasswordLog(...);
Future<void> addBackupCodeUsedLog(...);

// Фильтры и экспорт
List<ActivityLog> getSecurityLogs();
List<ActivityLog> getFailedLoginLogs({int days = 7});
bool hasSuspiciousActivity(...);
String exportSecurityLogsToJson();
String exportSecurityLogsToCsv();
```

**Строк кода:** ~350 (+150)

### 3. `lib/presentation/providers/admin_provider.dart` - Требуется обновление

**Необходимо добавить:**
```dart
Future<T> _checkPermission<T>(
  String permission,
  Future<T> Function() action,
) async {
  if (!context.read<AdminAuthProvider>().hasPermission(permission)) {
    throw PermissionDeniedException('Недостаточно прав: $permission');
  }
  return await action();
}

// Обернуть все delete методы
Future<void> deleteChildWithAllData(int childId) async {
  return _checkPermission('delete_child', () async {
    // ... существующая логика
  });
}
```

---

## Обновленные Screens (7)

### 1. `admin_login_screen.dart` - Требует полного переписывания

**Ключевые изменения:**
- Поле для 2FA кода (показывается условно)
- Проверка `isLockedOut` перед входом
- Обработка всех `LoginResult` значений
- Отображение счетчика попыток
- Таймер блокировки

**Компоненты:**
```dart
- Password field (существует)
- 2FA code field (добавить)
- Lockout warning banner (добавить)
- Attempts counter (добавить)
- Back to password button (для 2FA)
```

### 2. `admin_dashboard_screen.dart`

**Изменения:**
- Добавить бейдж роли в приветствии
- Показать иконку роли
- Цветовая кодировка ролей

```dart
Widget _buildRoleBadge() {
  return Chip(
    avatar: Icon(_getRoleIcon(adminAuth.role)),
    label: Text(adminAuth.role.displayName),
    backgroundColor: _getRoleColor(adminAuth.role),
  );
}
```

### 3. `admin_drawer.dart`

**Изменения:**
- Условный рендеринг пунктов меню
- Бейдж роли в header

```dart
if (permissions.canManageUsers)
  ListTile(...),

if (permissions.canManage2FA)
  ListTile(...),
```

### 4. `admin_settings_screen.dart` - Требует существенных изменений

**Добавить разделы:**

**4.1. Управление 2FA:**
```dart
Card(
  child: Column(
    children: [
      SwitchListTile(
        title: Text('Двухфакторная аутентификация'),
        value: adminAuth.is2FAEnabled,
        onChanged: _toggle2FA,
      ),
      if (adminAuth.is2FAEnabled) ...[
        Text('Секретный ключ: ${adminAuth.twoFactorAuth!.secretKey}'),
        Text('Резервные коды: ${adminAuth.get2FABackupCodes().length}'),
        ElevatedButton(
          onPressed: _regenerateBackupCodes,
          child: Text('Регенерировать коды'),
        ),
        ElevatedButton(
          onPressed: _showBackupCodes,
          child: Text('Показать коды'),
        ),
      ],
    ],
  ),
)
```

**4.2. Управление ролями (только Admin):**
```dart
if (adminAuth.permissions.canManageRoles)
  Card(
    child: Column(
      children: AdminRole.values.map((role) =>
        RadioListTile<AdminRole>(
          title: Text(role.displayName),
          subtitle: Text(AdminPermissions(role).roleDescription),
          value: role,
          groupValue: adminAuth.role,
          onChanged: _changeRole,
        ),
      ).toList(),
    ),
  )
```

### 5. `admin_logs_screen.dart`

**Изменения:**
- Добавить chip для фильтра "Безопасность"
- Кнопка экспорта security logs
- Отдельная статистика security logs

```dart
ChoiceChip(
  label: Text('Безопасность'),
  selected: _filter == 'security',
  onSelected: (_) => setState(() => _filter = 'security'),
),

if (_filter == 'security')
  FloatingActionButton(
    onPressed: _exportSecurityLogs,
    child: Icon(Icons.download),
  )
```

### 6. `admin_children_screen.dart`

**Изменения:**
- Условное отображение кнопок
- Обработка `PermissionDeniedException`

```dart
trailing: PopupMenuButton(
  itemBuilder: (context) {
    final items = <PopupMenuEntry<String>>[];

    if (permissions.canUpdateChild)
      items.add(PopupMenuItem(value: 'edit', child: Text('Редактировать')));

    if (permissions.canDeleteChild)
      items.add(PopupMenuItem(value: 'delete', child: Text('Удалить')));

    return items;
  },
)
```

### 7. `admin_episodes_screen.dart`

**Аналогично admin_children_screen.dart**

---

## Дополнительные тесты

### Интеграционные тесты

```dart
// test/integration/admin_security_test.dart

void main() {
  group('Admin Security Integration Tests', () {
    testWidgets('Viewer cannot delete child', (tester) async {
      // Setup: Login as Viewer
      // Attempt: Delete child
      // Expect: Button not visible or exception thrown
    });

    testWidgets('Moderator can edit but not delete', (tester) async {
      // Setup: Login as Moderator
      // Attempt: Edit child - should succeed
      // Attempt: Delete child - should fail
    });

    testWidgets('2FA flow works correctly', (tester) async {
      // Setup: Enable 2FA
      // Login: Enter password
      // Expect: 2FA field appears
      // Enter: Correct 2FA code
      // Expect: Login successful
    });

    testWidgets('Rate limiting blocks after 5 attempts', (tester) async {
      // Loop: 5 failed login attempts
      // Expect: Lockout message
      // Attempt: Login with correct password
      // Expect: Still blocked
    });
  });
}
```

### Unit тесты

```dart
// test/unit/rate_limiter_test.dart

void main() {
  group('RateLimiter', () {
    test('allows 5 attempts', () {
      var limiter = RateLimiter();
      expect(limiter.remainingAttempts, 5);

      for (int i = 0; i < 4; i++) {
        limiter = limiter.recordFailedAttempt();
      }

      expect(limiter.remainingAttempts, 1);
      expect(limiter.isLockedOut, false);
    });

    test('locks out after 5 attempts', () {
      var limiter = RateLimiter();

      for (int i = 0; i < 5; i++) {
        limiter = limiter.recordFailedAttempt();
      }

      expect(limiter.isLockedOut, true);
      expect(limiter.remainingAttempts, 0);
    });

    test('resets after success', () {
      var limiter = RateLimiter();
      limiter = limiter.recordFailedAttempt();
      limiter = limiter.recordFailedAttempt();

      limiter = limiter.reset();

      expect(limiter.remainingAttempts, 5);
      expect(limiter.isLockedOut, false);
    });
  });
}

// test/unit/admin_permissions_test.dart

void main() {
  group('AdminPermissions', () {
    test('Admin has all permissions', () {
      final perms = AdminPermissions(AdminRole.admin);

      expect(perms.canDeleteChild, true);
      expect(perms.canManage2FA, true);
      expect(perms.canManageRoles, true);
      expect(perms.canExport, true);
    });

    test('Moderator has limited permissions', () {
      final perms = AdminPermissions(AdminRole.moderator);

      expect(perms.canUpdateChild, true);
      expect(perms.canDeleteChild, false);
      expect(perms.canManage2FA, false);
      expect(perms.canExport, true);
    });

    test('Viewer has minimal permissions', () {
      final perms = AdminPermissions(AdminRole.viewer);

      expect(perms.canView, true);
      expect(perms.canUpdateChild, false);
      expect(perms.canDeleteChild, false);
      expect(perms.canExport, false);
    });
  });
}
```

---

## Миграция данных

Для существующих установок:

```dart
// lib/migrations/admin_security_migration.dart

class AdminSecurityMigration {
  static Future<void> migrate(
    SharedPreferences prefs,
    FlutterSecureStorage storage,
  ) async {
    // 1. Установить роль Admin для существующих админов
    if (!prefs.containsKey('admin_role')) {
      await prefs.setString('admin_role', AdminRole.admin.code);
    }

    // 2. Инициализировать rate limiter
    if (!prefs.containsKey('admin_rate_limiter')) {
      final limiter = RateLimiter();
      await prefs.setString('admin_rate_limiter', jsonEncode(limiter.toJson()));
    }

    // 3. 2FA остается выключенной по умолчанию (null)
  }
}

// В main.dart:
void main() async {
  // ...
  await AdminSecurityMigration.migrate(prefs, secureStorage);
  // ...
}
```

---

## Performance Impact

**Оценка влияния на производительность:**

| Компонент | Влияние | Оптимизация |
|-----------|---------|-------------|
| AdminAuthProvider.login() | +50ms (2FA verification) | Приемлемо |
| Rate Limiter check | +5ms (JSON parse) | Кеширование |
| Permission checks | +1ms (in-memory) | Нет |
| Security logs | +10ms (JSON save) | Фоновое сохранение |

**Память:**
- AdminRole enum: ~100 bytes
- RateLimiter: ~200 bytes
- TwoFactorAuth: ~500 bytes (с кодами)
- Security logs (100 записей): ~50KB

**Итого:** Незначительное влияние на производительность.

---

## Checklist для code review

- [ ] Все enum и константы определены правильно
- [ ] Rate limiting работает корректно (5 попыток, 15 мин)
- [ ] 2FA коды генерируются случайно (secure random)
- [ ] Резервные коды удаляются после использования
- [ ] Permissions проверяются перед всеми критичными действиями
- [ ] UI корректно скрывает недоступные элементы
- [ ] Логи безопасности записываются для всех критичных действий
- [ ] Нет утечек чувствительных данных в логах
- [ ] Пароли и 2FA секреты хранятся в FlutterSecureStorage
- [ ] Тесты покрывают все основные сценарии
- [ ] Документация обновлена
- [ ] Миграция существующих данных реализована

---

## Полезные ссылки

- [ADMIN_SECURITY_IMPLEMENTATION.md](ADMIN_SECURITY_IMPLEMENTATION.md) - Полная документация
- [ADMIN_GUIDE.md](ADMIN_GUIDE.md) - Руководство пользователя
- [Flutter Secure Storage](https://pub.dev/packages/flutter_secure_storage)
- [TOTP RFC 6238](https://tools.ietf.org/html/rfc6238)
- [OWASP Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)

---

**Status:** 🚧 В разработке
**Priority:** 🔴 High
**Estimated Time:** 12-16 часов разработки

**Последнее обновление:** 2025-11-17
