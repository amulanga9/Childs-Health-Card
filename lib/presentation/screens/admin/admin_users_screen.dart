import 'package:flutter/material.dart';
import 'widgets/admin_drawer.dart';

/// Экран управления пользователями (профилями)
class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Управление пользователями'),
      ),
      drawer: const AdminDrawer(),
      body: const Center(
        child: Text('Управление пользовательскими профилями'),
      ),
    );
  }
}
