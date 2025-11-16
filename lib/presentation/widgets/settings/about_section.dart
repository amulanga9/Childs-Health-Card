import 'package:flutter/material.dart';

class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.info, color: theme.colorScheme.primary, size: 24),
                const SizedBox(width: 12),
                Text('О приложении', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(height: 1),
          const ListTile(
            leading: Icon(Icons.app_settings_alt),
            title: Text('Версия'),
            trailing: Text('1.0.0'),
          ),
          const ListTile(
            leading: Icon(Icons.code),
            title: Text('Сборка'),
            trailing: Text('1'),
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Лицензия'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLicenseDialog(context),
          ),
        ],
      ),
    );
  }

  void _showLicenseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Лицензия'),
        content: const Text(
          'Карта здоровья ребёнка\n\n'
          'Proprietary Software\n'
          'Все права защищены © 2025\n\n'
          'Это приложение создано для управления медицинскими данными детей.',
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
