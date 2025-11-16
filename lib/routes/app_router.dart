import 'package:go_router/go_router.dart';
import '../presentation/screens/home_screen.dart';
import '../presentation/screens/episode_detail_screen_new.dart';

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

      // TODO: Добавить остальные экраны по мере реализации
      // - /child-profile/:childId
      // - /add-child
      // - /settings
      // - /qr-code
    ],
  );
}
