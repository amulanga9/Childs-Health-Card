import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_auth_provider.dart';
import '../../providers/admin_logs_provider.dart';
import '../../data/models/admin_security.dart';
import 'widgets/admin_drawer.dart';

/// Экран настроек админки
class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final adminAuth = context.watch<AdminAuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки админки'),
      ),
      drawer: const AdminDrawer(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Профиль
          Text(
            'Профиль',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),

          Card(
            child: ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Имя администратора'),
              subtitle: Text(adminAuth.name),
              trailing: const Icon(Icons.edit),
              onTap: () => _changeAdminName(context),
            ),
          ),

          if (adminAuth.perms.isAdmin)
            Card(
              child: ListTile(
                leading: const Icon(Icons.admin_panel_settings),
                title: const Text('Роль'),
                subtitle: Text(AdminRole.getDisplayName(adminAuth.role)),
                trailing: const Icon(Icons.edit),
                onTap: () => _changeRole(context),
              ),
            ),

          const SizedBox(height: 24),

          // Безопасность
          Text(
            'Безопасность',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),

          Card(
            child: ListTile(
              leading: const Icon(Icons.lock),
              title: const Text('Сменить пароль'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _changePassword(context),
            ),
          ),

          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.pin),
              title: const Text('PIN-код (второй фактор)'),
              subtitle: Text(
                adminAuth.hasSecondFactor
                  ? 'Включен (дополнительная защита)'
                  : 'Выключен'
              ),
              value: adminAuth.hasSecondFactor,
              onChanged: (value) {
                if (value) {
                  _enableSecondFactor(context);
                } else {
                  _disableSecondFactor(context);
                }
              },
            ),
          ),

          if (adminAuth.hasSecondFactor)
            Card(
              child: ListTile(
                leading: const Icon(Icons.key),
                title: const Text('Резервные коды'),
                subtitle: Text(
                  'Осталось кодов: ${adminAuth.getBackupCodes().length} из 5'
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showBackupCodes(context),
              ),
            ),

          Card(
            child: ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('Сбросить пароль'),
              subtitle: const Text('Вернуть пароль по умолчанию (0000)'),
              trailing: const Icon(Icons.warning, color: Colors.orange),
              onTap: () => _resetPassword(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changeAdminName(BuildContext context) async {
    final controller = TextEditingController(
      text: context.read<AdminAuthProvider>().name,
    );

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Изменить имя'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Имя администратора'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && mounted) {
      await context.read<AdminAuthProvider>().setName(newName);
    }
  }

  Future<void> _changeRole(BuildContext context) async {
    final adminAuth = context.read<AdminAuthProvider>();
    final adminLogs = context.read<AdminLogsProvider>();
    final currentRole = adminAuth.role;

    final newRole = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Изменить роль'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: Text(AdminRole.getDisplayName(AdminRole.admin)),
              subtitle: const Text('Все права'),
              value: AdminRole.admin,
              groupValue: currentRole,
              onChanged: (value) => Navigator.pop(context, value),
            ),
            RadioListTile<String>(
              title: Text(AdminRole.getDisplayName(AdminRole.moderator)),
              subtitle: const Text('Просмотр и редактирование'),
              value: AdminRole.moderator,
              groupValue: currentRole,
              onChanged: (value) => Navigator.pop(context, value),
            ),
            RadioListTile<String>(
              title: Text(AdminRole.getDisplayName(AdminRole.viewer)),
              subtitle: const Text('Только просмотр'),
              value: AdminRole.viewer,
              groupValue: currentRole,
              onChanged: (value) => Navigator.pop(context, value),
            ),
          ],
        ),
      ),
    );

    if (newRole != null && newRole != currentRole && mounted) {
      await adminAuth.setRole(newRole);
      await adminLogs.add(
        action: 'change_role',
        entityType: 'security',
        adminName: adminAuth.name,
        entityName: 'Изменено с $currentRole на $newRole',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Роль изменена на ${AdminRole.getDisplayName(newRole)}')),
        );
      }
    }
  }

  Future<void> _changePassword(BuildContext context) async {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сменить пароль'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Текущий пароль'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Новый пароль'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Подтвердите пароль'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              if (newController.text != confirmController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Пароли не совпадают')),
                );
                return;
              }
              if (newController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Пароль не может быть пустым')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Изменить'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final adminAuth = context.read<AdminAuthProvider>();
      final adminLogs = context.read<AdminLogsProvider>();
      final success = await adminAuth.changePass(
        oldController.text,
        newController.text,
      );

      if (mounted) {
        if (success) {
          await adminLogs.add(
            action: 'change_password',
            entityType: 'security',
            adminName: adminAuth.name,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Пароль успешно изменен')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Неверный текущий пароль'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _enableSecondFactor(BuildContext context) async {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Включить PIN-код'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Введите 4-значный PIN-код для дополнительной защиты'),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: 'PIN-код',
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: 'Подтвердите PIN',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              if (pinController.text != confirmController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN-коды не совпадают')),
                );
                return;
              }
              if (pinController.text.length != 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN должен быть 4 цифры')),
                );
                return;
              }
              // Проверка что PIN состоит только из цифр
              if (!RegExp(r'^\d{4}$').hasMatch(pinController.text)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN должен содержать только цифры')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Включить'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final adminAuth = context.read<AdminAuthProvider>();
      final adminLogs = context.read<AdminLogsProvider>();

      await adminAuth.enableSecondFactor(pinController.text);
      await adminLogs.add(
        action: 'enable_2fa',
        entityType: 'security',
        adminName: adminAuth.name,
      );

      if (mounted) {
        // Показываем резервные коды
        _showBackupCodes(context, isFirstTime: true);
      }
    }
  }

  Future<void> _disableSecondFactor(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отключить PIN-код?'),
        content: const Text(
          'Это снизит уровень безопасности вашей учетной записи. '
          'Вы уверены?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Отключить'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final adminAuth = context.read<AdminAuthProvider>();
      final adminLogs = context.read<AdminLogsProvider>();

      await adminAuth.disableSecondFactor();
      await adminLogs.add(
        action: 'disable_2fa',
        entityType: 'security',
        adminName: adminAuth.name,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN-код отключен')),
        );
      }
    }
  }

  Future<void> _showBackupCodes(BuildContext context, {bool isFirstTime = false}) async {
    final adminAuth = context.read<AdminAuthProvider>();
    final codes = adminAuth.getBackupCodes();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Резервные коды'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isFirstTime)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Сохраните эти коды в безопасном месте! '
                        'Они нужны, если забудете PIN.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            const Text('Используйте эти коды вместо PIN, если забудете его:'),
            const SizedBox(height: 16),
            ...codes.asMap().entries.map((entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text('${entry.key + 1}.'),
                  const SizedBox(width: 8),
                  Text(
                    entry.value,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetPassword(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сбросить пароль?'),
        content: const Text('Пароль будет сброшен на 0000'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final adminAuth = context.read<AdminAuthProvider>();
      final adminLogs = context.read<AdminLogsProvider>();

      await adminAuth.resetPass();
      await adminLogs.add(
        action: 'reset_password',
        entityType: 'security',
        adminName: adminAuth.name,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Пароль сброшен на 0000')),
        );
      }
    }
  }
}
