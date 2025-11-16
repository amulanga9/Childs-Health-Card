import 'package:go_router/go_router.dart';
import '../presentation/screens/home_screen.dart';
import '../presentation/screens/episode_detail_screen_new.dart';
import '../presentation/screens/qr_generator_screen.dart';
import '../presentation/screens/settings_screen.dart';

/// Конфигурация маршрутов приложения
/// Использует GoRouter для навигации
class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      // Главный экран
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
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

      // TODO: Добавить остальные экраны по мере реализации
      // - /child-profile/:childId
      // - /add-child
    ],
  );
}
