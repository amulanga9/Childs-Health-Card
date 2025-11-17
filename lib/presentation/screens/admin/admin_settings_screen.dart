import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_auth_provider.dart';
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
          Card(
            child: ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Имя администратора'),
              subtitle: Text(adminAuth.adminName),
              trailing: const Icon(Icons.edit),
              onTap: () => _changeAdminName(context),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock),
              title: const Text('Сменить пароль'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _changePassword(context),
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
      text: context.read<AdminAuthProvider>().adminName,
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
      await context.read<AdminAuthProvider>().setAdminName(newName);
    }
  }

  Future<void> _changePassword(BuildContext context) async {
    // TODO: Implement password change dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Функция в разработке')),
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
      await context.read<AdminAuthProvider>().resetAdminPassword();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Пароль сброшен на 0000')),
        );
      }
    }
  }
}
