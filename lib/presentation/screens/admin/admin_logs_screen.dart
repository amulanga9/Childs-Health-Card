import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_logs_provider.dart';
import 'widgets/admin_drawer.dart';

/// Экран логов активности
class AdminLogsScreen extends StatefulWidget {
  const AdminLogsScreen({super.key});

  @override
  State<AdminLogsScreen> createState() => _AdminLogsScreenState();
}

class _AdminLogsScreenState extends State<AdminLogsScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final adminLogs = context.watch<AdminLogsProvider>();
    final logs = _searchQuery.isEmpty
        ? adminLogs.logs
        : adminLogs.search(_searchQuery);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Логи активности'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _exportLogs(adminLogs),
            tooltip: 'Экспорт логов',
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_old',
                child: Text('Очистить старые логи'),
              ),
              const PopupMenuItem(
                value: 'clear_all',
                child: Text('Очистить все логи'),
              ),
            ],
            onSelected: (value) async {
              if (value == 'clear_old') {
                await adminLogs.clearOldLogs(days: 90);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Старые логи очищены')),
                  );
                }
              } else if (value == 'clear_all') {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Очистить все логи?'),
                    content: const Text(
                      'Это действие нельзя отменить.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Отмена'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Очистить'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  await adminLogs.clearAllLogs();
                }
              }
            },
          ),
        ],
      ),
      drawer: const AdminDrawer(),
      body: Column(
        children: [
          // Поиск
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Поиск в логах',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Статистика
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('Всего логов', adminLogs.logsCount),
                    _buildStatItem('За 7 дней', adminLogs.getRecentLogs(days: 7).length),
                    _buildStatItem('За сегодня', adminLogs.filterByDate(DateTime.now()).length),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Список логов
          Expanded(
            child: logs.isEmpty
                ? const Center(child: Text('Нет логов'))
                : ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: Text(
                            log.actionIcon,
                            style: const TextStyle(fontSize: 24),
                          ),
                          title: Text(log.description),
                          subtitle: Text(
                            '${_formatDateTime(log.timestamp)} • ${log.adminName}',
                          ),
                          trailing: Chip(
                            label: Text(log.entityType),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int value) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  void _exportLogs(AdminLogsProvider adminLogs) {
    // Экспорт логов в JSON
    final json = adminLogs.exportToJson();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Экспортировано ${adminLogs.logsCount} логов'),
        action: SnackBarAction(
          label: 'Копировать',
          onPressed: () {
            // Здесь можно добавить копирование в буфер обмена
          },
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}.${dateTime.month}.${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
