import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../providers/admin_auth_provider.dart';

/// Боковое меню для админской панели
class AdminDrawer extends StatelessWidget {
  const AdminDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final adminAuth = context.watch<AdminAuthProvider>();
    final theme = Theme.of(context);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Header
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primaryContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.admin_panel_settings,
                  size: 48,
                  color: Colors.white,
                ),
                const SizedBox(height: 8),
                Text(
                  'Админ-панель',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  adminAuth.adminName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          // Панель администратора
          _buildMenuItem(
            context,
            icon: Icons.dashboard,
            title: 'Панель администратора',
            route: '/admin',
            currentRoute: GoRouterState.of(context).uri.path,
          ),

          const Divider(),

          // Управление данными
          _buildSectionHeader(context, 'Управление данными'),

          _buildMenuItem(
            context,
            icon: Icons.child_care,
            title: 'Дети',
            route: '/admin/children',
            currentRoute: GoRouterState.of(context).uri.path,
          ),

          _buildMenuItem(
            context,
            icon: Icons.medical_services,
            title: 'Эпизоды болезней',
            route: '/admin/episodes',
            currentRoute: GoRouterState.of(context).uri.path,
          ),

          const Divider(),

          // Система
          _buildSectionHeader(context, 'Система'),

          _buildMenuItem(
            context,
            icon: Icons.people,
            title: 'Пользователи',
            route: '/admin/users',
            currentRoute: GoRouterState.of(context).uri.path,
          ),

          _buildMenuItem(
            context,
            icon: Icons.history,
            title: 'Логи активности',
            route: '/admin/logs',
            currentRoute: GoRouterState.of(context).uri.path,
          ),

          _buildMenuItem(
            context,
            icon: Icons.settings,
            title: 'Настройки админки',
            route: '/admin/settings',
            currentRoute: GoRouterState.of(context).uri.path,
          ),

          const Divider(),

          // Выход
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.red),
            title: const Text('Выйти из админки'),
            onTap: () {
              Navigator.pop(context); // Закрываем drawer
              _showLogoutDialog(context);
            },
          ),

          ListTile(
            leading: const Icon(Icons.arrow_back),
            title: const Text('Вернуться в приложение'),
            onTap: () {
              context.go('/home');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String route,
    required String currentRoute,
  }) {
    final isSelected = currentRoute == route;
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? theme.colorScheme.primary : null,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? theme.colorScheme.primary : null,
          fontWeight: isSelected ? FontWeight.bold : null,
        ),
      ),
      selected: isSelected,
      selectedTileColor: theme.colorScheme.primaryContainer.withOpacity(0.3),
      onTap: () {
        Navigator.pop(context); // Закрываем drawer
        context.go(route);
      },
    );
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выйти из админки?'),
        content: const Text(
          'Вы уверены, что хотите выйти из режима администратора?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<AdminAuthProvider>().logout();
      if (context.mounted) {
        context.go('/home');
      }
    }
  }
}
