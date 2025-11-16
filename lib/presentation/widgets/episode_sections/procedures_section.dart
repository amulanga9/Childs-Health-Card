import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/database/database.dart';

/// Секция процедур
class ProceduresSection extends StatelessWidget {
  final List<Procedure> procedures;
  final Function(int procedureId)? onProcedureTap;

  const ProceduresSection({
    super.key,
    required this.procedures,
    this.onProcedureTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (procedures.isEmpty) {
      return _buildEmptyState(theme);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.medical_services_outlined,
              color: theme.colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'Процедуры',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...procedures.map((procedure) {
          return _ProcedureCard(
            procedure: procedure,
            onTap: onProcedureTap != null
                ? () => onProcedureTap!(procedure.id)
                : null,
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
              Icons.medical_services_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Нет процедур',
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

/// Карточка отдельной процедуры
class _ProcedureCard extends StatelessWidget {
  final Procedure procedure;
  final VoidCallback? onTap;

  const _ProcedureCard({
    required this.procedure,
    this.onTap,
  });

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'выполнена':
        return Colors.green;
      case 'scheduled':
      case 'запланирована':
        return Colors.blue;
      case 'cancelled':
      case 'отменена':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'Выполнена';
      case 'scheduled':
        return 'Запланирована';
      case 'cancelled':
        return 'Отменена';
      default:
        return status;
    }
  }

  IconData _getProcedureIcon(String kind) {
    switch (kind.toLowerCase()) {
      case 'укол':
      case 'injection':
        return Icons.vaccines;
      case 'капельница':
      case 'infusion':
      case 'iv':
        return Icons.water_drop;
      case 'ингаляция':
      case 'inhalation':
        return Icons.air;
      case 'физиотерапия':
      case 'physiotherapy':
        return Icons.accessible;
      default:
        return Icons.medical_services;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _getStatusColor(procedure.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Иконка типа процедуры
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getProcedureIcon(procedure.kind),
                  color: statusColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              // Информация о процедуре
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            procedure.kind,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // Статус
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getStatusText(procedure.status),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('dd.MM.yyyy HH:mm').format(procedure.atDatetime),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (procedure.note.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        procedure.note,
                        style: theme.textTheme.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Стрелка если есть действие
              if (onTap != null)
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
