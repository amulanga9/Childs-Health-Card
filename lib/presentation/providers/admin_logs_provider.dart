import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/activity_log.dart';

/// Провайдер для управления логами активности администратора
///
/// Хранит историю действий и позволяет фильтровать/экспортировать логи
class AdminLogsProvider with ChangeNotifier {
  final SharedPreferences _prefs;
  final List<ActivityLog> _logs = [];

  static const String _logsKey = 'admin_activity_logs';
  static const int _maxLogs = 1000; // Максимум логов в памяти

  int _nextId = 1;

  AdminLogsProvider({required SharedPreferences prefs}) : _prefs = prefs {
    _loadLogs();
  }

  // Getters
  List<ActivityLog> get logs => List.unmodifiable(_logs);
  int get logsCount => _logs.length;

  /// Загрузка логов из SharedPreferences
  Future<void> _loadLogs() async {
    try {
      final logsJson = _prefs.getString(_logsKey);
      if (logsJson != null) {
        final List<dynamic> decoded = jsonDecode(logsJson);
        _logs.clear();
        _logs.addAll(
          decoded.map((json) => ActivityLog.fromJson(json)).toList(),
        );

        // Обновляем счетчик ID
        if (_logs.isNotEmpty) {
          _nextId = _logs.map((log) => log.id).reduce((a, b) => a > b ? a : b) + 1;
        }

        debugPrint('📋 Loaded ${_logs.length} activity logs');
      }
    } catch (e) {
      debugPrint('❌ Error loading activity logs: $e');
    }
    notifyListeners();
  }

  /// Сохранение логов в SharedPreferences
  Future<void> _saveLogs() async {
    try {
      final logsJson = jsonEncode(
        _logs.map((log) => log.toJson()).toList(),
      );
      await _prefs.setString(_logsKey, logsJson);
    } catch (e) {
      debugPrint('❌ Error saving activity logs: $e');
    }
  }

  /// Добавление нового лога
  Future<void> addLog({
    required String action,
    required String entityType,
    required String adminName,
    int? entityId,
    String? entityName,
    Map<String, dynamic>? changes,
  }) async {
    final log = ActivityLog(
      id: _nextId++,
      action: action,
      entityType: entityType,
      entityId: entityId,
      entityName: entityName,
      adminName: adminName,
      timestamp: DateTime.now(),
      changes: changes,
    );

    _logs.insert(0, log); // Добавляем в начало (новые сверху)

    // Ограничиваем количество логов
    if (_logs.length > _maxLogs) {
      _logs.removeLast();
    }

    await _saveLogs();
    debugPrint('📝 ${log.actionIcon} ${log.description}');
    notifyListeners();
  }

  // ============== Логи безопасности ==============

  /// Добавление лога неудачной попытки входа
  Future<void> addFailedLoginLog(String adminName, {String? reason}) async {
    await addLog(
      action: 'failed_login',
      entityType: 'security',
      adminName: adminName,
      entityName: reason ?? 'Неверный пароль',
    );
  }

  /// Добавление лога блокировки из-за превышения попыток
  Future<void> addLockoutLog(String adminName, Duration lockoutDuration) async {
    await addLog(
      action: 'lockout',
      entityType: 'security',
      adminName: adminName,
      entityName: 'Блокировка на ${lockoutDuration.inMinutes} мин',
      changes: {
        'lockout_duration_minutes': lockoutDuration.inMinutes,
      },
    );
  }

  /// Добавление лога включения 2FA
  Future<void> addEnable2FALog(String adminName) async {
    await addLog(
      action: 'enable_2fa',
      entityType: 'security',
      adminName: adminName,
      entityName: 'Двухфакторная аутентификация включена',
    );
  }

  /// Добавление лога отключения 2FA
  Future<void> addDisable2FALog(String adminName) async {
    await addLog(
      action: 'disable_2fa',
      entityType: 'security',
      adminName: adminName,
      entityName: 'Двухфакторная аутентификация отключена',
    );
  }

  /// Добавление лога смены роли
  Future<void> addChangeRoleLog(
    String adminName,
    String oldRole,
    String newRole,
  ) async {
    await addLog(
      action: 'change_role',
      entityType: 'security',
      adminName: adminName,
      entityName: 'Смена роли: $oldRole → $newRole',
      changes: {
        'old_role': oldRole,
        'new_role': newRole,
      },
    );
  }

  /// Добавление лога смены пароля
  Future<void> addChangePasswordLog(String adminName) async {
    await addLog(
      action: 'change_password',
      entityType: 'security',
      adminName: adminName,
      entityName: 'Пароль изменён',
    );
  }

  /// Добавление лога сброса пароля
  Future<void> addResetPasswordLog(String adminName) async {
    await addLog(
      action: 'reset_password',
      entityType: 'security',
      adminName: adminName,
      entityName: 'Пароль сброшен к значению по умолчанию',
    );
  }

  /// Добавление лога использования резервного кода 2FA
  Future<void> addBackupCodeUsedLog(String adminName) async {
    await addLog(
      action: 'backup_code_used',
      entityType: 'security',
      adminName: adminName,
      entityName: 'Использован резервный код 2FA',
    );
  }

