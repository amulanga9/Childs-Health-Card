import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';
import '../../../data/database/database.dart';
import 'widgets/admin_drawer.dart';

/// Экран управления эпизодами болезней
class AdminEpisodesScreen extends StatefulWidget {
  const AdminEpisodesScreen({super.key});

  @override
  State<AdminEpisodesScreen> createState() => _AdminEpisodesScreenState();
}

class _AdminEpisodesScreenState extends State<AdminEpisodesScreen> {
  List<Episode> _episodes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEpisodes();
  }

  Future<void> _loadEpisodes() async {
    setState(() => _isLoading = true);
    final episodes = await context.read<AdminProvider>().getAllEpisodes();
    setState(() {
      _episodes = episodes;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Эпизоды болезней'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEpisodes,
          ),
        ],
      ),
      drawer: const AdminDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _episodes.isEmpty
              ? const Center(child: Text('Нет данных'))
              : ListView.builder(
                  itemCount: _episodes.length,
                  itemBuilder: (context, index) {
                    final episode = _episodes[index];
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        leading: const Icon(Icons.medical_services),
                        title: Text(episode.diagnosis),
                        subtitle: Text(
                          'Начало: ${episode.startDate.day}.${episode.startDate.month}.${episode.startDate.year}',
                        ),
                        trailing: Chip(label: Text(episode.status)),
                      ),
                    );
                  },
                ),
    );
  }
}
