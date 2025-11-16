import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Экран детального просмотра болезни
/// Показывает информацию об эпизоде болезни:
/// - Визиты к врачу
/// - Анализы
/// - Процедуры
/// - Назначенные лекарства
class IllnessDetailScreen extends StatefulWidget {
  final String illnessId;

  const IllnessDetailScreen({
    super.key,
    required this.illnessId,
  });

  @override
  State<IllnessDetailScreen> createState() => _IllnessDetailScreenState();
}

class _IllnessDetailScreenState extends State<IllnessDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.illness),
        actions: [
          // Кнопка редактирования
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: Открыть форму редактирования болезни
            },
          ),
          // Кнопка удаления
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              // TODO: Показать диалог подтверждения удаления
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(text: l10n.visits),
            Tab(text: l10n.tests),
            Tab(text: l10n.procedures),
            Tab(text: l10n.medications),
          ],
        ),
      ),
      body: Column(
        children: [
          // Основная информация о болезни
          _IllnessHeader(),
          const Divider(),
          // Вкладки с детальной информацией
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _VisitsTab(),
                _TestsTab(),
                _ProceduresTab(),
                _MedicationsTab(),
              ],
            ),
          ),
        ],
      ),
      // Плавающие кнопки для добавления записей
      floatingActionButton: _buildFAB(context),
    );
  }

  Widget _buildFAB(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    switch (_tabController.index) {
      case 0:
        return FloatingActionButton.extended(
          onPressed: () {
            // TODO: Добавить визит
          },
          icon: const Icon(Icons.add),
          label: Text(l10n.addVisit),
        );
      case 1:
        return FloatingActionButton.extended(
          onPressed: () {
            // TODO: Добавить анализ
          },
          icon: const Icon(Icons.add),
          label: Text(l10n.addTest),
        );
      case 2:
        return FloatingActionButton.extended(
          onPressed: () {
            // TODO: Добавить процедуру
          },
          icon: const Icon(Icons.add),
          label: Text(l10n.addProcedure),
        );
      case 3:
        return FloatingActionButton.extended(
          onPressed: () {
            // TODO: Добавить лекарство
          },
          icon: const Icon(Icons.add),
          label: Text(l10n.addMedication),
        );
      default:
        return FloatingActionButton(
          onPressed: () {},
          child: const Icon(Icons.add),
        );
    }
  }
}

/// Заголовок с основной информацией о болезни
class _IllnessHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Грипп', // TODO: Заменить на реальные данные
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Chip(
                label: const Text('Активна'),
                backgroundColor: Colors.red.shade100,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Начало: 15.11.2025', // TODO: Заменить на реальные данные
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Продолжительность: 5 дней', // TODO: Заменить на реальные данные
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'Высокая температура, кашель, насморк', // TODO: Заменить на реальное описание
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// Вкладка "Визиты к врачу"
class _VisitsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // TODO: Заменить на реальные данные из Provider
    return ListView.builder(
      itemCount: 3,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: const Icon(Icons.local_hospital),
            title: Text('Педиатр Иванов И.И.'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Дата: 16.11.2025'),
                Text('Диагноз: ОРВИ'),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Открыть детали визита
            },
          ),
        );
      },
    );
  }
}

/// Вкладка "Анализы"
class _TestsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 2,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: const Icon(Icons.science),
            title: const Text('Общий анализ крови'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Дата: 16.11.2025'),
                Text('Лаборатория: ЛабМед'),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Открыть результаты анализа
            },
          ),
        );
      },
    );
  }
}

/// Вкладка "Процедуры"
class _ProceduresTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 2,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: const Icon(Icons.healing),
            title: const Text('Ингаляция'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Дата: 17.11.2025'),
                Text('Место: Детская поликлиника №5'),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Открыть детали процедуры
            },
          ),
        );
      },
    );
  }
}

/// Вкладка "Лекарства"
class _MedicationsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 4,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: const Icon(Icons.medication),
            title: const Text('Парацетамол'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Дозировка: 500 мг'),
                Text('Частота: 3 раза в день'),
                Text('Курс: 15.11.2025 - 20.11.2025'),
              ],
            ),
            trailing: Checkbox(
              value: true,
              onChanged: (value) {
                // TODO: Отметить приём лекарства
              },
            ),
          ),
        );
      },
    );
  }
}
