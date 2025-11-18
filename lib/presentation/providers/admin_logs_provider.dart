import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/activity_log.dart';

/// Провайдер логов админ-панели
class AdminLogsProvider with ChangeNotifier {
  // Зависимости
  final SharedPreferences _prefs;

  // Константы
  static const _storageKey = 'admin_logs';
  static const _maxLogsCount = 500;
  static const _csvSeparator = ',';
  static const _csvQuote = '"';

  // Состояние
  final List<ActivityLog> _logs = [];
  int _nextId = 1;

  AdminLogsProvider({required SharedPreferences prefs}) : _prefs = prefs {
    _load();
  }

  List<ActivityLog> get logs => List.unmodifiable(_logs);
  int get count => _logs.length;

  Future<void> _load() async {
    final json = _prefs.getString(_storageKey);
    if (json == null) return;

    try {
      final list = jsonDecode(json) as List;
      _logs.addAll(list.map((e) => ActivityLog.fromJson(e)));

      if (_logs.isNotEmpty) {
        _nextId = _logs.fold(0, (max, log) => log.id > max ? log.id : max) + 1;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Ошибка загрузки логов: $e');
    }
  }

  Future<void> _save() async {
    try {
      final json = jsonEncode(_logs.map((e) => e.toJson()).toList());
      await _prefs.setString(_storageKey, json);
    } catch (e) {
      debugPrint('Ошибка сохранения логов: $e');
    }
  }

  /// Добавить лог
  Future<void> add({
    required String action,
    required String entityType,
    required String adminName,
    int? entityId,
    String? entityName,
  }) async {
    // Валидация
    if (action.isEmpty || entityType.isEmpty || adminName.isEmpty) {
      debugPrint('Попытка добавить лог с пустыми полями');
      return;
    }

    final log = ActivityLog(
      id: _nextId++,
      action: action,
      entityType: entityType,
      entityId: entityId,
      entityName: entityName,
      adminName: adminName,
      timestamp: DateTime.now(),
    );

    _logs.insert(0, log);

    // Ограничение размера
    if (_logs.length > _maxLogsCount) {
      _logs.removeLast();
    }

    await _save();
    notifyListeners();
  }

  // Простые методы фильтрации
  List<ActivityLog> search(String query) {
    if (query.isEmpty) return logs;
    final q = query.toLowerCase();
    return _logs.where((log) {
      return log.description.toLowerCase().contains(q) ||
          log.adminName.toLowerCase().contains(q);
    }).toList();
  }

  List<ActivityLog> recent({int days = 7}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _logs.where((log) => log.timestamp.isAfter(cutoff)).toList();
  }

  List<ActivityLog> byDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(Duration(days: 1));
    return _logs.where((log) {
      return log.timestamp.isAfter(start) && log.timestamp.isBefore(end);
    }).toList();
  }

  // Простой экспорт
  String exportJson() {
    return jsonEncode({
      'exported_at': DateTime.now().toIso8601String(),
      'count': _logs.length,
      'logs': _logs.map((e) => e.toJson()).toList(),
    });
  }

  /// Экспорт в CSV с экранированием
  String exportCsv() {
    final header = ['ID', 'Действие', 'Тип', 'Администратор', 'Время']
        .join(_csvSeparator);

    final rows = _logs.map((log) {
      return [
        log.id.toString(),
        _escapeCsv(log.action),
        _escapeCsv(log.entityType),
        _escapeCsv(log.adminName),
        log.timestamp.toIso8601String(),
      ].join(_csvSeparator);
    });

    return [header, ...rows].join('\n');
  }

  /// Экранирование для CSV (защита от injection)
  String _escapeCsv(String value) {
    final needsQuotes = value.contains(_csvSeparator) ||
        value.contains(_csvQuote) ||
        value.contains('\n');

    if (!needsQuotes) return value;

    final escaped = value.replaceAll(_csvQuote, _csvQuote * 2);
    return '$_csvQuote$escaped$_csvQuote';
  }

  Future<void> clearAll() async {
    _logs.clear();
    _nextId = 1;
    await _prefs.remove(_storageKey);
    notifyListeners();
  }

  Future<void> clearOld({int days = 90}) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    _logs.removeWhere((log) => log.timestamp.isBefore(cutoff));
    await _save();
    notifyListeners();
  }
}
