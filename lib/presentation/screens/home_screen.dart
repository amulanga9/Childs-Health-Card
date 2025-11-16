import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/home_provider.dart';
import '../widgets/child_profile_header.dart';
import '../widgets/episodes_carousel.dart';
import '../widgets/health_calendar.dart';
import '../widgets/yearly_statistics.dart';
import '../../data/database/database.dart';

/// Главный экран приложения
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeInOut,
    );
    _fabAnimationController.forward();
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeProvider>(
      builder: (context, homeProvider, child) {
        final theme = Theme.of(context);

        return Scaffold(
          backgroundColor: theme.colorScheme.background,
          body: homeProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : homeProvider.selectedChild == null
                  ? _buildNoChildState(context, theme)
                  : _buildHomeContent(context, homeProvider, theme),
          // Floating Action Button для добавления эпизода
          floatingActionButton: homeProvider.selectedChild != null
              ? ScaleTransition(
                  scale: _fabAnimation,
                  child: FloatingActionButton.extended(
                    onPressed: () => _showAddEpisodeDialog(context, homeProvider),
                    icon: const Icon(Icons.add),
                    label: const Text('Новый эпизод'),
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                )
              : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          // Нижняя навигация
          bottomNavigationBar: homeProvider.selectedChild != null
              ? _buildBottomNavigationBar(context, theme)
              : null,
        );
      },
    );
  }

  /// Контент главного экрана
  Widget _buildHomeContent(BuildContext context, HomeProvider homeProvider, ThemeData theme) {
    return RefreshIndicator(
      onRefresh: homeProvider.refresh,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Верхняя панель профиля
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: ChildProfileHeader(
                child: homeProvider.selectedChild!,
                onTap: () => context.push('/child-profile/${homeProvider.selectedChild!.id}'),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          // Заголовок секции эпизодов
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Эпизоды болезней',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          // Горизонтальная лента эпизодов
          SliverToBoxAdapter(
            child: EpisodesCarousel(
              episodes: homeProvider.episodes,
              onEpisodeTap: (episode) {
                context.push('/episode/${episode.id}');
              },
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          // Заголовок секции календаря
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Календарь событий',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          // Календарь
          SliverToBoxAdapter(
            child: HealthCalendar(
              focusedDay: homeProvider.focusedMonth,
              events: homeProvider.calendarEvents,
              onMonthChanged: homeProvider.changeFocusedMonth,
              onDaySelected: (day) {
                final events = homeProvider.getEventsForDay(day);
                if (events.isNotEmpty) {
                  _showDayEventsDialog(context, day, events);
                }
              },
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          // Статистика за год
          SliverToBoxAdapter(
            child: YearlyStatistics(
              stats: homeProvider.yearlyStats,
              year: homeProvider.selectedYear,
              onYearChanged: homeProvider.changeSelectedYear,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  /// Состояние "Нет детей"
  Widget _buildNoChildState(BuildContext context, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.child_care,
              size: 120,
              color: theme.colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'Добавьте профиль ребёнка',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Создайте профиль ребёнка, чтобы начать отслеживать его здоровье',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => context.push('/add-child'),
              icon: const Icon(Icons.add),
              label: const Text('Добавить ребёнка'),
            ),
          ],
        ),
      ),
    );
  }

  /// Нижняя навигационная панель
  Widget _buildBottomNavigationBar(BuildContext context, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavButton(
                theme,
                icon: Icons.home,
                label: 'Главная',
                isSelected: true,
                onTap: () {},
              ),
              _buildNavButton(
                theme,
                icon: Icons.qr_code,
                label: 'QR для врача',
                isSelected: false,
                onTap: () => _showQRDialog(context),
              ),
              _buildNavButton(
                theme,
                icon: Icons.settings,
                label: 'Настройки',
                isSelected: false,
                onTap: () => context.push('/settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Кнопка нижней навигации
  Widget _buildNavButton(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Диалог добавления эпизода
  void _showAddEpisodeDialog(BuildContext context, HomeProvider homeProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Добавить эпизод',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                'Эта функция в разработке',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Закрыть'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Диалог событий дня
  void _showDayEventsDialog(BuildContext context, DateTime day, List<dynamic> events) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('События ${day.day}.${day.month}.${day.year}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: events.map((event) {
            if (event is Episode) {
              return ListTile(
                leading: const Icon(Icons.sick),
                title: Text(event.diagnosis),
                subtitle: Text(event.status == 'active' ? 'Активно' : 'Закрыто'),
                contentPadding: EdgeInsets.zero,
              );
            }
            return const SizedBox.shrink();
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  /// Диалог QR кода
  void _showQRDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('QR для врача'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.qr_code, size: 120),
            SizedBox(height: 16),
            Text('Эта функция в разработке'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }
}
