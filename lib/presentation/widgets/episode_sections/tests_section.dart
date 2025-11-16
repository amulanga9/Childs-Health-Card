import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/database/database.dart';

/// Секция анализов с возможностью просмотра файлов
class TestsSection extends StatelessWidget {
  final List<Test> tests;
  final List<Attachment> attachments;
  final Function(int testId)? onTestTap;

  const TestsSection({
    super.key,
    required this.tests,
    required this.attachments,
    this.onTestTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (tests.isEmpty) {
      return _buildEmptyState(theme);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.science_outlined,
              color: theme.colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'Анализы',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...tests.map((test) {
          final attachment = test.attachmentId != null
              ? attachments.where((a) => a.id == test.attachmentId).firstOrNull
              : null;

          return _TestCard(
            test: test,
            attachment: attachment,
            onTap: onTestTap != null ? () => onTestTap!(test.id) : null,
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
              Icons.science_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Нет анализов',
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

/// Карточка отдельного анализа
class _TestCard extends StatelessWidget {
  final Test test;
  final Attachment? attachment;
  final VoidCallback? onTap;

  const _TestCard({
    required this.test,
    this.attachment,
    this.onTap,
  });

  IconData _getTestIcon(String kind) {
    switch (kind.toLowerCase()) {
      case 'кровь':
      case 'blood':
        return Icons.bloodtype;
      case 'моча':
      case 'urine':
        return Icons.opacity;
      case 'рентген':
      case 'xray':
        return Icons.medical_services;
      default:
        return Icons.science;
    }
  }

  Color _getTestColor(String kind) {
    switch (kind.toLowerCase()) {
      case 'кровь':
      case 'blood':
        return Colors.red;
      case 'моча':
      case 'urine':
        return Colors.amber;
      case 'рентген':
      case 'xray':
        return Colors.blue;
      default:
        return Colors.purple;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final testColor = _getTestColor(test.kind);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: testColor.withOpacity(0.3),
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
              // Иконка типа анализа
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: testColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getTestIcon(test.kind),
                  color: testColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              // Информация об анализе
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      test.kind,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('dd.MM.yyyy HH:mm').format(test.atDatetime),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (test.resultText.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        test.resultText,
                        style: theme.textTheme.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (attachment != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.attach_file,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Прикреплён файл',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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
