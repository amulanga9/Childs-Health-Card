import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/database/database.dart';

/// Виджет верхней панели с профилем ребёнка
class ChildProfileHeader extends StatelessWidget {
  final Child child;
  final VoidCallback? onTap;

  const ChildProfileHeader({
    super.key,
    required this.child,
    this.onTap,
  });

  /// Вычислить возраст ребёнка
  String _calculateAge() {
    final now = DateTime.now();
    final birthDate = child.birthDate;

    int years = now.year - birthDate.year;
    int months = now.month - birthDate.month;

    if (months < 0) {
      years--;
      months += 12;
    }

    if (years > 0) {
      return '$years ${_getYearWord(years)}';
    } else {
      return '$months ${_getMonthWord(months)}';
    }
  }

  /// Склонение слова "год"
  String _getYearWord(int years) {
    if (years % 10 == 1 && years % 100 != 11) return 'год';
    if ([2, 3, 4].contains(years % 10) && ![12, 13, 14].contains(years % 100)) {
      return 'года';
    }
    return 'лет';
  }

  /// Склонение слова "месяц"
  String _getMonthWord(int months) {
    if (months % 10 == 1 && months % 100 != 11) return 'месяц';
    if ([2, 3, 4].contains(months % 10) && ![12, 13, 14].contains(months % 100)) {
      return 'месяца';
    }
    return 'месяцев';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allergies = child.allergies.isEmpty ? [] : child.allergies.split(',');
    final chronicConditions = child.chronicConditions.isEmpty ? [] : child.chronicConditions.split(',');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: Material(
        color: theme.colorScheme.surface,
        elevation: 2,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              children: [
                // Аватар и основная информация
                Row(
                  children: [
                    // Аватар с анимацией
                    Hero(
                      tag: 'child_avatar_${child.id}',
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primary,
                              theme.colorScheme.primaryContainer,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: child.avatar != null && child.avatar!.isNotEmpty
                            ? ClipOval(
                                child: Image.network(
                                  child.avatar!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _buildAvatarPlaceholder(theme),
                                ),
                              )
                            : _buildAvatarPlaceholder(theme),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Имя и возраст
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            child.name,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.cake_outlined,
                                size: 16,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _calculateAge(),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '•',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('dd.MM.yyyy').format(child.birthDate),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Иконка редактирования
                    IconButton(
                      onPressed: onTap,
                      icon: Icon(
                        Icons.edit_outlined,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Медицинская информация (группа крови, аллергии, хронические заболевания)
                _buildMedicalInfo(theme, allergies, chronicConditions),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Аватар по умолчанию
  Widget _buildAvatarPlaceholder(ThemeData theme) {
    return Center(
      child: Text(
        child.name.isNotEmpty ? child.name[0].toUpperCase() : '?',
        style: theme.textTheme.headlineLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Медицинская информация
  Widget _buildMedicalInfo(
    ThemeData theme,
    List<String> allergies,
    List<String> chronicConditions,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Группа крови
        if (child.bloodGroup.isNotEmpty)
          _buildInfoChip(
            theme,
            icon: Icons.bloodtype,
            label: child.bloodGroup,
            color: Colors.red,
          ),
        // Аллергии
        if (allergies.isNotEmpty)
          _buildInfoChip(
            theme,
            icon: Icons.warning_amber_rounded,
            label: 'Аллергии: ${allergies.length}',
            color: Colors.orange,
          ),
        // Хронические заболевания
        if (chronicConditions.isNotEmpty)
          _buildInfoChip(
            theme,
            icon: Icons.local_hospital_outlined,
            label: 'Хрон.: ${chronicConditions.length}',
            color: Colors.blue,
          ),
      ],
    );
  }

  /// Чип с информацией
  Widget _buildInfoChip({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