  /// Фильтрация логов безопасности
  List<ActivityLog> getSecurityLogs() {
    const securityActions = [
      'failed_login',
      'lockout',
      'enable_2fa',
      'disable_2fa',
      'change_role',
      'change_password',
      'reset_password',
      'backup_code_used',
      'login',
      'logout',
    ];

    return _logs.where((log) {
      return securityActions.contains(log.action) ||
          log.entityType == 'security';
    }).toList();
  }

  /// Получение логов неудачных попыток входа
  List<ActivityLog> getFailedLoginLogs({int days = 7}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _logs.where((log) {
      return log.action == 'failed_login' && log.timestamp.isAfter(cutoff);
    }).toList();
  }

  /// Проверка подозрительной активности (много неудачных попыток входа)
  bool hasSuspiciousActivity({int threshold = 10, int hours = 24}) {
    final cutoff = DateTime.now().subtract(Duration(hours: hours));
    final failedLogins = _logs.where((log) {
      return log.action == 'failed_login' && log.timestamp.isAfter(cutoff);
    }).length;

    return failedLogins >= threshold;
  }

  /// Экспорт логов безопасности в JSON
  String exportSecurityLogsToJson() {
    final securityLogs = getSecurityLogs();
    return jsonEncode({
      'exported_at': DateTime.now().toIso8601String(),
      'logs_count': securityLogs.length,
      'logs': securityLogs.map((log) => log.toJson()).toList(),
    });
  }

  /// Экспорт логов безопасности в CSV
  String exportSecurityLogsToCsv() {
    final securityLogs = getSecurityLogs();
    final buffer = StringBuffer();

    // Заголовки
    buffer.writeln(
      'ID,Действие,Администратор,Описание,Дата и время,Изменения',
    );

    // Данные
    for (final log in securityLogs) {
      buffer.writeln(
        '${log.id},${log.action},${log.adminName},"${log.entityName ?? ""}",${log.timestamp},"${log.changes ?? ""}"',
      );
    }

    return buffer.toString();
  }

  /// Фильтрация логов по действию
  List<ActivityLog> filterByAction(String action) {
    return _logs.where((log) => log.action == action).toList();
  }

  /// Фильтрация логов по типу сущности
  List<ActivityLog> filterByEntityType(String entityType) {
    return _logs.where((log) => log.entityType == entityType).toList();
  }

  /// Фильтрация логов по администратору
  List<ActivityLog> filterByAdmin(String adminName) {
    return _logs.where((log) => log.adminName == adminName).toList();
  }

  /// Фильтрация логов по дате
  List<ActivityLog> filterByDateRange(DateTime start, DateTime end) {
    return _logs.where((log) {
      return log.timestamp.isAfter(start) && log.timestamp.isBefore(end);
    }).toList();
  }

  /// Фильтрация логов по дню
  List<ActivityLog> filterByDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return filterByDateRange(start, end);
  }

  /// Поиск логов по тексту
  List<ActivityLog> search(String query) {
    final lowerQuery = query.toLowerCase();
    return _logs.where((log) {
      return log.description.toLowerCase().contains(lowerQuery) ||
          log.adminName.toLowerCase().contains(lowerQuery) ||
          (log.entityName?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  /// Получение логов за последние N дней
  List<ActivityLog> getRecentLogs({int days = 7}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _logs.where((log) => log.timestamp.isAfter(cutoff)).toList();
  }

  /// Получение статистики по действиям
  Map<String, int> getActionStats() {
    final stats = <String, int>{};
    for (final log in _logs) {
      stats[log.action] = (stats[log.action] ?? 0) + 1;
    }
    return stats;
  }

  /// Получение статистики по типам сущностей
  Map<String, int> getEntityTypeStats() {
    final stats = <String, int>{};
    for (final log in _logs) {
      stats[log.entityType] = (stats[log.entityType] ?? 0) + 1;
    }
    return stats;
  }

  /// Получение топ администраторов по активности
  Map<String, int> getAdminActivityStats() {
    final stats = <String, int>{};
    for (final log in _logs) {
      stats[log.adminName] = (stats[log.adminName] ?? 0) + 1;
    }
    return stats;
  }

  /// Экспорт логов в JSON
  String exportToJson() {
    return jsonEncode({
      'exported_at': DateTime.now().toIso8601String(),
      'logs_count': _logs.length,
      'logs': _logs.map((log) => log.toJson()).toList(),
    });
  }

  /// Экспорт логов в CSV
  String exportToCsv() {
    final buffer = StringBuffer();

    // Заголовки
    buffer.writeln(
      'ID,Действие,Тип сущности,ID сущности,Название сущности,Администратор,Дата и время',
    );

    // Данные
    for (final log in _logs) {
      buffer.writeln(
        '${log.id},${log.action},${log.entityType},${log.entityId ?? ""},${log.entityName ?? ""},${log.adminName},${log.timestamp}',
      );
    }

    return buffer.toString();
  }

  /// Очистка всех логов
  Future<void> clearAllLogs() async {
    _logs.clear();
    _nextId = 1;
    await _prefs.remove(_logsKey);
    debugPrint('🗑️ All activity logs cleared');
    notifyListeners();
  }

  /// Очистка старых логов (старше N дней)
  Future<void> clearOldLogs({int days = 90}) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final before = _logs.length;

    _logs.removeWhere((log) => log.timestamp.isBefore(cutoff));

    if (_logs.length < before) {
      await _saveLogs();
      debugPrint('🗑️ Cleared ${before - _logs.length} old logs');
      notifyListeners();
    }
  }
}
