import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/activity_log.dart';

/// Простой провайдер логов (без лишней сложности)
class AdminLogsProvider with ChangeNotifier {
  final SharedPreferences _prefs;
  final List<ActivityLog> _logs = [];
  int _nextId = 1;

  static const _key = 'admin_logs';
  static const _maxLogs = 500; // Уменьшил с 1000

  AdminLogsProvider({required SharedPreferences prefs}) : _prefs = prefs {
    _load();
  }

  List<ActivityLog> get logs => List.unmodifiable(_logs);
  int get count => _logs.length;

  Future<void> _load() async {
    final json = _prefs.getString(_key);
    if (json != null) {
      try {
        final list = jsonDecode(json) as List;
        _logs.addAll(list.map((e) => ActivityLog.fromJson(e)));
        if (_logs.isNotEmpty) {
          _nextId = _logs.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1;
        }
      } catch (e) {
        debugPrint('Ошибка загрузки логов: $e');
      }
    }
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final json = jsonEncode(_logs.map((e) => e.toJson()).toList());
      await _prefs.setString(_key, json);
    } catch (e) {
      debugPrint('Ошибка сохранения логов: $e');
    }
  }

  /// Добавить лог с валидацией
  Future<void> add({
    required String action,
    required String entityType,
    required String adminName,
    int? entityId,
    String? entityName,
  }) async {
    // Валидация входных данных
    if (action.isEmpty || entityType.isEmpty || adminName.isEmpty) {
      debugPrint('Предупреждение: попытка добавить лог с пустыми полями');
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

    // Ограничиваем размер логов
    if (_logs.length > _maxLogs) {
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

  /// Экспорт в CSV с правильным экранированием
  String exportCsv() {
    final buf = StringBuffer();
    buf.writeln('ID,Действие,Тип,Администратор,Время');

    for (final log in _logs) {
      // Экранируем каждое поле для защиты от CSV injection
      buf.writeln([
        log.id.toString(),
        _escapeCsv(log.action),
        _escapeCsv(log.entityType),
        _escapeCsv(log.adminName),
        log.timestamp.toIso8601String(),
      ].join(','));
    }

    return buf.toString();
  }

  /// Экранирование значений для CSV (защита от injection)
  String _escapeCsv(String value) {
    // Если содержит запятую, кавычки или перевод строки - оборачиваем в кавычки
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      // Удваиваем кавычки внутри и оборачиваем в кавычки
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  Future<void> clearAll() async {
    _logs.clear();
    _nextId = 1;
    await _prefs.remove(_key);
    notifyListeners();
  }

  Future<void> clearOld({int days = 90}) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    _logs.removeWhere((log) => log.timestamp.isBefore(cutoff));
    await _save();
    notifyListeners();
  }
}
