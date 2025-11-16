import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/settings_provider.dart';
import '../../../data/database/database.dart';

/// Секция управления профилями детей
class ChildrenManagementSection extends StatelessWidget {
  const ChildrenManagementSection({super.key});

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
                      Icons.child_care,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Профили детей',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${settings.children.length} из 5',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (settings.canAddChild)
                      IconButton(
                        onPressed: () => _showAddChildDialog(context),
                        icon: const Icon(Icons.add_circle_outline),
                        tooltip: 'Добавить ребенка',
                      ),
                  ],
                ),
              ),
              if (settings.children.isNotEmpty) const Divider(height: 1),
              ...settings.children.map((child) {
                return _ChildTile(
                  child: child,
                  onEdit: () => _showEditChildDialog(context, child),
                  onDelete: () => _showDeleteChildDialog(context, child),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  void _showAddChildDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _ChildDialog(),
    );
  }

  void _showEditChildDialog(BuildContext context, Child child) {
    showDialog(
      context: context,
      builder: (context) => _ChildDialog(child: child),
    );
  }

  void _showDeleteChildDialog(BuildContext context, Child child) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить профиль'),
        content: Text(
          'Вы действительно хотите удалить профиль "${child.name}"?\n\n'
          'Все связанные данные (эпизоды, назначения, анализы) также будут удалены.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              final settings = context.read<SettingsProvider>();
              await settings.deleteChild(child.id);

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Профиль "${child.name}" удален'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }
}

/// Плитка ребенка
class _ChildTile extends StatelessWidget {
  final Child child;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ChildTile({
    required this.child,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final age = _calculateAge(child.birthDate);

    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage:
                  child.avatar.isNotEmpty ? NetworkImage(child.avatar) : null,
              child: child.avatar.isEmpty
                  ? const Icon(Icons.child_care, size: 24)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    child.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$age • ${DateFormat('dd.MM.yyyy').format(child.birthDate)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (child.bloodGroup.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Группа крови: ${child.bloodGroup}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              onPressed: onDelete,
              icon: Icon(
                Icons.delete_outline,
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int years = now.year - birthDate.year;
    int months = now.month - birthDate.month;

    if (months < 0) {
      years--;
      months += 12;
    }

    if (years > 0) {
      return '$years ${_getYearsWord(years)}';
    } else {
      return '$months ${_getMonthsWord(months)}';
    }
  }

  String _getYearsWord(int years) {
    if (years % 10 == 1 && years % 100 != 11) return 'год';
    if ([2, 3, 4].contains(years % 10) && ![12, 13, 14].contains(years % 100)) {
      return 'года';
    }
    return 'лет';
  }

  String _getMonthsWord(int months) {
    if (months % 10 == 1 && months % 100 != 11) return 'месяц';
    if ([2, 3, 4].contains(months % 10) &&
        ![12, 13, 14].contains(months % 100)) {
      return 'месяца';
    }
    return 'месяцев';
  }
}

/// Диалог добавления/редактирования ребенка
class _ChildDialog extends StatefulWidget {
  final Child? child;

  const _ChildDialog({this.child});

  @override
  State<_ChildDialog> createState() => _ChildDialogState();
}

class _ChildDialogState extends State<_ChildDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _bloodGroupController;
  late final TextEditingController _allergiesController;
  late final TextEditingController _chronicController;
  DateTime? _birthDate;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.child?.name ?? '');
    _bloodGroupController =
        TextEditingController(text: widget.child?.bloodGroup ?? '');
    _allergiesController =
        TextEditingController(text: widget.child?.allergies ?? '');
    _chronicController =
        TextEditingController(text: widget.child?.chronicConditions ?? '');
    _birthDate = widget.child?.birthDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bloodGroupController.dispose();
    _allergiesController.dispose();
    _chronicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.child != null;

    return AlertDialog(
      title: Text(isEdit ? 'Редактировать профиль' : 'Новый профиль'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Имя *',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Дата рождения *'),
              subtitle: Text(
                _birthDate != null
                    ? DateFormat('dd.MM.yyyy').format(_birthDate!)
                    : 'Не выбрано',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _selectDate(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: theme.colorScheme.outline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bloodGroupController,
              decoration: const InputDecoration(
                labelText: 'Группа крови',
                border: OutlineInputBorder(),
                hintText: 'I (O)+, II (A)-, III (B)+, IV (AB)-',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _allergiesController,
              decoration: const InputDecoration(
                labelText: 'Аллергии',
                border: OutlineInputBorder(),
                hintText: 'Разделяйте запятыми',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _chronicController,
              decoration: const InputDecoration(
                labelText: 'Хронические заболевания',
                border: OutlineInputBorder(),
                hintText: 'Разделяйте запятыми',
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => _save(context),
          child: Text(isEdit ? 'Сохранить' : 'Добавить'),
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (date != null) {
      setState(() {
        _birthDate = date;
      });
    }
  }

  Future<void> _save(BuildContext context) async {
    if (_nameController.text.isEmpty || _birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заполните обязательные поля'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final settings = context.read<SettingsProvider>();

    if (widget.child != null) {
      // Редактирование
      final updated = widget.child!.copyWith(
        name: _nameController.text.trim(),
        birthDate: _birthDate!,
        bloodGroup: _bloodGroupController.text.trim(),
        allergies: _allergiesController.text.trim(),
        chronicConditions: _chronicController.text.trim(),
      );
      await settings.updateChild(updated);
    } else {
      // Добавление
      await settings.addChild(
        ChildrenCompanion.insert(
          name: _nameController.text.trim(),
          birthDate: _birthDate!,
          bloodGroup: _bloodGroupController.text.trim(),
          allergies: _allergiesController.text.trim(),
          chronicConditions: _chronicController.text.trim(),
          avatar: '',
        ),
      );
    }

    if (context.mounted) {
      Navigator.pop(context);
    }
  }
}
