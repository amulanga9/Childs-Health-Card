/// Модель для логирования активности администратора
///
/// Хранит информацию о действиях, выполненных в админке
class ActivityLog {
  final int id;
  final String action; // create, update, delete, login, etc.
  final String entityType; // child, episode, prescription, etc.
  final int? entityId;
  final String? entityName;
  final String adminName;
  final DateTime timestamp;
  final Map<String, dynamic>? changes; // До/после изменений

  ActivityLog({
    required this.id,
    required this.action,
    required this.entityType,
    this.entityId,
    this.entityName,
    required this.adminName,
    required this.timestamp,
    this.changes,
  });

  /// Фабрика для создания из JSON
  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: json['id'] as int,
      action: json['action'] as String,
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as int?,
      entityName: json['entity_name'] as String?,
      adminName: json['admin_name'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      changes: json['changes'] as Map<String, dynamic>?,
    );
  }

  /// Конвертация в JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'action': action,
      'entity_type': entityType,
      'entity_id': entityId,
      'entity_name': entityName,
      'admin_name': adminName,
      'timestamp': timestamp.toIso8601String(),
      'changes': changes,
    };
  }

  /// Человекочитаемое описание действия
  String get description {
    final actionRu = _actionToRussian(action);
    final entityRu = _entityTypeToRussian(entityType);

    if (entityName != null) {
      return '$actionRu: $entityRu "$entityName"';
    } else if (entityId != null) {
      return '$actionRu: $entityRu #$entityId';
    } else {
      return '$actionRu: $entityRu';
    }
  }

  /// Иконка для типа действия
  String get actionIcon {
    switch (action) {
      case 'create':
        return '➕';
      case 'update':
        return '✏️';
      case 'delete':
        return '🗑️';
      case 'login':
        return '🔑';
      case 'logout':
        return '🚪';
      case 'export':
        return '📤';
      case 'import':
        return '📥';
      case 'backup':
        return '💾';
      default:
        return '📝';
    }
  }

  String _actionToRussian(String action) {
    switch (action) {
      case 'create':
        return 'Создание';
      case 'update':
        return 'Обновление';
      case 'delete':
        return 'Удаление';
      case 'login':
        return 'Вход';
      case 'logout':
        return 'Выход';
      case 'export':
        return 'Экспорт';
      case 'import':
        return 'Импорт';
      case 'backup':
        return 'Резервная копия';
      default:
        return action;
    }
  }

  String _entityTypeToRussian(String entityType) {
    switch (entityType) {
      case 'child':
        return 'Ребенок';
      case 'episode':
        return 'Эпизод болезни';
      case 'prescription':
        return 'Назначение';
      case 'intake':
        return 'Прием лекарства';
      case 'test':
        return 'Анализ';
      case 'procedure':
        return 'Процедура';
      case 'attachment':
        return 'Файл';
      case 'user':
        return 'Пользователь';
      case 'settings':
        return 'Настройки';
      case 'system':
        return 'Система';
      default:
        return entityType;
    }
  }

  @override
  String toString() {
    return 'ActivityLog(action: $action, entity: $entityType, at: $timestamp)';
  }
}
