import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Провайдер для авторизации администратора
///
/// Управляет входом/выходом администратора и хранением админского пароля
class AdminAuthProvider with ChangeNotifier {
  final FlutterSecureStorage _secureStorage;
  final SharedPreferences _prefs;

  bool _isAuthenticated = false;
  String _adminName = 'Администратор';
  DateTime? _lastLoginTime;

  static const String _adminPasswordKey = 'admin_password';
  static const String _adminNameKey = 'admin_name';
  static const String _lastLoginKey = 'admin_last_login';
  static const String _defaultPassword = '0000'; // Дефолтный пароль

  AdminAuthProvider({
    required FlutterSecureStorage secureStorage,
    required SharedPreferences prefs,
  })  : _secureStorage = secureStorage,
        _prefs = prefs {
    _loadAdminData();
  }

  // Getters
  bool get isAuthenticated => _isAuthenticated;
  String get adminName => _adminName;
  DateTime? get lastLoginTime => _lastLoginTime;

  /// Загрузка данных администратора
  Future<void> _loadAdminData() async {
    _adminName = _prefs.getString(_adminNameKey) ?? 'Администратор';

    final lastLoginStr = _prefs.getString(_lastLoginKey);
    if (lastLoginStr != null) {
      _lastLoginTime = DateTime.tryParse(lastLoginStr);
    }

    notifyListeners();
  }

  /// Проверка, установлен ли админский пароль
  Future<bool> hasAdminPassword() async {
    final password = await _secureStorage.read(key: _adminPasswordKey);
    return password != null && password.isNotEmpty;
  }

  /// Установка админского пароля
  Future<void> setAdminPassword(String password) async {
    await _secureStorage.write(key: _adminPasswordKey, value: password);
    debugPrint('✅ Admin password set');
  }

  /// Изменение имени администратора
  Future<void> setAdminName(String name) async {
    _adminName = name;
    await _prefs.setString(_adminNameKey, name);
    notifyListeners();
  }

  /// Вход в админку
  Future<bool> login(String password) async {
    try {
      // Проверяем, есть ли сохраненный пароль
      final hasPassword = await hasAdminPassword();

      String? savedPassword;
      if (hasPassword) {
        savedPassword = await _secureStorage.read(key: _adminPasswordKey);
      } else {
        // Если пароль не установлен, используем дефолтный
        savedPassword = _defaultPassword;
        // Сохраняем дефолтный пароль
        await setAdminPassword(_defaultPassword);
      }

      // Проверяем пароль
      if (password == savedPassword) {
        _isAuthenticated = true;
        _lastLoginTime = DateTime.now();

        // Сохраняем время последнего входа
        await _prefs.setString(
          _lastLoginKey,
          _lastLoginTime!.toIso8601String(),
        );

        debugPrint('✅ Admin logged in: $_adminName');
        notifyListeners();
        return true;
      } else {
        debugPrint('❌ Invalid admin password');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Admin login error: $e');
      return false;
    }
  }

  /// Выход из админки
  Future<void> logout() async {
    _isAuthenticated = false;
    debugPrint('🚪 Admin logged out');
    notifyListeners();
  }

  /// Сброс админского пароля (для восстановления)
  Future<void> resetAdminPassword() async {
    await _secureStorage.delete(key: _adminPasswordKey);
    await setAdminPassword(_defaultPassword);
    debugPrint('🔄 Admin password reset to default: $_defaultPassword');
  }

  /// Изменение админского пароля
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

  /// Проверка сессии (автоматический выход через N часов)
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
      await _prefs.setString(
        _lastLoginKey,
        _lastLoginTime!.toIso8601String(),
      );
    }
  }
}
