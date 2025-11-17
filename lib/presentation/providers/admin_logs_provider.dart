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
