import 'dart:convert';
import 'dart:math';

/// Модель для двухфакторной аутентификации (2FA)
class TwoFactorAuth {
  final String secretKey;
  final bool isEnabled;
  final DateTime? enabledAt;
  final List<String> backupCodes;

  TwoFactorAuth({
    required this.secretKey,
    required this.isEnabled,
    this.enabledAt,
    this.backupCodes = const [],
  });

  /// Генерация случайного секретного ключа
  static String generateSecretKey() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final random = Random.secure();
    return List.generate(32, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Генерация резервных кодов
  static List<String> generateBackupCodes({int count = 10}) {
    final random = Random.secure();
    return List.generate(
      count,
      (_) => List.generate(8, (_) => random.nextInt(10)).join(),
    );
  }

  /// Проверка TOTP кода
  bool verifyCode(String code) {
    if (!isEnabled) return true; // Если 2FA отключена, всегда успешно

    // Проверка резервного кода
    if (backupCodes.contains(code)) {
      return true;
    }

    // Проверка TOTP кода
    final currentCode = _generateTOTP();
    final previousCode = _generateTOTP(offsetMinutes: -1);
    final nextCode = _generateTOTP(offsetMinutes: 1);

    return code == currentCode || code == previousCode || code == nextCode;
  }

  /// Генерация TOTP кода (упрощенная версия)
  String _generateTOTP({int offsetMinutes = 0}) {
    final timestamp = DateTime.now().add(Duration(minutes: offsetMinutes));
    final timeStep = timestamp.millisecondsSinceEpoch ~/ 30000; // 30 секунд

    // Простая хеш-функция (в продакшене использовать HMAC-SHA1)
    final hash = (secretKey.hashCode + timeStep).abs();
    final code = (hash % 1000000).toString().padLeft(6, '0');

    return code;
  }

  /// Получить текущий TOTP код (для отображения пользователю при настройке)
  String getCurrentCode() {
    return _generateTOTP();
  }

  /// Конвертация в JSON
  Map<String, dynamic> toJson() {
    return {
      'secretKey': secretKey,
      'isEnabled': isEnabled,
      'enabledAt': enabledAt?.toIso8601String(),
      'backupCodes': backupCodes,
    };
  }

  /// Создание из JSON
  factory TwoFactorAuth.fromJson(Map<String, dynamic> json) {
    return TwoFactorAuth(
      secretKey: json['secretKey'] as String,
      isEnabled: json['isEnabled'] as bool,
      enabledAt: json['enabledAt'] != null
          ? DateTime.parse(json['enabledAt'] as String)
          : null,
      backupCodes: (json['backupCodes'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  /// Включение 2FA
  TwoFactorAuth enable() {
    return TwoFactorAuth(
      secretKey: secretKey,
      isEnabled: true,
      enabledAt: DateTime.now(),
      backupCodes: backupCodes.isEmpty
          ? generateBackupCodes()
          : backupCodes,
    );
  }

  /// Отключение 2FA
  TwoFactorAuth disable() {
    return TwoFactorAuth(
      secretKey: secretKey,
      isEnabled: false,
      enabledAt: null,
      backupCodes: backupCodes,
    );
  }

  /// Использование резервного кода
  TwoFactorAuth useBackupCode(String code) {
    final newCodes = List<String>.from(backupCodes);
    newCodes.remove(code);

    return TwoFactorAuth(
      secretKey: secretKey,
      isEnabled: isEnabled,
      enabledAt: enabledAt,
      backupCodes: newCodes,
    );
  }

  /// Регенерация резервных кодов
  TwoFactorAuth regenerateBackupCodes() {
    return TwoFactorAuth(
      secretKey: secretKey,
      isEnabled: isEnabled,
      enabledAt: enabledAt,
      backupCodes: generateBackupCodes(),
    );
  }
}

/// Rate limiting для защиты от брутфорса
class RateLimiter {
  int attemptCount;
  DateTime? lockoutUntil;
  DateTime? windowStart;

  static const int maxAttempts = 5;
  static const Duration windowDuration = Duration(minutes: 15);
  static const Duration lockoutDuration = Duration(minutes: 15);

  RateLimiter({
    this.attemptCount = 0,
    this.lockoutUntil,
    this.windowStart,
  });

  /// Проверка, заблокирован ли доступ
  bool get isLockedOut {
    if (lockoutUntil == null) return false;
    return DateTime.now().isBefore(lockoutUntil!);
  }

  /// Оставшееся время блокировки
  Duration? get remainingLockoutTime {
    if (!isLockedOut) return null;
    return lockoutUntil!.difference(DateTime.now());
  }

  /// Регистрация неудачной попытки
  RateLimiter recordFailedAttempt() {
    final now = DateTime.now();

    // Если прошло больше времени окна, сбрасываем счетчик
    if (windowStart == null ||
        now.difference(windowStart!) > windowDuration) {
      return RateLimiter(
        attemptCount: 1,
        windowStart: now,
      );
    }

    // Увеличиваем счетчик
    final newCount = attemptCount + 1;

    // Если превысили лимит, блокируем
    if (newCount >= maxAttempts) {
      return RateLimiter(
        attemptCount: newCount,
        windowStart: windowStart,
        lockoutUntil: now.add(lockoutDuration),
      );
    }

    return RateLimiter(
      attemptCount: newCount,
      windowStart: windowStart,
      lockoutUntil: lockoutUntil,
    );
  }

  /// Сброс после успешного входа
  RateLimiter reset() {
    return RateLimiter();
  }

  /// Оставшееся количество попыток
  int get remainingAttempts {
    if (isLockedOut) return 0;

    final now = DateTime.now();
    if (windowStart == null ||
        now.difference(windowStart!) > windowDuration) {
      return maxAttempts;
    }

    return maxAttempts - attemptCount;
  }

  /// Конвертация в JSON
  Map<String, dynamic> toJson() {
    return {
      'attemptCount': attemptCount,
      'lockoutUntil': lockoutUntil?.toIso8601String(),
      'windowStart': windowStart?.toIso8601String(),
    };
  }

  /// Создание из JSON
  factory RateLimiter.fromJson(Map<String, dynamic> json) {
    return RateLimiter(
      attemptCount: json['attemptCount'] as int? ?? 0,
      lockoutUntil: json['lockoutUntil'] != null
          ? DateTime.parse(json['lockoutUntil'] as String)
          : null,
      windowStart: json['windowStart'] != null
          ? DateTime.parse(json['windowStart'] as String)
          : null,
    );
  }
}
