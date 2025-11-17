/// Упрощенная модель безопасности админ-панели
library;

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
    if (!isLocked) return null;
    final diff = lockUntil!.difference(DateTime.now());
    return '${diff.inMinutes}:${(diff.inSeconds % 60).toString().padLeft(2, '0')}';
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
  final List<String> backupCodes; // 5 простых кодов

  SecondFactor({
    required this.pinCode,
    this.enabled = false,
    this.backupCodes = const [],
  });

  bool verify(String code) {
    if (!enabled) return true;
    return code == pinCode || backupCodes.contains(code);
  }

  static String generatePin() {
    return (1000 + DateTime.now().millisecondsSinceEpoch % 9000).toString();
  }

  static List<String> generateBackups() {
    return List.generate(5, (i) => (10000 + i * 1111).toString());
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
