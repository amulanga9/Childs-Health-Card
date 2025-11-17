import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/admin_role.dart';
import '../../data/models/two_factor_auth.dart';

/// Провайдер для авторизации администратора с поддержкой ролей, 2FA и rate limiting
class AdminAuthProvider with ChangeNotifier {
  final FlutterSecureStorage _secureStorage;
  final SharedPreferences _prefs;

  bool _isAuthenticated = false;
  String _adminName = 'Администратор';
  DateTime? _lastLoginTime;
  AdminRole _role = AdminRole.admin; // По умолчанию admin
  TwoFactorAuth? _twoFactorAuth;
  RateLimiter _rateLimiter = RateLimiter();

  static const String _adminPasswordKey = 'admin_password';
  static const String _adminNameKey = 'admin_name';
  static const String _adminRoleKey = 'admin_role';
  static const String _lastLoginKey = 'admin_last_login';
  static const String _twoFactorKey = 'admin_2fa';
  static const String _rateLimiterKey = 'admin_rate_limiter';
  static const String _defaultPassword = '0000';

  AdminAuthProvider({
    required FlutterSecureStorage secureStorage,
    required SharedPreferences prefs,
  })  : _secureStorage = secureStorage,
        _prefs = prefs {
    _loadAdminData();
  }

  // ============== Getters ==============

  bool get isAuthenticated => _isAuthenticated;
  String get adminName => _adminName;
  DateTime? get lastLoginTime => _lastLoginTime;
  AdminRole get role => _role;
  AdminPermissions get permissions => AdminPermissions(_role);
  TwoFactorAuth? get twoFactorAuth => _twoFactorAuth;
  RateLimiter get rateLimiter => _rateLimiter;

  bool get isAdmin => _role == AdminRole.admin;
  bool get isModerator => _role == AdminRole.moderator;
  bool get isViewer => _role == AdminRole.viewer;

  bool get is2FAEnabled => _twoFactorAuth?.isEnabled ?? false;
  bool get isLockedOut => _rateLimiter.isLockedOut;
  int get remainingAttempts => _rateLimiter.remainingAttempts;
  Duration? get remainingLockoutTime => _rateLimiter.remainingLockoutTime;

  // ============== Загрузка данных ==============

  /// Загрузка данных администратора
  Future<void> _loadAdminData() async {
    _adminName = _prefs.getString(_adminNameKey) ?? 'Администратор';

    // Загрузка роли
    final roleCode = _prefs.getString(_adminRoleKey);
    if (roleCode != null) {
      _role = AdminRole.fromCode(roleCode);
    }

    // Загрузка последнего входа
    final lastLoginStr = _prefs.getString(_lastLoginKey);
    if (lastLoginStr != null) {
      _lastLoginTime = DateTime.tryParse(lastLoginStr);
    }

    // Загрузка 2FA
    await _load2FA();

    // Загрузка rate limiter
    await _loadRateLimiter();

    notifyListeners();
  }

  /// Загрузка настроек 2FA
  Future<void> _load2FA() async {
    final twoFactorJson = await _secureStorage.read(key: _twoFactorKey);
    if (twoFactorJson != null) {
      try {
        final data = jsonDecode(twoFactorJson);
        _twoFactorAuth = TwoFactorAuth.fromJson(data);
      } catch (e) {
        debugPrint('Error loading 2FA: $e');
      }
    }
  }

  /// Загрузка rate limiter
  Future<void> _loadRateLimiter() async {
    final rateLimiterJson = _prefs.getString(_rateLimiterKey);
    if (rateLimiterJson != null) {
      try {
        final data = jsonDecode(rateLimiterJson);
        _rateLimiter = RateLimiter.fromJson(data);
      } catch (e) {
        debugPrint('Error loading rate limiter: $e');
      }
    }
  }

  /// Сохранение 2FA
  Future<void> _save2FA() async {
    if (_twoFactorAuth != null) {
      final json = jsonEncode(_twoFactorAuth!.toJson());
      await _secureStorage.write(key: _twoFactorKey, value: json);
    } else {
      await _secureStorage.delete(key: _twoFactorKey);
    }
  }

  /// Сохранение rate limiter
  Future<void> _saveRateLimiter() async {
    final json = jsonEncode(_rateLimiter.toJson());
    await _prefs.setString(_rateLimiterKey, json);
  }

  // ============== Аутентификация ==============

  /// Проверка, установлен ли пароль
  Future<bool> hasAdminPassword() async {
    final password = await _secureStorage.read(key: _adminPasswordKey);
    return password != null && password.isNotEmpty;
  }

  /// Вход в админку
  Future<LoginResult> login(String password, {String? twoFactorCode}) async {
    try {
      // Проверка блокировки
      if (_rateLimiter.isLockedOut) {
        return LoginResult.lockedOut;
      }

      // Проверка пароля
      final hasPassword = await hasAdminPassword();
      String? savedPassword;

      if (hasPassword) {
        savedPassword = await _secureStorage.read(key: _adminPasswordKey);
      } else {
        savedPassword = _defaultPassword;
        await setAdminPassword(_defaultPassword);
      }

      if (password != savedPassword) {
        // Неверный пароль - увеличиваем счетчик попыток
        _rateLimiter = _rateLimiter.recordFailedAttempt();
        await _saveRateLimiter();
        notifyListeners();
        return LoginResult.wrongPassword;
      }

      // Проверка 2FA
      if (_twoFactorAuth != null && _twoFactorAuth!.isEnabled) {
        if (twoFactorCode == null || twoFactorCode.isEmpty) {
          return LoginResult.need2FA;
        }

        if (!_twoFactorAuth!.verifyCode(twoFactorCode)) {
          _rateLimiter = _rateLimiter.recordFailedAttempt();
          await _saveRateLimiter();
          notifyListeners();
          return LoginResult.wrong2FA;
        }

        // Если использован резервный код, обновляем 2FA
        if (_twoFactorAuth!.backupCodes.contains(twoFactorCode)) {
          _twoFactorAuth = _twoFactorAuth!.useBackupCode(twoFactorCode);
          await _save2FA();
        }
      }

      // Успешный вход
      _isAuthenticated = true;
      _lastLoginTime = DateTime.now();
      _rateLimiter = _rateLimiter.reset();

      await _prefs.setString(_lastLoginKey, _lastLoginTime!.toIso8601String());
      await _saveRateLimiter();

      debugPrint('✅ Admin logged in: $_adminName ($_role)');
      notifyListeners();
      return LoginResult.success;
    } catch (e) {
      debugPrint('❌ Admin login error: $e');
      return LoginResult.error;
    }
  }

