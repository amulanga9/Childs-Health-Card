import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../data/database/database.dart';
import '../providers/episode_detail_provider.dart';
import '../widgets/episode_sections/prescriptions_section.dart';
import '../widgets/episode_sections/tests_section.dart';
import '../widgets/episode_sections/procedures_section.dart';
import '../widgets/episode_sections/attachments_section.dart';

/// Экран деталей эпизода болезни с полным функционалом
class EpisodeDetailScreenNew extends StatefulWidget {
  final int episodeId;

  const EpisodeDetailScreenNew({
    super.key,
    required this.episodeId,
  });

  @override
  State<EpisodeDetailScreenNew> createState() => _EpisodeDetailScreenNewState();
}

class _EpisodeDetailScreenNewState extends State<EpisodeDetailScreenNew>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => EpisodeDetailProvider(
        context.read<AppDatabase>(),
        widget.episodeId,
      ),
      child: Consumer<EpisodeDetailProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (provider.episode == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Ошибка')),
              body: const Center(child: Text('Эпизод не найден')),
            );
          }

          return _buildContent(context, provider);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, EpisodeDetailProvider provider) {
    final theme = Theme.of(context);
    final episode = provider.episode!;
    final isActive = episode.status == 'active';

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Шапка с диагнозом и Hero анимацией
          _buildSliverAppBar(theme, episode, isActive),

          // Контент с секциями
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Основная информация
                      _buildInfoSection(theme, episode, isActive),
                      const SizedBox(height: 24),

                      // Цепочка эпизодов
                      if (provider.episodeChain != null &&
                          provider.episodeChain!.length > 1) ...[
                        _buildChainSection(theme, provider.episodeChain!, episode.id),
                        const SizedBox(height: 24),
                      ],

                      // Назначения лекарств
                      if (provider.prescriptions.isNotEmpty) ...[
                        PrescriptionsSection(
                          prescriptions: provider.prescriptions,
                          intakesByPrescription: provider.intakesByPrescription,
                          onMarkIntake: (prescriptionId, time, taken, reason) {
                            provider.markIntake(
                              prescriptionId: prescriptionId,
                              atDatetime: time,
                              taken: taken,
                              reasonSkip: reason,
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Анализы
                      if (provider.tests.isNotEmpty) ...[
                        TestsSection(
                          tests: provider.tests,
                          attachments: provider.attachments,
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Процедуры
                      if (provider.procedures.isNotEmpty) ...[
                        ProceduresSection(
                          procedures: provider.procedures,
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Вложения
                      AttachmentsSection(
                        attachments: provider.attachments,
                        onAddAttachment: () => _showAddAttachmentDialog(context, provider),
                        onDeleteAttachment: (id) => _confirmDelete(
                          context,
                          'Удалить вложение?',
                          () => provider.deleteAttachment(id),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Заметки
                      _buildNotesSection(theme, episode, provider),
                      const SizedBox(height: 100), // Для кнопок действий
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

      // Кнопки действий
      bottomNavigationBar: _buildActionButtons(context, theme, episode, provider),
    );
  }

  /// Шапка с Hero анимацией
  Widget _buildSliverAppBar(ThemeData theme, Episode episode, bool isActive) {
    final accentColor = isActive ? Colors.red.shade600 : Colors.green.shade600;

    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: accentColor,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          episode.diagnosis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        background: Hero(
          tag: 'episode_card_${episode.id}',
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accentColor,
                  accentColor.withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isActive ? 'Активный эпизод' : 'Завершён',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Основная информация об эпизоде
  Widget _buildInfoSection(ThemeData theme, Episode episode, bool isActive) {
    final duration = episode.endDate != null
        ? episode.endDate!.difference(episode.startDate).inDays
        : DateTime.now().difference(episode.startDate).inDays;
    final accentColor = isActive ? Colors.red.shade600 : Colors.green.shade600;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Информация',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            theme,
            icon: Icons.calendar_today,
            label: 'Начало',
            value: DateFormat('dd.MM.yyyy').format(episode.startDate),
          ),
          if (episode.endDate != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              theme,
              icon: Icons.event_available,
              label: 'Окончание',
              value: DateFormat('dd.MM.yyyy').format(episode.endDate!),
            ),
          ],
          const SizedBox(height: 12),
          _buildInfoRow(
            theme,
            icon: Icons.timelapse,
            label: 'Длительность',
            value: '$duration дней',
            valueColor: accentColor,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor ?? theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  /// Цепочка эпизодов
  Widget _buildChainSection(ThemeData theme, List<Episode> chain, int currentId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'История развития болезни',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: List.generate(chain.length, (index) {
              final episode = chain[index];
              final isCurrent = episode.id == currentId;

              return Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surfaceVariant,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isCurrent
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              episode.diagnosis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: isCurrent
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            Text(
                              DateFormat('dd.MM.yyyy').format(episode.startDate),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (index < chain.length - 1)
                    Padding(
                      padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
                      child: Icon(
                        Icons.arrow_downward,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  /// Секция заметок
  Widget _buildNotesSection(
    ThemeData theme,
    Episode episode,
    EpisodeDetailProvider provider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Заметки',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _showEditNotesDialog(context, episode, provider),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Text(
            episode.notes.isEmpty ? 'Нет заметок' : episode.notes,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: episode.notes.isEmpty
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  /// Кнопки действий
  Widget _buildActionButtons(
    BuildContext context,
    ThemeData theme,
    Episode episode,
    EpisodeDetailProvider provider,
  ) {
    final isActive = episode.status == 'active';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Закрыть эпизод
            if (isActive)
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _confirmCloseEpisode(context, provider),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Закрыть'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
              ),

            if (isActive) const SizedBox(width: 12),

            // Создать новый эпизод ("переросло в...")
            if (isActive)
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _showCreateChildEpisodeDialog(context, provider),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Новый'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                ),
              ),

            const SizedBox(width: 12),

            // Показать QR
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showQRDialog(context, episode),
                icon: const Icon(Icons.qr_code),
                label: const Text('QR'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============ Диалоги ============

  void _confirmCloseEpisode(BuildContext context, EpisodeDetailProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Закрыть эпизод?'),
        content: const Text(
          'Эпизод будет отмечен как завершённый. Вы сможете просмотреть его позже в истории.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await provider.closeEpisode();
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Эпизод закрыт')),
                );
              }
            },
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  void _showCreateChildEpisodeDialog(
    BuildContext context,
    EpisodeDetailProvider provider,
  ) {
    final diagnosisController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Болезнь переросла в новое заболевание'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: diagnosisController,
              decoration: const InputDecoration(
                labelText: 'Новый диагноз',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Заметки',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              if (diagnosisController.text.isNotEmpty) {
                Navigator.pop(context);
                final newId = await provider.createChildEpisode(
                  diagnosis: diagnosisController.text,
                  notes: notesController.text,
                );
                if (newId != null && context.mounted) {
                  context.go('/episode/$newId');
                }
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  void _showEditNotesDialog(
    BuildContext context,
    Episode episode,
    EpisodeDetailProvider provider,
  ) {
    final controller = TextEditingController(text: episode.notes);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Редактировать заметки'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
          maxLines: 5,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              provider.updateNotes(controller.text);
              Navigator.pop(context);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showAddAttachmentDialog(
    BuildContext context,
    EpisodeDetailProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Добавить вложение'),
        content: const Text('Функция добавления файлов в разработке'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showQRDialog(BuildContext context, Episode episode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('QR код эпизода'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code, size: 120),
            const SizedBox(height: 16),
            Text(
              'ID: ${episode.id}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            const Text('Функция в разработке'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String title, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }
}
