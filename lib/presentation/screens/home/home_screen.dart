import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Главный экран приложения
/// Содержит профиль ребёнка, ленту болезней, календарь, статистику
/// Навигация через нижнюю панель (BottomNavigationBar)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          // Кнопка выбора ребёнка
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              // TODO: Показать список детей для выбора
            },
          ),
          // Кнопка настроек
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: l10n.home,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.calendar_today),
            label: l10n.calendar,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.bar_chart),
            label: l10n.statistics,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: l10n.settings,
          ),
        ],
      ),
      // Кнопка добавления новой болезни
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                // TODO: Показать диалог добавления болезни
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return _buildCalendarTab();
      case 2:
        return _buildStatisticsTab();
      case 3:
        return _buildSettingsTab();
      default:
        return _buildHomeTab();
    }
  }

  /// Вкладка "Главная" - профиль ребёнка и лента болезней
  Widget _buildHomeTab() {
    final l10n = AppLocalizations.of(context)!;

    return CustomScrollView(
      slivers: [
        // Профиль выбранного ребёнка
        SliverToBoxAdapter(
          child: _ChildProfileCard(),
        ),

        // Заголовок секции болезней
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.illnesses,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton(
                  onPressed: () {
                    // TODO: Показать все болезни
                  },
                  child: const Text('Все'),
                ),
              ],
            ),
          ),
        ),

        // Список болезней
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              return _IllnessCard(
                title: 'Грипп',
                startDate: DateTime.now(),
                status: 'Активна',
                onTap: () {
                  // TODO: Открыть детальную информацию о болезни
                },
              );
            },
            childCount: 5, // TODO: Заменить на реальные данные
          ),
        ),
      ],
    );
  }

  /// Вкладка "Календарь" - календарь событий
  Widget _buildCalendarTab() {
    return const Center(
      child: Text('Календарь'),
    );
  }

  /// Вкладка "Статистика" - графики и аналитика
  Widget _buildStatisticsTab() {
    return const Center(
      child: Text('Статистика'),
    );
  }

  /// Вкладка "Настройки"
  Widget _buildSettingsTab() {
    return const Center(
      child: Text('Настройки'),
    );
  }
}

/// Карточка профиля ребёнка
class _ChildProfileCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Аватар ребёнка
            const CircleAvatar(
              radius: 40,
              child: Icon(Icons.child_care, size: 40),
            ),
            const SizedBox(width: 16),
            // Информация о ребёнке
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Имя ребёнка', // TODO: Заменить на реальные данные
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '5 лет', // TODO: Заменить на реальный возраст
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: 0.8, // TODO: Заменить на реальный прогресс здоровья
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Карточка болезни в списке
class _IllnessCard extends StatelessWidget {
  final String title;
  final DateTime startDate;
  final String status;
  final VoidCallback onTap;

  const _IllnessCard({
    required this.title,
    required this.startDate,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: const Icon(Icons.medical_services),
        title: Text(title),
        subtitle: Text('Начало: ${_formatDate(startDate)}'),
        trailing: Chip(
          label: Text(status),
          backgroundColor: status == 'Активна' ? Colors.red.shade100 : Colors.green.shade100,
        ),
        onTap: onTap,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }
}
