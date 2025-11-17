import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/admin_security.dart';

/// Простой провайдер авторизации админа
class AdminAuthProvider with ChangeNotifier {
  final FlutterSecureStorage _secure;
  final SharedPreferences _prefs;

  bool _isAuth = false;
  String _name = 'Админ';
  String _role = AdminRole.admin;
  DateTime? _lastLogin;

  SimpleRateLimiter _limiter = SimpleRateLimiter();
  SecondFactor? _secondFactor;

  static const _passKey = 'admin_pass';
  static const _nameKey = 'admin_name';
  static const _roleKey = 'admin_role';
  static const _loginKey = 'last_login';
  static const _limiterKey = 'rate_limit';
  static const _secondKey = 'second_factor';
  static const _defaultPass = '0000';

  AdminAuthProvider({
    required FlutterSecureStorage secureStorage,
    required SharedPreferences prefs,
  })  : _secure = secureStorage,
        _prefs = prefs {
    _load();
  }

  // Getters
  bool get isAuth => _isAuth;
  String get name => _name;
  String get role => _role;
  DateTime? get lastLogin => _lastLogin;
  Permissions get perms => Permissions(_role);

  bool get isLocked => _limiter.isLocked;
  int get attemptsLeft => _limiter.remainingAttempts;
  String? get lockTime => _limiter.lockTimeRemaining;

  bool get hasSecondFactor => _secondFactor?.enabled ?? false;

  Future<void> _load() async {
    _name = _prefs.getString(_nameKey) ?? 'Админ';
    _role = _prefs.getString(_roleKey) ?? AdminRole.admin;

    final loginStr = _prefs.getString(_loginKey);
    if (loginStr != null) _lastLogin = DateTime.tryParse(loginStr);

    // Загрузка rate limiter с обработкой ошибок
    final limiterJson = _prefs.getString(_limiterKey);
    if (limiterJson != null) {
      try {
        _limiter = SimpleRateLimiter.fromJson(jsonDecode(limiterJson));
      } catch (e) {
        debugPrint('Ошибка загрузки rate limiter: $e');
        _limiter = SimpleRateLimiter(); // Создаем новый при ошибке
      }
    }

    // Загрузка second factor с обработкой ошибок
    final secondJson = await _secure.read(key: _secondKey);
    if (secondJson != null) {
      try {
        _secondFactor = SecondFactor.fromJson(jsonDecode(secondJson));
      } catch (e) {
        debugPrint('Ошибка загрузки second factor: $e');
        _secondFactor = null; // Сбрасываем при ошибке
      }
    }

    notifyListeners();
  }

  /// Простой вход
  Future<String> login(String pass, {String? secondCode}) async {
    // Валидация входных данных
    if (pass.isEmpty) {
      return 'Пароль не может быть пустым';
    }

    // Проверка блокировки
    if (_limiter.isLocked) {
      return 'Заблокировано. Подождите ${_limiter.lockTimeRemaining}';
    }

    // Проверка пароля
    final saved = await _secure.read(key: _passKey) ?? _defaultPass;
    if (pass != saved) {
      _limiter.recordFail();
      await _saveLimiter();
      notifyListeners();
      return 'Неверный пароль. Осталось попыток: ${_limiter.remainingAttempts}';
    }

    // Проверка second factor
    bool usedBackup = false;
    if (_secondFactor?.enabled == true) {
      if (secondCode == null) return 'NEED_SECOND'; // Специальный код

      final (success, usedBackupCode) = _secondFactor!.verifyWithUsage(secondCode);

      if (!success) {
        _limiter.recordFail();
        await _saveLimiter();
        notifyListeners();
        return 'Неверный PIN код';
      }

      // Если использован backup код - удаляем его
      if (usedBackupCode != null) {
        _secondFactor = _secondFactor!.removeBackupCode(usedBackupCode);
        await _saveSecond();
        usedBackup = true;
      }
    }

    // Успех
    _isAuth = true;
    _lastLogin = DateTime.now();
    _limiter.reset();

    await _prefs.setString(_loginKey, _lastLogin!.toIso8601String());
    await _saveLimiter();

    notifyListeners();
    return usedBackup ? 'OK_BACKUP_USED' : 'OK';
  }

  Future<void> logout() async {
    _isAuth = false;
    notifyListeners();
  }

  Future<void> setName(String n) async {
    // Валидация
    if (n.isEmpty) {
      debugPrint('Предупреждение: попытка установить пустое имя');
      return;
    }

    _name = n;
    await _prefs.setString(_nameKey, n);
    notifyListeners();
  }

  Future<void> setRole(String r) async {
    // Валидация роли
    if (!AdminRole.isValid(r)) {
      debugPrint('Ошибка: неверная роль $r');
      return;
    }

    _role = r;
    await _prefs.setString(_roleKey, r);
    notifyListeners();
  }

  Future<bool> changePass(String oldPass, String newPass) async {
    // Валидация
    if (oldPass.isEmpty || newPass.isEmpty) {
      return false;
    }

    final saved = await _secure.read(key: _passKey) ?? _defaultPass;
    if (oldPass != saved) return false;

    await _secure.write(key: _passKey, value: newPass);
    return true;
  }

  Future<void> resetPass() async {
    await _secure.write(key: _passKey, value: _defaultPass);
  }

  // Second Factor (простой PIN)
  Future<void> enableSecondFactor(String pin) async {
    // Валидация PIN: должен быть ровно 4 цифры
    if (pin.length != 4 || !RegExp(r'^\d{4}$').hasMatch(pin)) {
      debugPrint('Ошибка: PIN должен быть 4 цифры');
      return;
    }

    _secondFactor = SecondFactor(
      pinCode: pin,
      enabled: true,
      backupCodes: SecondFactor.generateBackups(),
    );
    await _saveSecond();
    notifyListeners();
  }

  Future<void> disableSecondFactor() async {
    if (_secondFactor != null) {
      _secondFactor = SecondFactor(
        pinCode: _secondFactor!.pinCode,
        enabled: false,
        backupCodes: _secondFactor!.backupCodes,
      );
      await _saveSecond();
      notifyListeners();
    }
  }

  List<String> getBackupCodes() => _secondFactor?.backupCodes ?? [];

  Future<void> _saveLimiter() async {
    try {
      await _prefs.setString(_limiterKey, jsonEncode(_limiter.toJson()));
    } catch (e) {
      debugPrint('Ошибка сохранения rate limiter: $e');
    }
  }

  Future<void> _saveSecond() async {
    if (_secondFactor != null) {
      try {
        // ИСПРАВЛЕН КРИТИЧЕСКИЙ БАГ: добавлен параметр value:
        await _secure.write(
          key: _secondKey,
          value: jsonEncode(_secondFactor!.toJson()),
        );
      } catch (e) {
        debugPrint('Ошибка сохранения second factor: $e');
      }
    }
  }
}
