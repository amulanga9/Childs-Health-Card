/// Роли администратора
enum AdminRole {
  admin('Admin', 'Администратор'),
  moderator('Moderator', 'Модератор'),
  viewer('Viewer', 'Наблюдатель');

  final String code;
  final String displayName;

  const AdminRole(this.code, this.displayName);

  static AdminRole fromCode(String code) {
    return AdminRole.values.firstWhere(
      (role) => role.code == code,
      orElse: () => AdminRole.viewer,
    );
  }
}

/// Права доступа для различных ролей
class AdminPermissions {
  final AdminRole role;

  AdminPermissions(this.role);

  // ============== Просмотр ==============

  /// Может просматривать данные
  bool get canView => true; // Все роли могут просматривать

  /// Может просматривать логи
  bool get canViewLogs => true; // Все роли могут просматривать логи

  /// Может просматривать статистику
  bool get canViewStats => true; // Все роли могут просматривать статистику

  // ============== Создание ==============

  /// Может создавать детей
  bool get canCreateChild => role == AdminRole.admin || role == AdminRole.moderator;

  /// Может создавать эпизоды
  bool get canCreateEpisode => role == AdminRole.admin || role == AdminRole.moderator;

  // ============== Изменение ==============

  /// Может редактировать детей
  bool get canUpdateChild => role == AdminRole.admin || role == AdminRole.moderator;

  /// Может редактировать эпизоды
  bool get canUpdateEpisode => role == AdminRole.admin || role == AdminRole.moderator;

  /// Может изменять настройки
  bool get canUpdateSettings => role == AdminRole.admin;

  // ============== Удаление ==============

  /// Может удалять детей
  bool get canDeleteChild => role == AdminRole.admin;

  /// Может удалять эпизоды
  bool get canDeleteEpisode => role == AdminRole.admin;

  /// Может очищать логи
  bool get canClearLogs => role == AdminRole.admin;

  // ============== Экспорт ==============

  /// Может экспортировать данные
  bool get canExport => role == AdminRole.admin || role == AdminRole.moderator;

  /// Может экспортировать логи безопасности
  bool get canExportSecurityLogs => role == AdminRole.admin;

  // ============== Безопасность ==============

  /// Может управлять 2FA
  bool get canManage2FA => role == AdminRole.admin;

  /// Может менять роли
  bool get canManageRoles => role == AdminRole.admin;

  /// Может сбрасывать пароль
  bool get canResetPassword => role == AdminRole.admin;

  // ============== Пользователи ==============

  /// Может управлять пользователями
  bool get canManageUsers => role == AdminRole.admin;

  // ============== Вспомогательные методы ==============

  /// Проверка прав на действие
  bool hasPermission(String action) {
    switch (action) {
      // Просмотр
      case 'view':
        return canView;
      case 'view_logs':
        return canViewLogs;
      case 'view_stats':
        return canViewStats;

      // Создание
      case 'create_child':
        return canCreateChild;
      case 'create_episode':
        return canCreateEpisode;

      // Изменение
      case 'update_child':
        return canUpdateChild;
      case 'update_episode':
        return canUpdateEpisode;
      case 'update_settings':
        return canUpdateSettings;

      // Удаление
      case 'delete_child':
        return canDeleteChild;
      case 'delete_episode':
        return canDeleteEpisode;
      case 'clear_logs':
        return canClearLogs;

      // Экспорт
      case 'export':
        return canExport;
      case 'export_security_logs':
        return canExportSecurityLogs;

      // Безопасность
      case 'manage_2fa':
        return canManage2FA;
      case 'manage_roles':
        return canManageRoles;
      case 'reset_password':
        return canResetPassword;

      // Пользователи
      case 'manage_users':
        return canManageUsers;

      default:
        return false;
    }
  }

  /// Получить описание роли
  String get roleDescription {
    switch (role) {
      case AdminRole.admin:
        return 'Полный доступ ко всем функциям';
      case AdminRole.moderator:
        return 'Просмотр и редактирование (без удаления)';
      case AdminRole.viewer:
        return 'Только просмотр данных';
    }
  }

  /// Получить список доступных действий
  List<String> get availableActions {
    final actions = <String>[];

    if (canView) actions.add('Просмотр данных');
    if (canViewLogs) actions.add('Просмотр логов');
    if (canCreateChild) actions.add('Создание профилей');
    if (canUpdateChild) actions.add('Редактирование');
    if (canDeleteChild) actions.add('Удаление');
    if (canExport) actions.add('Экспорт данных');
    if (canManage2FA) actions.add('Управление 2FA');
    if (canManageRoles) actions.add('Управление ролями');

    return actions;
  }
}
