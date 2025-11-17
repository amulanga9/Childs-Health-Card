import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';
import '../../../data/database/database.dart';
import 'widgets/admin_drawer.dart';

/// Экран управления детьми
class AdminChildrenScreen extends StatefulWidget {
  const AdminChildrenScreen({super.key});

  @override
  State<AdminChildrenScreen> createState() => _AdminChildrenScreenState();
}

class _AdminChildrenScreenState extends State<AdminChildrenScreen> {
  List<Child> _children = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    setState(() => _isLoading = true);
    final children = await context.read<AdminProvider>().getAllChildren();
    setState(() {
      _children = children;
      _isLoading = false;
    });
  }

  List<Child> get _filteredChildren {
    if (_searchQuery.isEmpty) return _children;
    return _children
        .where((child) =>
            child.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Управление детьми'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadChildren,
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
                labelText: 'Поиск по имени',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Список детей
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredChildren.isEmpty
                    ? const Center(
                        child: Text('Нет данных'),
                      )
                    : ListView.builder(
                        itemCount: _filteredChildren.length,
                        itemBuilder: (context, index) {
                          final child = _filteredChildren[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text(child.name[0]),
                              ),
                              title: Text(child.name),
                              subtitle: Text(
                                'Дата рождения: ${child.birthDate.day}.${child.birthDate.month}.${child.birthDate.year}',
                              ),
                              trailing: PopupMenuButton(
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Удалить'),
                                      ],
                                    ),
                                  ),
                                ],
                                onSelected: (value) async {
                                  if (value == 'delete') {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Удалить ребенка?'),
                                        content: Text(
                                          'Вы уверены, что хотите удалить ${child.name}? Все связанные данные будут удалены.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Отмена'),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text('Удалить'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirmed == true && mounted) {
                                      await context
                                          .read<AdminProvider>()
                                          .deleteChildWithAllData(child.id);
                                      _loadChildren();
                                    }
                                  }
                                },
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
}
