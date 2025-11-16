import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';

/// Секция безопасности (PIN-код)
class SecuritySection extends StatelessWidget {
  const SecuritySection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.2),
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
                      Icons.security,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Безопасность',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.pin),
                title: const Text('PIN-код'),
                subtitle: Text(
                  settings.isPinEnabled ? 'Установлен' : 'Не установлен',
                ),
                trailing: Switch(
                  value: settings.isPinEnabled,
                  onChanged: (value) {
                    if (value) {
                      _showSetPinDialog(context);
                    } else {
                      _showRemovePinDialog(context);
                    }
                  },
                ),
              ),
              if (settings.isPinEnabled)
                ListTile(
                  leading: const Icon(Icons.fingerprint),
                  title: const Text('Биометрия'),
                  subtitle: const Text('Отпечаток пальца / Face ID'),
                  trailing: Switch(
                    value: settings.useBiometrics,
                    onChanged: (value) => settings.setBiometrics(value),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showSetPinDialog(BuildContext context) {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Установить PIN-код'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pinController,
              decoration: const InputDecoration(
                labelText: 'PIN-код (4-6 цифр)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmController,
              decoration: const InputDecoration(
                labelText: 'Подтвердите PIN-код',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              final pin = pinController.text;
              final confirm = confirmController.text;

              if (pin.length < 4 || pin.length > 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('PIN должен содержать 4-6 цифр'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (pin != confirm) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('PIN-коды не совпадают'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final settings = context.read<SettingsProvider>();
              final success = await settings.setPinCode(pin);

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'PIN-код установлен'
                        : 'Ошибка установки PIN-кода'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Установить'),
          ),
        ],
      ),
    );
  }

  void _showRemovePinDialog(BuildContext context) {
    final pinController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить PIN-код'),
        content: TextField(
          controller: pinController,
          decoration: const InputDecoration(
            labelText: 'Введите текущий PIN-код',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          maxLength: 6,
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              final settings = context.read<SettingsProvider>();
              final isValid = await settings.verifyPinCode(pinController.text);

              if (!isValid) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Неверный PIN-код'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return;
              }

              final success = await settings.removePinCode();

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'PIN-код удален'
                        : 'Ошибка удаления PIN-кода'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }
}
