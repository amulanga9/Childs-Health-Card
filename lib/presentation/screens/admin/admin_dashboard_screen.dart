import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';
import '../../providers/admin_auth_provider.dart';
import '../../providers/admin_logs_provider.dart';
import 'widgets/admin_drawer.dart';
import 'widgets/admin_stat_card.dart';

/// Главный экран админской панели
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Обновляем статистику при входе
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().refreshStatistics();
    });
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = context.watch<AdminProvider>();
    final adminAuth = context.watch<AdminAuthProvider>();
    final adminLogs = context.watch<AdminLogsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Панель администратора'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => adminProvider.refreshStatistics(),
            tooltip: 'Обновить',
          ),
        ],
      ),
      drawer: const AdminDrawer(),
      body: adminProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => adminProvider.refreshStatistics(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Приветствие
                    _buildWelcomeCard(adminAuth),

                    const SizedBox(height: 24),

                    // Основная статистика
                    Text(
                      'Общая статистика',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),

                    _buildMainStats(adminProvider),

                    const SizedBox(height: 24),

                    // Логи активности
                    Text(
                      'Последняя активность',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),

                    _buildRecentActivity(adminLogs),

                    const SizedBox(height: 24),

                    // Быстрые действия
                    Text(
                      'Быстрые действия',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),

                    _buildQuickActions(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWelcomeCard(AdminAuthProvider adminAuth) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 30,
              child: Icon(Icons.person, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Добро пожаловать, ${adminAuth.adminName}!',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (adminAuth.lastLoginTime != null)
                    Text(
                      'Последний вход: ${_formatDateTime(adminAuth.lastLoginTime!)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainStats(AdminProvider adminProvider) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: [
        AdminStatCard(
          title: 'Дети',
          value: adminProvider.childrenCount,
          icon: Icons.child_care,
          color: Colors.blue,
          onTap: () => context.go('/admin/children'),
        ),
        AdminStatCard(
          title: 'Эпизоды',
          value: adminProvider.episodesCount,
          icon: Icons.medical_services,
          color: Colors.red,
          onTap: () => context.go('/admin/episodes'),
        ),
        AdminStatCard(
          title: 'Назначения',
          value: adminProvider.prescriptionsCount,
          icon: Icons.medication,
          color: Colors.green,
        ),
        AdminStatCard(
          title: 'Анализы',
          value: adminProvider.testsCount,
          icon: Icons.science,
          color: Colors.purple,
        ),
        AdminStatCard(
          title: 'Процедуры',
          value: adminProvider.proceduresCount,
          icon: Icons.healing,
          color: Colors.orange,
        ),
        AdminStatCard(
          title: 'Файлы',
          value: adminProvider.attachmentsCount,
          icon: Icons.attach_file,
          color: Colors.teal,
        ),
      ],
    );
  }

  Widget _buildRecentActivity(AdminLogsProvider adminLogs) {
    final recentLogs = adminLogs.getRecentLogs(days: 1).take(5).toList();

    if (recentLogs.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Нет активности за последние 24 часа'),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: recentLogs.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final log = recentLogs[index];
          return ListTile(
            leading: Text(log.actionIcon, style: const TextStyle(fontSize: 24)),
            title: Text(log.description),
            subtitle: Text(_formatDateTime(log.timestamp)),
            trailing: Chip(
              label: Text(log.adminName),
              visualDensity: VisualDensity.compact,
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickActions() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ActionChip(
          avatar: const Icon(Icons.child_care),
          label: const Text('Управление детьми'),
          onPressed: () => context.go('/admin/children'),
        ),
        ActionChip(
          avatar: const Icon(Icons.medical_services),
          label: const Text('Эпизоды болезней'),
          onPressed: () => context.go('/admin/episodes'),
        ),
        ActionChip(
          avatar: const Icon(Icons.history),
          label: const Text('Логи активности'),
          onPressed: () => context.go('/admin/logs'),
        ),
        ActionChip(
          avatar: const Icon(Icons.settings),
          label: const Text('Настройки'),
          onPressed: () => context.go('/admin/settings'),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}.${dateTime.month}.${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