  /// Выход из админки
  Future<void> logout() async {
    _isAuthenticated = false;
    debugPrint('🚪 Admin logged out');
    notifyListeners();
  }

  // ============== Управление паролем ==============

  /// Установка пароля
  Future<void> setAdminPassword(String password) async {
    await _secureStorage.write(key: _adminPasswordKey, value: password);
    debugPrint('✅ Admin password set');
  }

  /// Изменение пароля
  Future<bool> changePassword(String oldPassword, String newPassword) async {
    try {
      final savedPassword = await _secureStorage.read(key: _adminPasswordKey);

      if (savedPassword == oldPassword) {
        await setAdminPassword(newPassword);
        debugPrint('✅ Admin password changed');
        return true;
      } else {
        debugPrint('❌ Old password incorrect');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Change password error: $e');
      return false;
    }
  }

  /// Сброс пароля
  Future<void> resetAdminPassword() async {
    await _secureStorage.delete(key: _adminPasswordKey);
    await setAdminPassword(_defaultPassword);
    debugPrint('🔄 Admin password reset to default');
  }

  // ============== Управление ролями ==============

  /// Установка роли
  Future<void> setRole(AdminRole newRole) async {
    _role = newRole;
    await _prefs.setString(_adminRoleKey, newRole.code);
    debugPrint('✅ Admin role set to: ${newRole.displayName}');
    notifyListeners();
  }

  /// Получение роли
  AdminRole getRole() => _role;

  // ============== Управление 2FA ==============

  /// Включение 2FA
  Future<TwoFactorAuth> enable2FA() async {
    if (_twoFactorAuth == null) {
      _twoFactorAuth = TwoFactorAuth(
        secretKey: TwoFactorAuth.generateSecretKey(),
        isEnabled: false,
      );
    }

    _twoFactorAuth = _twoFactorAuth!.enable();
    await _save2FA();
    debugPrint('✅ 2FA enabled');
    notifyListeners();
    return _twoFactorAuth!;
  }

  /// Отключение 2FA
  Future<void> disable2FA() async {
    if (_twoFactorAuth != null) {
      _twoFactorAuth = _twoFactorAuth!.disable();
      await _save2FA();
      debugPrint('🚫 2FA disabled');
      notifyListeners();
    }
  }

  /// Получение секретного ключа для настройки 2FA
  Future<String> get2FASecretKey() async {
    if (_twoFactorAuth == null) {
      _twoFactorAuth = TwoFactorAuth(
        secretKey: TwoFactorAuth.generateSecretKey(),
        isEnabled: false,
      );
      await _save2FA();
    }
    return _twoFactorAuth!.secretKey;
  }

  /// Получение резервных кодов
  List<String> get2FABackupCodes() {
    return _twoFactorAuth?.backupCodes ?? [];
  }

  /// Регенерация резервных кодов
  Future<List<String>> regenerate2FABackupCodes() async {
    if (_twoFactorAuth != null) {
      _twoFactorAuth = _twoFactorAuth!.regenerateBackupCodes();
      await _save2FA();
      notifyListeners();
      return _twoFactorAuth!.backupCodes;
    }
    return [];
  }

  // ============== Управление именем ==============

  /// Установка имени
  Future<void> setAdminName(String name) async {
    _adminName = name;
    await _prefs.setString(_adminNameKey, name);
    notifyListeners();
  }

  // ============== Проверка прав ==============

  /// Проверка права на действие
  bool hasPermission(String action) {
    return permissions.hasPermission(action);
  }

  /// Проверка сессии
  bool isSessionValid({int maxHours = 24}) {
    if (!_isAuthenticated || _lastLoginTime == null) {
      return false;
    }

    final now = DateTime.now();
    final difference = now.difference(_lastLoginTime!);

    return difference.inHours < maxHours;
  }

  /// Обновление времени последней активности
  Future<void> updateLastActivity() async {
    if (_isAuthenticated) {
      _lastLoginTime = DateTime.now();
      await _prefs.setString(_lastLoginKey, _lastLoginTime!.toIso8601String());
    }
  }

  // ============== Сброс rate limiter (для тестирования) ==============

  /// Сброс блокировки (только для admin)
  Future<void> resetRateLimiter() async {
    if (isAdmin) {
      _rateLimiter = RateLimiter();
      await _saveRateLimiter();
      notifyListeners();
      debugPrint('🔄 Rate limiter reset');
    }
  }
}

/// Результаты попытки входа
enum LoginResult {
  success, // Успешный вход
  wrongPassword, // Неверный пароль
  need2FA, // Требуется 2FA код
  wrong2FA, // Неверный 2FA код
  lockedOut, // Заблокирован из-за превышения попыток
  error, // Ошибка
}
