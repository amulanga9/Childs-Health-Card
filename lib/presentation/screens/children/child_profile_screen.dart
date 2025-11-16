import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Экран профиля ребёнка
/// Показывает детальную информацию о ребёнке
class ChildProfileScreen extends StatelessWidget {
  final String childId;

  const ChildProfileScreen({
    super.key,
    required this.childId,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // TODO: Загрузить данные ребёнка по childId из Provider

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль ребёнка'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: Открыть форму редактирования
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          // Основная информация
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 60,
                  child: Icon(Icons.child_care, size: 60),
                ),
                const SizedBox(height: 16),
                Text(
                  'Имя ребёнка', // TODO: Заменить на реальное имя
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '5 лет', // TODO: Заменить на реальный возраст
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Дата рождения: 16.11.2020', // TODO: Заменить на реальную дату
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const Divider(),

          // Статистика по здоровью
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Статистика здоровья',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          _buildHealthStats(),
          const Divider(),

          // История болезней
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'История болезней',
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
          _buildIllnessHistory(),
        ],
      ),
    );
  }

  Widget _buildHealthStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _StatRow(
            icon: Icons.medical_services,
            label: 'Всего болезней',
            value: '12',
          ),
          _StatRow(
            icon: Icons.healing,
            label: 'Визитов к врачу',
            value: '24',
          ),
          _StatRow(
            icon: Icons.science,
            label: 'Анализов',
            value: '18',
          ),
          _StatRow(
            icon: Icons.medication,
            label: 'Курсов лечения',
            value: '15',
          ),
        ],
      ),
    );
  }

  Widget _buildIllnessHistory() {
    // TODO: Получить реальные данные из Provider
    return Column(
      children: List.generate(5, (index) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: const Icon(Icons.medical_services),
            title: const Text('ОРВИ'),
            subtitle: const Text('15.10.2025 - 20.10.2025'),
            trailing: const Chip(
              label: Text('Выздоровел'),
              backgroundColor: Colors.green,
            ),
            onTap: () {
              // TODO: Открыть детали болезни
            },
          ),
        );
      }),
    );
  }
}

/// Строка статистики
class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ],
      ),
    );
  }
}
