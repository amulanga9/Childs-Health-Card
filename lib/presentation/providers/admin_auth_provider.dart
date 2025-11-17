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

    final limiterJson = _prefs.getString(_limiterKey);
    if (limiterJson != null) {
      _limiter = SimpleRateLimiter.fromJson(jsonDecode(limiterJson));
    }

    final secondJson = await _secure.read(key: _secondKey);
    if (secondJson != null) {
      _secondFactor = SecondFactor.fromJson(jsonDecode(secondJson));
    }

    notifyListeners();
  }

  /// Простой вход
  Future<String> login(String pass, {String? secondCode}) async {
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
    if (_secondFactor?.enabled == true) {
      if (secondCode == null) return 'NEED_SECOND'; // Специальный код
      if (!_secondFactor!.verify(secondCode)) {
        _limiter.recordFail();
        await _saveLimiter();
        notifyListeners();
        return 'Неверный PIN код';
      }
    }

    // Успех
    _isAuth = true;
    _lastLogin = DateTime.now();
    _limiter.reset();

    await _prefs.setString(_loginKey, _lastLogin!.toIso8601String());
    await _saveLimiter();

    notifyListeners();
    return 'OK';
  }

  Future<void> logout() async {
    _isAuth = false;
    notifyListeners();
  }

  Future<void> setName(String n) async {
    _name = n;
    await _prefs.setString(_nameKey, n);
    notifyListeners();
  }

  Future<void> setRole(String r) async {
    _role = r;
    await _prefs.setString(_roleKey, r);
    notifyListeners();
  }

  Future<bool> changePass(String oldPass, String newPass) async {
    final saved = await _secure.read(key: _passKey) ?? _defaultPass;
    if (oldPass != saved) return false;

    await _secure.write(key: _passKey, value: newPass);
    return true;
  }

  Future<void> resetPass() async {
    await _secure.delete(key: _passKey);
    await _secure.write(key: _passKey, value: _defaultPass);
  }

  // Second Factor (простой PIN)
  Future<void> enableSecondFactor(String pin) async {
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
    await _prefs.setString(_limiterKey, jsonEncode(_limiter.toJson()));
  }

  Future<void> _saveSecond() async {
    if (_secondFactor != null) {
      await _secure.write(key: _secondKey, jsonEncode(_secondFactor!.toJson()));
    }
  }
}
