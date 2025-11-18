/// Модели безопасности админ-панели
library;

import 'dart:math';

/// Роли администратора
class AdminRole {
  // Константы ролей
  static const String admin = 'admin';
  static const String moderator = 'moderator';
  static const String viewer = 'viewer';

  // Приватный конструктор - класс только для констант
  AdminRole._();

  static String getDisplayName(String role) {
    switch (role) {
      case admin:
        return 'Администратор';
      case moderator:
        return 'Модератор';
      case viewer:
        return 'Наблюдатель';
      default:
        return role;
    }
  }

  static bool isValid(String role) {
    return role == admin || role == moderator || role == viewer;
  }
}

/// Права доступа по ролям
class Permissions {
  final String role;

  Permissions(this.role);

  bool get canDelete => role == AdminRole.admin;
  bool get canEdit => role == AdminRole.admin || role == AdminRole.moderator;
  bool get canView => true;
  bool get canExport => role == AdminRole.admin || role == AdminRole.moderator;
  bool get isAdmin => role == AdminRole.admin;
}

/// Ограничитель попыток входа (rate limiter)
class SimpleRateLimiter {
  // Константы
  static const int maxAttempts = 5;
  static const int lockDurationMinutes = 15;

  // Состояние
  int failedAttempts = 0;
  DateTime? lockUntil;

  bool get isLocked {
    if (lockUntil == null) return false;

    if (DateTime.now().isAfter(lockUntil!)) {
      reset();
      return false;
    }

    return true;
  }

  int get remainingAttempts => isLocked ? 0 : (maxAttempts - failedAttempts);

  String? get lockTimeRemaining {
    if (lockUntil == null) return null;

    final diff = lockUntil!.difference(DateTime.now());
    if (diff.isNegative) return null;

    final minutes = diff.inMinutes;
    final seconds = diff.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void recordFail() {
    failedAttempts++;

    if (failedAttempts >= maxAttempts) {
      lockUntil = DateTime.now().add(Duration(minutes: lockDurationMinutes));
    }
  }

  void reset() {
    failedAttempts = 0;
    lockUntil = null;
  }

  // Сериализация
  Map<String, dynamic> toJson() => {
        'attempts': failedAttempts,
        'lockUntil': lockUntil?.toIso8601String(),
      };

  factory SimpleRateLimiter.fromJson(Map<String, dynamic>? json) {
    if (json == null) return SimpleRateLimiter();

    return SimpleRateLimiter()
      ..failedAttempts = json['attempts'] ?? 0
      ..lockUntil =
          json['lockUntil'] != null ? DateTime.parse(json['lockUntil']) : null;
  }
}

/// Второй фактор аутентификации (PIN + резервные коды)
class SecondFactor {
  // Константы
  static const int pinLength = 4;
  static const int backupCodesCount = 5;
  static const int backupCodeLength = 5;

  // Данные
  final String pinCode;
  final bool enabled;
  final List<String> backupCodes;

  SecondFactor({
    required this.pinCode,
    this.enabled = false,
    this.backupCodes = const [],
  });

  /// Результат проверки кода
  /// Возвращает: (успех, использованный backup code или null)
  (bool, String?) verifyCode(String code) {
    if (!enabled) return (true, null);

    // Проверка PIN
    if (code == pinCode) return (true, null);

    // Проверка backup кодов
    if (backupCodes.contains(code)) return (true, code);

    return (false, null);
  }

  /// Создать копию с удаленным backup кодом
  SecondFactor removeBackupCode(String code) {
    return SecondFactor(
      pinCode: pinCode,
      enabled: enabled,
      backupCodes: backupCodes.where((c) => c != code).toList(),
    );
  }

  // Генерация безопасных кодов
  static String generatePin() {
    final random = Random.secure();
    final pin = 1000 + random.nextInt(9000); // 1000-9999
    return pin.toString();
  }

  static List<String> generateBackupCodes() {
    final random = Random.secure();
    final codes = <String>{};

    while (codes.length < backupCodesCount) {
      final code = 10000 + random.nextInt(90000); // 10000-99999
      codes.add(code.toString());
    }

    return codes.toList();
  }

  // Сериализация
  Map<String, dynamic> toJson() => {
        'pin': pinCode,
        'enabled': enabled,
        'backups': backupCodes,
      };

  factory SecondFactor.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return SecondFactor(pinCode: '', enabled: false);
    }

    return SecondFactor(
      pinCode: json['pin'] ?? '',
      enabled: json['enabled'] ?? false,
      backupCodes: (json['backups'] as List?)?.cast<String>() ?? [],
    );
  }
}

