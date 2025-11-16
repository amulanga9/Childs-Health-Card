import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../data/database/database.dart';

/// Провайдер настроек приложения
class SettingsProvider with ChangeNotifier {
  final AppDatabase database;
  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;

  SettingsProvider({
    required this.database,
    required SharedPreferences prefs,
    FlutterSecureStorage? secureStorage,
  })  : _prefs = prefs,
        _secureStorage = secureStorage ?? const FlutterSecureStorage() {
    _loadSettings();
  }

  // ==================== Язык ====================

  String _languageCode = 'ru';
  String get languageCode => _languageCode;

  Locale get locale => Locale(_languageCode);

  Future<void> setLanguage(String languageCode) async {
    _languageCode = languageCode;
    await _prefs.setString('language_code', languageCode);
    notifyListeners();
  }

  // ==================== PIN-код ====================

  bool _isPinEnabled = false;
  bool get isPinEnabled => _isPinEnabled;

  bool _useBiometrics = false;
  bool get useBiometrics => _useBiometrics;

  /// Установить PIN-код
  Future<bool> setPinCode(String pinCode) async {
    try {
      await _secureStorage.write(key: 'pin_code', value: pinCode);
      _isPinEnabled = true;
      await _prefs.setBool('pin_enabled', true);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error setting PIN: $e');
      return false;
    }
  }

  /// Проверить PIN-код
  Future<bool> verifyPinCode(String pinCode) async {
    try {
      final storedPin = await _secureStorage.read(key: 'pin_code');
      return storedPin == pinCode;
    } catch (e) {
      debugPrint('Error verifying PIN: $e');
      return false;
    }
  }

  /// Удалить PIN-код
  Future<bool> removePinCode() async {
    try {
      await _secureStorage.delete(key: 'pin_code');
      _isPinEnabled = false;
      await _prefs.setBool('pin_enabled', false);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error removing PIN: $e');
      return false;
    }
  }

  /// Включить/выключить биометрию
  Future<void> setBiometrics(bool enabled) async {
    _useBiometrics = enabled;
    await _prefs.setBool('use_biometrics', enabled);
    notifyListeners();
  }

  // ==================== Облачные настройки ====================

  bool _isCloudEnabled = false;
  bool get isCloudEnabled => _isCloudEnabled;

  String? _cloudEndpoint;
  String? get cloudEndpoint => _cloudEndpoint;

  /// Сохранить облачные учетные данные
  Future<bool> setCloudCredentials({
    required String endpoint,
    required String accessKey,
    required String secretKey,
    required String bucketName,
  }) async {
    try {
      await _secureStorage.write(key: 'cloud_endpoint', value: endpoint);
      await _secureStorage.write(key: 'cloud_access_key', value: accessKey);
      await _secureStorage.write(key: 'cloud_secret_key', value: secretKey);
      await _secureStorage.write(key: 'cloud_bucket', value: bucketName);

      _isCloudEnabled = true;
      _cloudEndpoint = endpoint;
      await _prefs.setBool('cloud_enabled', true);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error setting cloud credentials: $e');
      return false;
    }
  }

  /// Получить облачные учетные данные
  Future<Map<String, String?>> getCloudCredentials() async {
    try {
      return {
        'endpoint': await _secureStorage.read(key: 'cloud_endpoint'),
        'accessKey': await _secureStorage.read(key: 'cloud_access_key'),
        'secretKey': await _secureStorage.read(key: 'cloud_secret_key'),
        'bucketName': await _secureStorage.read(key: 'cloud_bucket'),
      };
    } catch (e) {
      debugPrint('Error getting cloud credentials: $e');
      return {};
    }
  }

  /// Удалить облачные учетные данные
  Future<bool> removeCloudCredentials() async {
    try {
      await _secureStorage.delete(key: 'cloud_endpoint');
      await _secureStorage.delete(key: 'cloud_access_key');
      await _secureStorage.delete(key: 'cloud_secret_key');
      await _secureStorage.delete(key: 'cloud_bucket');

      _isCloudEnabled = false;
      _cloudEndpoint = null;
      await _prefs.setBool('cloud_enabled', false);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error removing cloud credentials: $e');
      return false;
    }
  }

  // ==================== Управление детьми ====================

  List<Child> _children = [];
  List<Child> get children => _children;

  bool get canAddChild => _children.length < 5;

  /// Загрузить список детей
  Future<void> loadChildren() async {
    try {
      _children = await database.childDao.getAllChildren();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading children: $e');
    }
  }

  /// Добавить ребенка
  Future<bool> addChild(ChildrenCompanion child) async {
    if (!canAddChild) {
      return false;
    }

    try {
      await database.childDao.createChild(child);
      await loadChildren();
      return true;
    } catch (e) {
      debugPrint('Error adding child: $e');
      return false;
    }
  }

