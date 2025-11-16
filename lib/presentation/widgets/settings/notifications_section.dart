import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';

class NotificationsSection extends StatelessWidget {
  const NotificationsSection({super.key});

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
                    Icon(Icons.notifications, color: theme.colorScheme.primary, size: 24),
                    const SizedBox(width: 12),
                    Text('Уведомления', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.notifications_active),
                title: const Text('Уведомления'),
                subtitle: const Text('Включить все уведомления'),
                trailing: Switch(
                  value: settings.notificationsEnabled,
                  onChanged: (value) => settings.setNotifications(value),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.medication),
                title: const Text('Напоминания о лекарствах'),
                subtitle: const Text('Уведомлять о времени приёма'),
                trailing: Switch(
                  value: settings.medicationReminders,
                  onChanged: settings.notificationsEnabled ? (value) => settings.setMedicationReminders(value) : null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
