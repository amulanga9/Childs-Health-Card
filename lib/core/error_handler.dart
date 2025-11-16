import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';

/// Глобальный обработчик ошибок для приложения
///
/// Перехватывает все необработанные исключения и ошибки Flutter
class ErrorHandler {
  /// Инициализация глобального обработчика ошибок
  ///
  /// Вызовите это в main() перед runApp()
  static void initialize() {
    // Обработка ошибок Flutter framework
    FlutterError.onError = (FlutterErrorDetails details) {
      // Показываем стандартное красное окно с ошибкой в debug mode
      FlutterError.presentError(details);

      // Логируем в консоль
      debugPrint('━' * 80);
      debugPrint('Flutter Error caught by ErrorHandler:');
      debugPrint('Exception: ${details.exception}');
      debugPrint('Stack trace:');
      debugPrint(details.stack.toString());
      debugPrint('━' * 80);

      // TODO: Отправка в систему мониторинга (Firebase Crashlytics, Sentry)
      // Example:
      // FirebaseCrashlytics.instance.recordFlutterError(details);
    };

    // Обработка асинхронных ошибок вне Flutter framework
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('━' * 80);
      debugPrint('Uncaught Error caught by ErrorHandler:');
      debugPrint('Error: $error');
      debugPrint('Stack trace:');
      debugPrint(stack.toString());
      debugPrint('━' * 80);

      // TODO: Отправка в систему мониторинга
      // Example:
      // FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);

      return true; // Ошибка обработана
    };

    debugPrint('✅ Global error handler initialized');
  }

  /// Wrapper для запуска приложения с обработкой ошибок в зоне
  ///
  /// Использование:
  /// ```dart
  /// ErrorHandler.runAppWithErrorHandling(() => runApp(MyApp()));
  /// ```
  static void runAppWithErrorHandling(void Function() appRunner) {
    runZonedGuarded<void>(
      () {
        // Инициализируем обработчик
        initialize();

        // Запускаем приложение
        appRunner();
      },
      (error, stack) {
        // Все необработанные ошибки в Zone попадают сюда
        debugPrint('━' * 80);
        debugPrint('Zone Error caught by ErrorHandler:');
        debugPrint('Error: $error');
        debugPrint('Stack trace:');
        debugPrint(stack.toString());
        debugPrint('━' * 80);

        // TODO: Отправка в систему мониторинга
        // Example:
        // FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      },
    );
  }

  /// Обработчик сетевых ошибок
  ///
  /// Возвращает пользовательское сообщение об ошибке
  static String handleNetworkError(dynamic error) {
    if (error.toString().contains('SocketException')) {
      return 'Нет подключения к интернету. Проверьте соединение.';
    } else if (error.toString().contains('TimeoutException')) {
      return 'Превышено время ожидания. Попробуйте позже.';
    } else if (error.toString().contains('HandshakeException')) {
      return 'Ошибка безопасного соединения. Проверьте настройки сети.';
    } else if (error.toString().contains('401')) {
      return 'Ошибка аутентификации. Проверьте API ключ.';
    } else if (error.toString().contains('403')) {
      return 'Доступ запрещён. Недостаточно прав.';
    } else if (error.toString().contains('404')) {
      return 'Ресурс не найден на сервере.';
    } else if (error.toString().contains('500')) {
      return 'Ошибка сервера. Попробуйте позже.';
    } else {
      return 'Произошла ошибка: ${error.toString()}';
    }
  }

  /// Показать диалог с ошибкой пользователю
  static void showErrorDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Показать SnackBar с ошибкой
  static void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
}
