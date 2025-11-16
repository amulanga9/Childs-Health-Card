import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/settings_provider.dart';
import '../../services/backup_service.dart';
import '../widgets/settings/children_management_section.dart';
import '../widgets/settings/security_section.dart';
import '../widgets/settings/backup_section.dart';
import '../widgets/settings/cloud_section.dart';
import '../widgets/settings/language_section.dart';
import '../widgets/settings/notifications_section.dart';
import '../widgets/settings/privacy_section.dart';
import '../widgets/settings/about_section.dart';

/// Экран настроек приложения
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final BackupService _backupService;

  @override
  void initState() {
    super.initState();
    final settingsProvider = context.read<SettingsProvider>();
    _backupService = BackupService(database: settingsProvider.database);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App Bar
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: theme.colorScheme.surface,
            elevation: 0,
            title: Text(
              'Настройки',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            leading: IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back),
            ),
          ),

          // Секции настроек
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Управление детьми
                  ChildrenManagementSection(),
                  const SizedBox(height: 24),

                  // Язык
                  const LanguageSection(),
                  const SizedBox(height: 24),

                  // Безопасность
                  const SecuritySection(),
                  const SizedBox(height: 24),

                  // Приватность
                  const PrivacySection(),
                  const SizedBox(height: 24),

                  // Резервное копирование
                  BackupSection(backupService: _backupService),
                  const SizedBox(height: 24),

                  // Облачное хранилище
                  const CloudSection(),
                  const SizedBox(height: 24),

                  // Уведомления
                  const NotificationsSection(),
                  const SizedBox(height: 24),

                  // О приложении
                  const AboutSection(),
                  const SizedBox(height: 24),

                  // Сброс настроек
                  _buildResetSection(context, theme),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetSection(BuildContext context, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.error.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: theme.colorScheme.error,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Опасная зона',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              Icons.restart_alt,
              color: theme.colorScheme.error,
            ),
            title: const Text('Сбросить все настройки'),
            subtitle: const Text('Вернуть настройки к значениям по умолчанию'),
            onTap: () => _showResetDialog(context),
          ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сброс настроек'),
        content: const Text(
          'Вы действительно хотите сбросить все настройки?\n\n'
          'Это действие:\n'
          '• Удалит PIN-код\n'
          '• Удалит облачные настройки\n'
          '• Сбросит язык на русский\n'
          '• Сбросит все прочие настройки\n\n'
          'Данные детей и эпизоды НЕ будут удалены.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              final settingsProvider = context.read<SettingsProvider>();
              await settingsProvider.resetToDefaults();

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Настройки сброшены'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );
  }
}
