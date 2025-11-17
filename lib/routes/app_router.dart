import 'package:go_router/go_router.dart';
import '../presentation/screens/home_screen.dart';
import '../presentation/screens/episode_detail_screen_new.dart';
import '../presentation/screens/qr_generator_screen.dart';
import '../presentation/screens/settings_screen.dart';

// Admin screens
import '../presentation/screens/admin/admin_login_screen.dart';
import '../presentation/screens/admin/admin_dashboard_screen.dart';
import '../presentation/screens/admin/admin_children_screen.dart';
import '../presentation/screens/admin/admin_episodes_screen.dart';
import '../presentation/screens/admin/admin_users_screen.dart';
import '../presentation/screens/admin/admin_settings_screen.dart';
import '../presentation/screens/admin/admin_logs_screen.dart';

/// Конфигурация маршрутов приложения
/// Использует GoRouter для навигации
class AppRouter {
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
          final episodeId = int.parse(state.pathParameters['episodeId']!);
          return EpisodeDetailScreenNew(episodeId: episodeId);
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

      // ============ АДМИНСКАЯ ПАНЕЛЬ ============

      // Вход в админку
      GoRoute(
        path: '/admin/login',
        name: 'adminLogin',
        builder: (context, state) => const AdminLoginScreen(),
      ),

      // Панель администратора
      GoRoute(
        path: '/admin',
        name: 'adminDashboard',
        builder: (context, state) => const AdminDashboardScreen(),
      ),

      // Управление детьми
      GoRoute(
        path: '/admin/children',
        name: 'adminChildren',
        builder: (context, state) => const AdminChildrenScreen(),
      ),

      // Управление эпизодами
      GoRoute(
        path: '/admin/episodes',
        name: 'adminEpisodes',
        builder: (context, state) => const AdminEpisodesScreen(),
      ),

      // Управление пользователями
      GoRoute(
        path: '/admin/users',
        name: 'adminUsers',
        builder: (context, state) => const AdminUsersScreen(),
      ),

      // Настройки админки
      GoRoute(
        path: '/admin/settings',
        name: 'adminSettings',
        builder: (context, state) => const AdminSettingsScreen(),
      ),

      // Логи активности
      GoRoute(
        path: '/admin/logs',
        name: 'adminLogs',
        builder: (context, state) => const AdminLogsScreen(),
      ),

      // TODO: Добавить остальные экраны по мере реализации
      // - /child-profile/:childId
      // - /add-child
    ],
  );
}
