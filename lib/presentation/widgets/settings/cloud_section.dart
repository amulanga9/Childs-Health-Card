import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';

class CloudSection extends StatelessWidget {
  const CloudSection({super.key});

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
                    Icon(Icons.cloud, color: theme.colorScheme.primary, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Облачное хранилище', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          Text(
                            settings.isCloudEnabled ? 'Подключено' : 'Не настроено',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: settings.isCloudEnabled ? Colors.green : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.settings),
                title: Text(settings.isCloudEnabled ? 'Изменить настройки' : 'Настроить'),
                subtitle: const Text('Yandex Object Storage'),
                onTap: () => _showCloudDialog(context, settings),
              ),
              if (settings.isCloudEnabled)
                ListTile(
                  leading: Icon(Icons.delete, color: theme.colorScheme.error),
                  title: Text('Отключить', style: TextStyle(color: theme.colorScheme.error)),
                  onTap: () => _removeCloud(context, settings),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showCloudDialog(BuildContext context, SettingsProvider settings) async {
    final creds = await settings.getCloudCredentials();
    final endpointController = TextEditingController(text: creds['endpoint'] ?? 'https://storage.yandexcloud.net');
    final accessKeyController = TextEditingController(text: creds['accessKey'] ?? '');
    final secretKeyController = TextEditingController(text: creds['secretKey'] ?? '');
    final bucketController = TextEditingController(text: creds['bucketName'] ?? '');

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Облачное хранилище'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Введите параметры Yandex Object Storage:', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 16),
              TextField(
                controller: endpointController,
                decoration: const InputDecoration(labelText: 'Endpoint', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: accessKeyController,
                decoration: const InputDecoration(labelText: 'Access Key ID', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: secretKeyController,
                decoration: const InputDecoration(labelText: 'Secret Access Key', border: OutlineInputBorder()),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bucketController,
                decoration: const InputDecoration(labelText: 'Bucket Name', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          FilledButton(
            onPressed: () async {
              if (endpointController.text.isEmpty || accessKeyController.text.isEmpty ||
                  secretKeyController.text.isEmpty || bucketController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Заполните все поля'), backgroundColor: Colors.red),
                );
                return;
              }

              final success = await settings.setCloudCredentials(
                endpoint: endpointController.text.trim(),
                accessKey: accessKeyController.text.trim(),
                secretKey: secretKeyController.text.trim(),
                bucketName: bucketController.text.trim(),
              );

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Облачное хранилище настроено' : 'Ошибка сохранения'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _removeCloud(BuildContext context, SettingsProvider settings) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отключить облако?'),
        content: const Text('Учетные данные будут удалены. Файлы в облаке останутся.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await settings.removeCloudCredentials();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Облачное хранилище отключено'), backgroundColor: Colors.green),
        );
      }
    }
  }
}
