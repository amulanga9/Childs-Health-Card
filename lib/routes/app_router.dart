import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../presentation/screens/home_screen.dart';
import '../presentation/screens/episode_detail_screen_new.dart';
import '../presentation/screens/qr_generator_screen.dart';
import '../presentation/screens/settings_screen.dart';
import '../presentation/providers/admin_auth_provider.dart';

// Admin screens
import '../presentation/screens/admin/admin_login_screen.dart';
import '../presentation/screens/admin/admin_dashboard_screen.dart';
import '../presentation/screens/admin/admin_children_screen.dart';
import '../presentation/screens/admin/admin_episodes_screen.dart';
import '../presentation/screens/admin/admin_users_screen.dart';
import '../presentation/screens/admin/admin_settings_screen.dart';
import '../presentation/screens/admin/admin_logs_screen.dart';

/// Конфигурация маршрутов приложения
/// Использует GoRouter для навигации с защитой admin роутов
class AppRouter {
  /// Проверка авторизации админа (Auth Guard)
  ///
  /// SECURITY: Защищает admin роуты от неавторизованного доступа
  static String? _adminAuthGuard(BuildContext context, GoRouterState state) {
    final adminAuth = context.read<AdminAuthProvider>();

    // Если пользователь НЕ авторизован как админ
    if (!adminAuth.isAuth) {
      // Перенаправляем на экран входа
      // Сохраняем originalLocation для возврата после логина
      return '/admin/login?redirect=${Uri.encodeComponent(state.matchedLocation)}';
    }

    // Если авторизован - разрешаем доступ
    return null;
  }

  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      // ============ ОСНОВНЫЕ ЭКРАНЫ ============

      // Главный экран
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),

      // Alias для home
      GoRoute(
        path: '/home',
        redirect: (context, state) => '/',
      ),

      // Детальный экран эпизода
      GoRoute(
        path: '/episode/:episodeId',
        name: 'episodeDetail',
        builder: (context, state) {
          final episodeIdStr = state.pathParameters['episodeId'];
          if (episodeIdStr == null) {
            // Если ID отсутствует, возвращаемся на главную
            return const HomeScreen();
          }

          try {
            final episodeId = int.parse(episodeIdStr);
            return EpisodeDetailScreenNew(episodeId: episodeId);
          } catch (e) {
            // Если ID невалиден, возвращаемся на главную
            return const HomeScreen();
          }
        },
      ),

      // Экран генерации QR кода для врача
      GoRoute(
        path: '/qr-generator',
        name: 'qrGenerator',
        builder: (context, state) => const QRGeneratorScreen(),
      ),

      // Экран настроек
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),

      // ============ АДМИНСКАЯ ПАНЕЛЬ (ЗАЩИЩЕНО) ============

      // Вход в админку (не требует авторизации)
      GoRoute(
        path: '/admin/login',
        name: 'adminLogin',
        builder: (context, state) => const AdminLoginScreen(),
      ),

      // ===== ВСЕ ОСТАЛЬНЫЕ ADMIN РОУТЫ ЗАЩИЩЕНЫ AUTH GUARD =====

      // Панель администратора
      GoRoute(
        path: '/admin',
        name: 'adminDashboard',
        redirect: _adminAuthGuard,
        builder: (context, state) => const AdminDashboardScreen(),
      ),

      // Управление детьми
      GoRoute(
        path: '/admin/children',
        name: 'adminChildren',
        redirect: _adminAuthGuard,
        builder: (context, state) => const AdminChildrenScreen(),
      ),

      // Управление эпизодами
      GoRoute(
        path: '/admin/episodes',
        name: 'adminEpisodes',
        redirect: _adminAuthGuard,
        builder: (context, state) => const AdminEpisodesScreen(),
      ),

      // Управление пользователями
      GoRoute(
        path: '/admin/users',
        name: 'adminUsers',
        redirect: _adminAuthGuard,
        builder: (context, state) => const AdminUsersScreen(),
      ),

      // Настройки админки
      GoRoute(
        path: '/admin/settings',
        name: 'adminSettings',
        redirect: _adminAuthGuard,
        builder: (context, state) => const AdminSettingsScreen(),
      ),

      // Логи активности
      GoRoute(
        path: '/admin/logs',
        name: 'adminLogs',
        redirect: _adminAuthGuard,
        builder: (context, state) => const AdminLogsScreen(),
      ),
    ],

    // Обработка ошибок навигации
    errorBuilder: (context, state) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'Страница не найдена',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('404: Запрошенная страница не существует'),
            ],
          ),
        ),
      );
    },
  );
}