  /// Обновить данные ребенка
  Future<bool> updateChild(Child child) async {
    try {
      await database.childDao.updateChild(child);
      await loadChildren();
      return true;
    } catch (e) {
      debugPrint('Error updating child: $e');
      return false;
    }
  }

  /// Удалить ребенка
  Future<bool> deleteChild(int childId) async {
    try {
      await database.childDao.deleteChild(childId);
      await loadChildren();
      return true;
    } catch (e) {
      debugPrint('Error deleting child: $e');
      return false;
    }
  }

  // ==================== Резервное копирование ====================

  DateTime? _lastBackupTime;
  DateTime? get lastBackupTime => _lastBackupTime;

  bool _autoBackup = false;
  bool get autoBackup => _autoBackup;

  /// Включить/выключить автоматическое резервное копирование
  Future<void> setAutoBackup(bool enabled) async {
    _autoBackup = enabled;
    await _prefs.setBool('auto_backup', enabled);
    notifyListeners();
  }

  /// Обновить время последнего резервного копирования
  Future<void> updateLastBackupTime() async {
    _lastBackupTime = DateTime.now();
    await _prefs.setInt(
      'last_backup_time',
      _lastBackupTime!.millisecondsSinceEpoch,
    );
    notifyListeners();
  }

  // ==================== Уведомления ====================

  bool _notificationsEnabled = true;
  bool get notificationsEnabled => _notificationsEnabled;

  bool _medicationReminders = true;
  bool get medicationReminders => _medicationReminders;

  /// Включить/выключить уведомления
  Future<void> setNotifications(bool enabled) async {
    _notificationsEnabled = enabled;
    await _prefs.setBool('notifications_enabled', enabled);
    notifyListeners();
  }

  /// Включить/выключить напоминания о лекарствах
  Future<void> setMedicationReminders(bool enabled) async {
    _medicationReminders = enabled;
    await _prefs.setBool('medication_reminders', enabled);
    notifyListeners();
  }

  // ==================== Приватность ====================

  bool _requirePinOnStart = false;
  bool get requirePinOnStart => _requirePinOnStart;

  bool _hideDataInMultitasking = false;
  bool get hideDataInMultitasking => _hideDataInMultitasking;

  /// Требовать PIN при запуске
  Future<void> setRequirePinOnStart(bool enabled) async {
    _requirePinOnStart = enabled;
    await _prefs.setBool('require_pin_on_start', enabled);
    notifyListeners();
  }

  /// Скрывать данные в режиме многозадачности
  Future<void> setHideDataInMultitasking(bool enabled) async {
    _hideDataInMultitasking = enabled;
    await _prefs.setBool('hide_data_multitasking', enabled);
    notifyListeners();
  }

  // ==================== Загрузка настроек ====================

  Future<void> _loadSettings() async {
    // Язык
    _languageCode = _prefs.getString('language_code') ?? 'ru';

    // PIN-код
    _isPinEnabled = _prefs.getBool('pin_enabled') ?? false;
    _useBiometrics = _prefs.getBool('use_biometrics') ?? false;

    // Облако
    _isCloudEnabled = _prefs.getBool('cloud_enabled') ?? false;
    if (_isCloudEnabled) {
      _cloudEndpoint = await _secureStorage.read(key: 'cloud_endpoint');
    }

    // Резервное копирование
    _autoBackup = _prefs.getBool('auto_backup') ?? false;
    final lastBackupMillis = _prefs.getInt('last_backup_time');
    if (lastBackupMillis != null) {
      _lastBackupTime = DateTime.fromMillisecondsSinceEpoch(lastBackupMillis);
    }

    // Уведомления
    _notificationsEnabled = _prefs.getBool('notifications_enabled') ?? true;
    _medicationReminders = _prefs.getBool('medication_reminders') ?? true;

    // Приватность
    _requirePinOnStart = _prefs.getBool('require_pin_on_start') ?? false;
    _hideDataInMultitasking = _prefs.getBool('hide_data_multitasking') ?? false;

    // Дети
    await loadChildren();

    notifyListeners();
  }

  // ==================== Сброс настроек ====================

  /// Сброс всех настроек к значениям по умолчанию
  Future<void> resetToDefaults() async {
    // Удаляем чувствительные данные
    await removePinCode();
    await removeCloudCredentials();

    // Сбрасываем обычные настройки
    await _prefs.clear();

    // Устанавливаем значения по умолчанию
    _languageCode = 'ru';
    _notificationsEnabled = true;
    _medicationReminders = true;
    _autoBackup = false;
    _requirePinOnStart = false;
    _hideDataInMultitasking = false;

    await _prefs.setString('language_code', 'ru');
    await _prefs.setBool('notifications_enabled', true);
    await _prefs.setBool('medication_reminders', true);

    notifyListeners();
  }
}
