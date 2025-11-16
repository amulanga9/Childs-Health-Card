import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/database/database.dart';
import '../animated_check_box.dart';

/// Секция назначений лекарств с чекбоксами приёма
class PrescriptionsSection extends StatelessWidget {
  final List<Prescription> prescriptions;
  final Map<int, List<Intake>> intakesByPrescription;
  final Function(int prescriptionId, DateTime time, bool taken, String? reason) onMarkIntake;

  const PrescriptionsSection({
    super.key,
    required this.prescriptions,
    required this.intakesByPrescription,
    required this.onMarkIntake,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (prescriptions.isEmpty) {
      return _buildEmptyState(theme);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.medication,
              color: theme.colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'Назначения',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...prescriptions.map((prescription) {
          return _PrescriptionCard(
            prescription: prescription,
            intakes: intakesByPrescription[prescription.id] ?? [],
            onMarkIntake: (time, taken, reason) =>
                onMarkIntake(prescription.id, time, taken, reason),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.medication_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Нет назначений',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Карточка отдельного назначения
class _PrescriptionCard extends StatefulWidget {
  final Prescription prescription;
  final List<Intake> intakes;
  final Function(DateTime time, bool taken, String? reason) onMarkIntake;

  const _PrescriptionCard({
    required this.prescription,
    required this.intakes,
    required this.onMarkIntake,
  });

  @override
  State<_PrescriptionCard> createState() => _PrescriptionCardState();
}

class _PrescriptionCardState extends State<_PrescriptionCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
  }

  List<DateTime> _getScheduleTimes() {
    // Парсим расписание (например, "08:00, 14:00, 20:00")
    final schedule = widget.prescription.schedule;
    final times = <DateTime>[];
    final now = DateTime.now();

    // Простой парсер времени
    final timePattern = RegExp(r'(\d{1,2}):(\d{2})');
    final matches = timePattern.allMatches(schedule);

    for (final match in matches) {
      final hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      times.add(DateTime(now.year, now.month, now.day, hour, minute));
    }

    return times;
  }

  Intake? _getIntakeForTime(DateTime time) {
    return widget.intakes.where((intake) {
      return intake.atDatetime.hour == time.hour &&
          intake.atDatetime.minute == time.minute &&
          intake.atDatetime.day == time.day;
    }).firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = widget.prescription.endDate == null ||
        widget.prescription.endDate!.isAfter(DateTime.now());
    final times = _getScheduleTimes();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? theme.colorScheme.primary.withOpacity(0.3)
              : theme.colorScheme.outline.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Заголовок с названием лекарства
          InkWell(
            onTap: _toggleExpand,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Иконка лекарства
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.medication,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Информация о лекарстве
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.prescription.drugName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Доза: ${widget.prescription.dose}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Кнопка раскрытия
                  RotationTransition(
                    turns: Tween(begin: 0.0, end: 0.5).animate(_expandAnimation),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Раскрывающаяся секция с расписанием
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Column(
              children: [
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'График приёма на сегодня:',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...times.map((time) {
                        final intake = _getIntakeForTime(time);
                        final timeStr = DateFormat('HH:mm').format(time);
                        final isPast = time.isBefore(DateTime.now());

                        return _IntakeCheckItem(
                          time: timeStr,
                          intake: intake,
                          isPast: isPast,
                          onChanged: (taken, reason) {
                            widget.onMarkIntake(time, taken, reason);
                          },
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Элемент отметки приёма с чекбоксом
class _IntakeCheckItem extends StatefulWidget {
  final String time;
  final Intake? intake;
  final bool isPast;
  final Function(bool taken, String? reason) onChanged;

  const _IntakeCheckItem({
    required this.time,
    required this.intake,
    required this.isPast,
    required this.onChanged,
  });

  @override
  State<_IntakeCheckItem> createState() => _IntakeCheckItemState();
}

class _IntakeCheckItemState extends State<_IntakeCheckItem> {
  void _showSkipReasonDialog() {
    final controller = TextEditingController(
      text: widget.intake?.reasonSkip ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Причина пропуска'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Укажите причину...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              widget.onChanged(false, controller.text);
              Navigator.pop(context);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final taken = widget.intake?.taken ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Время
          SizedBox(
            width: 60,
            child: Text(
              widget.time,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: widget.isPast
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Чекбокс "Принял"
          AnimatedCheckBox(
            value: taken,
            onChanged: (value) {
              widget.onChanged(value, null);
            },
            activeColor: Colors.green,
            size: 28,
          ),
          const SizedBox(width: 8),
          Text(
            'Принял',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: taken ? Colors.green : theme.colorScheme.onSurfaceVariant,
              fontWeight: taken ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          const Spacer(),
          // Кнопка "Пропустил"
          TextButton.icon(
            onPressed: _showSkipReasonDialog,
            icon: Icon(
              Icons.cancel_outlined,
              size: 18,
              color: widget.intake != null && !taken
                  ? Colors.orange
                  : theme.colorScheme.onSurfaceVariant,
            ),
            label: Text(
              'Пропустил',
              style: TextStyle(
                color: widget.intake != null && !taken
                    ? Colors.orange
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ],
      ),
    );
  }
}
