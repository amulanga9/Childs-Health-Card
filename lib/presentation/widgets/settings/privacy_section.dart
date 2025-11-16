import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';

class PrivacySection extends StatelessWidget {
  const PrivacySection({super.key});

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
                    Icon(Icons.privacy_tip, color: theme.colorScheme.primary, size: 24),
                    const SizedBox(width: 12),
                    Text('Приватность', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.lock_clock),
                title: const Text('PIN при запуске'),
                subtitle: const Text('Запрашивать PIN при каждом открытии'),
                trailing: Switch(
                  value: settings.requirePinOnStart,
                  onChanged: settings.isPinEnabled ? (value) => settings.setRequirePinOnStart(value) : null,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.visibility_off),
                title: const Text('Скрывать данные в многозадачности'),
                subtitle: const Text('Затемнять экран при переключении приложений'),
                trailing: Switch(
                  value: settings.hideDataInMultitasking,
                  onChanged: (value) => settings.setHideDataInMultitasking(value),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
