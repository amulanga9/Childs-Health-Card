import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../../../services/backup_service.dart';
import '../../providers/settings_provider.dart';

class BackupSection extends StatelessWidget {
  final BackupService backupService;
  
  const BackupSection({super.key, required this.backupService});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
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
                    Icon(Icons.backup, color: theme.colorScheme.primary, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Резервное копирование', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          if (settings.lastBackupTime != null)
                            Text(
                              'Последний раз: ${DateFormat('dd.MM.yyyy HH:mm').format(settings.lastBackupTime!)}',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.save_alt),
                title: const Text('Создать резервную копию'),
                subtitle: const Text('Сохранить данные в ZIP архив'),
                onTap: () => _createBackup(context),
              ),
              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('Восстановить из резервной копии'),
                subtitle: const Text('Загрузить данные из ZIP архива'),
                onTap: () => _restoreBackup(context),
              ),
              ListTile(
                leading: const Icon(Icons.auto_mode),
                title: const Text('Автоматическое резервное копирование'),
                subtitle: const Text('Еженедельно'),
                trailing: Switch(
                  value: settings.autoBackup,
                  onChanged: (value) => settings.setAutoBackup(value),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _createBackup(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Создание резервной копии...'),
          ],
        ),
      ),
    );

    final zipPath = await backupService.createBackup();

    if (context.mounted) {
      Navigator.pop(context);

      if (zipPath != null) {
        final settings = context.read<SettingsProvider>();
        await settings.updateLastBackupTime();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Резервная копия создана:\n$zipPath'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка создания резервной копии'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _restoreBackup(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (result == null || result.files.single.path == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Восстановить данные?'),
        content: const Text(
          'Все текущие данные будут заменены данными из резервной копии.\n\nПриложение будет перезапущено.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Восстановить'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Восстановление...'),
          ],
        ),
      ),
    );

    final success = await backupService.restoreBackup(result.files.single.path!);

    if (context.mounted) {
      Navigator.pop(context);

      if (success) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Восстановление завершено'),
            content: const Text('Пожалуйста, перезапустите приложение.'),
            actions: [
              FilledButton(
                onPressed: () {
                  // TODO: Implement app restart
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка восстановления'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
