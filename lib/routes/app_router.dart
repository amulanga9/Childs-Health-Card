import 'package:go_router/go_router.dart';
import '../presentation/screens/home/home_screen.dart';
import '../presentation/screens/illness/illness_detail_screen.dart';
import '../presentation/screens/settings/settings_screen.dart';
import '../presentation/screens/children/child_profile_screen.dart';
import '../presentation/screens/calendar/calendar_screen.dart';
import '../presentation/screens/statistics/statistics_screen.dart';

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

      // Экран календаря
      GoRoute(
        path: '/calendar',
        name: 'calendar',
        builder: (context, state) => const CalendarScreen(),
      ),

      // Экран статистики
      GoRoute(
        path: '/statistics',
        name: 'statistics',
        builder: (context, state) => const StatisticsScreen(),
      ),

      // Экран настроек
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),

      // Экран профиля ребёнка
      GoRoute(
        path: '/child/:childId',
        name: 'childProfile',
        builder: (context, state) {
          final childId = state.pathParameters['childId']!;
          return ChildProfileScreen(childId: childId);
        },
      ),

      // Детальный экран болезни
      GoRoute(
        path: '/illness/:illnessId',
        name: 'illnessDetail',
        builder: (context, state) {
          final illnessId = state.pathParameters['illnessId']!;
          return IllnessDetailScreen(illnessId: illnessId);
        },
      ),
    ],
  );
}
