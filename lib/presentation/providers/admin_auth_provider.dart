import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/admin_security.dart';

/// Провайдер авторизации админ-панели
class AdminAuthProvider with ChangeNotifier {
  // Зависимости
  final FlutterSecureStorage _secure;
  final SharedPreferences _prefs;

  // Ключи хранилища
  static const _passKey = 'admin_pass';
  static const _nameKey = 'admin_name';
  static const _roleKey = 'admin_role';
  static const _loginKey = 'last_login';
  static const _limiterKey = 'rate_limit';
  static const _secondKey = 'second_factor';

  // Константы
  static const _defaultPass = '0000';

  // Публичные константы результатов login()
  static const resultOk = 'OK';
  static const resultBackupUsed = 'OK_BACKUP_USED';
  static const resultNeedSecond = 'NEED_SECOND';

  // Состояние
  bool _isAuth = false;
  String _name = 'Админ';
  String _role = AdminRole.admin;
  DateTime? _lastLogin;
  SimpleRateLimiter _limiter = SimpleRateLimiter();
  SecondFactor? _secondFactor;

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

  /// Вход в админ-панель
  Future<String> login(String pass, {String? secondCode}) async {
    // 1. Валидация
    if (pass.isEmpty) return 'Пароль не может быть пустым';

    // 2. Проверка блокировки
    if (_limiter.isLocked) {
      return 'Заблокировано. Подождите ${_limiter.lockTimeRemaining}';
    }

    // 3. Проверка пароля
    final passwordValid = await _checkPassword(pass);
    if (!passwordValid) {
      return _handleFailedAttempt('Неверный пароль');
    }

    // 4. Проверка второго фактора
    final secondFactorResult = await _checkSecondFactor(secondCode);
    if (secondFactorResult != resultOk) return secondFactorResult;

    // 5. Успешный вход
    return await _handleSuccessfulLogin();
  }

  Future<bool> _checkPassword(String pass) async {
    final saved = await _secure.read(key: _passKey) ?? _defaultPass;
    return pass == saved;
  }

  Future<String> _checkSecondFactor(String? code) async {
    if (_secondFactor?.enabled != true) return resultOk;

    if (code == null) return resultNeedSecond;

    final (success, usedBackupCode) = _secondFactor!.verifyCode(code);

    if (!success) {
      await _handleFailedAttempt('Неверный PIN код');
      return 'Неверный PIN код';
    }

    // Удаляем использованный backup код
    if (usedBackupCode != null) {
      _secondFactor = _secondFactor!.removeBackupCode(usedBackupCode);
      await _saveJson(_secondKey, _secondFactor!.toJson(), secure: true);
      return resultBackupUsed;
    }

    return resultOk;
  }

  String _handleFailedAttempt(String message) {
    _limiter.recordFail();
    _saveJson(_limiterKey, _limiter.toJson());
    notifyListeners();
    return '$message. Осталось попыток: ${_limiter.remainingAttempts}';
  }

  Future<String> _handleSuccessfulLogin() async {
    _isAuth = true;
    _lastLogin = DateTime.now();
    _limiter.reset();

    await _prefs.setString(_loginKey, _lastLogin!.toIso8601String());
    await _saveJson(_limiterKey, _limiter.toJson());

    notifyListeners();
    return resultOk;
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

  // Управление вторым фактором
  Future<void> enableSecondFactor(String pin) async {
    // Валидация: PIN должен быть ровно 4 цифры
    if (pin.length != SecondFactor.pinLength ||
        !RegExp(r'^\d{4}$').hasMatch(pin)) {
      debugPrint('Ошибка: PIN должен быть ${SecondFactor.pinLength} цифры');
      return;
    }

    _secondFactor = SecondFactor(
      pinCode: pin,
      enabled: true,
      backupCodes: SecondFactor.generateBackupCodes(),
    );

    await _saveJson(_secondKey, _secondFactor!.toJson(), secure: true);
    notifyListeners();
  }

  Future<void> disableSecondFactor() async {
    if (_secondFactor == null) return;

    _secondFactor = SecondFactor(
      pinCode: _secondFactor!.pinCode,
      enabled: false,
      backupCodes: _secondFactor!.backupCodes,
    );

    await _saveJson(_secondKey, _secondFactor!.toJson(), secure: true);
    notifyListeners();
  }

  List<String> getBackupCodes() => _secondFactor?.backupCodes ?? [];

  /// Универсальное сохранение JSON в хранилище
  Future<void> _saveJson(
    String key,
    Map<String, dynamic> data, {
    bool secure = false,
  }) async {
    try {
      final json = jsonEncode(data);

      if (secure) {
        await _secure.write(key: key, value: json);
      } else {
        await _prefs.setString(key, json);
      }
    } catch (e) {
      debugPrint('Ошибка сохранения $key: $e');
    }
  }
}
