import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/database/database.dart';
import '../../data/database/daos/episode_dao.dart';
import '../../data/database/daos/prescription_dao.dart';

/// Экран деталей эпизода болезни с Hero анимацией
class EpisodeDetailScreen extends StatefulWidget {
  final int episodeId;

  const EpisodeDetailScreen({
    super.key,
    required this.episodeId,
  });

  @override
  State<EpisodeDetailScreen> createState() => _EpisodeDetailScreenState();
}

class _EpisodeDetailScreenState extends State<EpisodeDetailScreen>
    with SingleTickerProviderStateMixin {
  Episode? _episode;
  List<Episode>? _episodeChain;
  List<Prescription>? _prescriptions;
  bool _isLoading = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadEpisodeData();
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

  Future<void> _loadEpisodeData() async {
    setState(() => _isLoading = true);

    try {
      final database = AppDatabase();
      final episodeDao = database.episodeDao;
      final prescriptionDao = database.prescriptionDao;

      // Загружаем эпизод
      _episode = await episodeDao.getEpisodeById(widget.episodeId);

      if (_episode != null) {
        // Загружаем цепочку эпизодов
        _episodeChain = await episodeDao.getEpisodesChain(widget.episodeId);

        // Загружаем назначения
        _prescriptions = await prescriptionDao.getPrescriptionsByEpisodeId(widget.episodeId);
      }
    } catch (e) {
      debugPrint('Ошибка загрузки эпизода: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.colorScheme.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_episode == null) {
      return Scaffold(
        backgroundColor: theme.colorScheme.background,
        appBar: AppBar(title: const Text('Ошибка')),
        body: const Center(child: Text('Эпизод не найден')),
      );
    }

    final isActive = _episode!.status == 'active';
    final backgroundColor = isActive ? Colors.red.shade50 : Colors.green.shade50;
    final accentColor = isActive ? Colors.red.shade600 : Colors.green.shade600;

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Анимированная шапка с Hero
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: accentColor,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                _episode!.diagnosis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Hero(
                tag: 'episode_card_${_episode!.id}',
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
          ),
          // Контент с анимациями
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
                      _buildInfoSection(theme, accentColor),
                      const SizedBox(height: 24),
                      // Цепочка эпизодов
                      if (_episodeChain != null && _episodeChain!.length > 1) ...[
                        _buildChainSection(theme),
                        const SizedBox(height: 24),
                      ],
                      // Заметки
                      if (_episode!.notes.isNotEmpty) ...[
                        _buildNotesSection(theme),
                        const SizedBox(height: 24),
                      ],
                      // Назначения
                      if (_prescriptions != null && _prescriptions!.isNotEmpty) ...[
                        _buildPrescriptionsSection(theme),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Секция основной информации
  Widget _buildInfoSection(ThemeData theme, Color accentColor) {
    final duration = _episode!.endDate != null
        ? _episode!.endDate!.difference(_episode!.startDate).inDays
        : DateTime.now().difference(_episode!.startDate).inDays;

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
            value: DateFormat('dd.MM.yyyy').format(_episode!.startDate),
          ),
          if (_episode!.endDate != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              theme,
              icon: Icons.event_available,
              label: 'Окончание',
              value: DateFormat('dd.MM.yyyy').format(_episode!.endDate!),
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

  /// Секция цепочки эпизодов
  Widget _buildChainSection(ThemeData theme) {
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
            children: List.generate(_episodeChain!.length, (index) {
              final episode = _episodeChain![index];
              final isCurrent = episode.id == _episode!.id;

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
                                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
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
                  if (index < _episodeChain!.length - 1)
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
  Widget _buildNotesSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Заметки',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
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
            _episode!.notes,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  /// Секция назначений
  Widget _buildPrescriptionsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Назначения',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ..._prescriptions!.map((prescription) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.medication,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        prescription.drugName,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Доза: ${prescription.dose}',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  'График: ${prescription.schedule}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}
