/// Упрощенная модель безопасности админ-панели
library;

import 'dart:math';

/// Простые роли админа (без сложного enum)
class AdminRole {
  static const String admin = 'admin';
  static const String moderator = 'moderator';
  static const String viewer = 'viewer';

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

  /// Валидация роли
  static bool isValid(String role) {
    return role == admin || role == moderator || role == viewer;
  }
}

/// Простая проверка прав (без сложного класса)
class Permissions {
  final String role;

  Permissions(this.role);

  bool get canDelete => role == AdminRole.admin;
  bool get canEdit => role == AdminRole.admin || role == AdminRole.moderator;
  bool get canView => true;
  bool get canExport => role == AdminRole.admin || role == AdminRole.moderator;
  bool get isAdmin => role == AdminRole.admin;
}

/// Простой rate limiter (вместо сложного с окнами времени)
class SimpleRateLimiter {
  int failedAttempts = 0;
  DateTime? lockUntil;

  static const maxAttempts = 5;
  static const lockMinutes = 15;

  bool get isLocked {
    if (lockUntil == null) return false;
    if (DateTime.now().isAfter(lockUntil!)) {
      reset(); // Авто-сброс
      return false;
    }
    return true;
  }

  int get remainingAttempts => isLocked ? 0 : (maxAttempts - failedAttempts);

  void recordFail() {
    failedAttempts++;
    if (failedAttempts >= maxAttempts) {
      lockUntil = DateTime.now().add(Duration(minutes: lockMinutes));
    }
  }

  void reset() {
    failedAttempts = 0;
    lockUntil = null;
  }

  String? get lockTimeRemaining {
    if (lockUntil == null) return null;
    final diff = lockUntil!.difference(DateTime.now());
    // Защита от race condition - если время истекло, возвращаем null
    if (diff.isNegative) return null;
    final minutes = diff.inMinutes;
    final seconds = diff.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() => {
        'attempts': failedAttempts,
        'lockUntil': lockUntil?.toIso8601String(),
      };

  factory SimpleRateLimiter.fromJson(Map<String, dynamic>? json) {
    if (json == null) return SimpleRateLimiter();
    return SimpleRateLimiter()
      ..failedAttempts = json['attempts'] ?? 0
      ..lockUntil = json['lockUntil'] != null ? DateTime.parse(json['lockUntil']) : null;
  }
}

/// Простой second factor (вместо сложного TOTP)
class SecondFactor {
  final String pinCode; // Просто 4 цифры
  final bool enabled;
  final List<String> backupCodes; // 5 уникальных случайных кодов

  SecondFactor({
    required this.pinCode,
    this.enabled = false,
    this.backupCodes = const [],
  });

  /// Проверка кода (PIN или backup)
  /// Возвращает: (успех, использованный backup code или null)
  (bool, String?) verifyWithUsage(String code) {
    if (!enabled) return (true, null);

    if (code == pinCode) {
      return (true, null); // PIN не удаляется
    }

    if (backupCodes.contains(code)) {
      return (true, code); // Backup код нужно удалить
    }

    return (false, null);
  }

  /// Простая проверка без отслеживания использования (для обратной совместимости)
  bool verify(String code) {
    return verifyWithUsage(code).$1;
  }

  /// Удалить использованный backup код
  SecondFactor removeBackupCode(String code) {
    return SecondFactor(
      pinCode: pinCode,
      enabled: enabled,
      backupCodes: backupCodes.where((c) => c != code).toList(),
    );
  }

  /// Генерация криптографически безопасного PIN
  static String generatePin() {
    final random = Random.secure();
    // Генерируем случайное 4-значное число от 1000 до 9999
    final pin = 1000 + random.nextInt(9000);
    return pin.toString();
  }

  /// Генерация уникальных криптографически безопасных backup кодов
  static List<String> generateBackups() {
    final random = Random.secure();
    final codes = <String>{};

    // Генерируем 5 уникальных 5-значных кодов
    while (codes.length < 5) {
      final code = 10000 + random.nextInt(90000);
      codes.add(code.toString());
    }

    return codes.toList();
  }

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
