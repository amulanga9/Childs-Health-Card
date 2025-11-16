import 'package:flutter/foundation.dart';
import '../../data/database/database.dart';
import '../../data/database/daos/child_dao.dart';
import '../../data/database/daos/episode_dao.dart';

/// Provider для управления состоянием главного экрана
class HomeProvider with ChangeNotifier {
  final AppDatabase _database;
  late final ChildDao _childDao;
  late final EpisodeDao _episodeDao;

  /// Выбранный ребёнок
  Child? _selectedChild;
  Child? get selectedChild => _selectedChild;

  /// Список всех детей
  List<Child> _children = [];
  List<Child> get children => _children;

  /// Эпизоды болезней выбранного ребёнка
  List<Episode> _episodes = [];
  List<Episode> get episodes => _episodes;

  /// Активные (текущие) эпизоды
  List<Episode> get activeEpisodes =>
      _episodes.where((e) => e.status == 'active').toList();

  /// Закрытые эпизоды
  List<Episode> get closedEpisodes =>
      _episodes.where((e) => e.status == 'closed').toList();

  /// Текущий выбранный месяц для календаря
  DateTime _focusedMonth;
  DateTime get focusedMonth => _focusedMonth;

  /// Текущий год для статистики
  int _selectedYear;
  int get selectedYear => _selectedYear;

  /// Статистика за выбранный год
  Map<String, dynamic>? _yearlyStats;
  Map<String, dynamic>? get yearlyStats => _yearlyStats;

  /// События календаря (эпизоды, визиты и т.д.)
  Map<DateTime, List<dynamic>> _calendarEvents = {};
  Map<DateTime, List<dynamic>> get calendarEvents => _calendarEvents;

  /// Состояние загрузки
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  HomeProvider(this._database)
      : _focusedMonth = DateTime.now(),
        _selectedYear = DateTime.now().year {
    _childDao = _database.childDao;
    _episodeDao = _database.episodeDao;
    _initialize();
  }

  /// Инициализация данных
  Future<void> _initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Загружаем список детей
      _children = await _childDao.getAllChildren();

      // Если есть дети, выбираем первого
      if (_children.isNotEmpty) {
        await selectChild(_children.first.id);
      }
    } catch (e) {
      debugPrint('Ошибка инициализации HomeProvider: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Выбрать ребёнка
  Future<void> selectChild(int childId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _selectedChild = await _childDao.getChildById(childId);

      if (_selectedChild != null) {
        // Загружаем эпизоды ребёнка
        await _loadEpisodes();

        // Загружаем статистику
        await _loadYearlyStats();

        // Загружаем события календаря
        await _loadCalendarEvents();
      }
    } catch (e) {
      debugPrint('Ошибка выбора ребёнка: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Загрузить эпизоды ребёнка
  Future<void> _loadEpisodes() async {
    if (_selectedChild == null) return;

    try {
      _episodes = await _episodeDao.getEpisodesByChildId(_selectedChild!.id);
    } catch (e) {
      debugPrint('Ошибка загрузки эпизодов: $e');
    }
  }

  /// Загрузить статистику за год
  Future<void> _loadYearlyStats() async {
    if (_selectedChild == null) return;

    try {
      _yearlyStats = await _episodeDao.getYearlyStatsByChildId(
        _selectedChild!.id,
        _selectedYear,
      );
    } catch (e) {
      debugPrint('Ошибка загрузки статистики: $e');
      _yearlyStats = null;
    }
  }

  /// Загрузить события календаря для выбранного месяца
  Future<void> _loadCalendarEvents() async {
    if (_selectedChild == null) return;

    try {
      _calendarEvents.clear();

      final startOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
      final endOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);

      // Фильтруем эпизоды по месяцу
      final monthEpisodes = _episodes.where((episode) {
        final startDate = episode.startDate;
        final endDate = episode.endDate ?? DateTime.now();

        return (startDate.isBefore(endOfMonth) || startDate.isAtSameMomentAs(endOfMonth)) &&
            (endDate.isAfter(startOfMonth) || endDate.isAtSameMomentAs(startOfMonth));
      }).toList();

      // Группируем эпизоды по дням
      for (final episode in monthEpisodes) {
        final date = DateTime(
          episode.startDate.year,
          episode.startDate.month,
          episode.startDate.day,
        );

        if (_calendarEvents.containsKey(date)) {
          _calendarEvents[date]!.add(episode);
        } else {
          _calendarEvents[date] = [episode];
        }
      }
    } catch (e) {
      debugPrint('Ошибка загрузки событий календаря: $e');
    }
  }

  /// Изменить фокус календаря на другой месяц
  Future<void> changeFocusedMonth(DateTime newMonth) async {
    _focusedMonth = newMonth;
    await _loadCalendarEvents();
    notifyListeners();
  }

  /// Изменить выбранный год для статистики
  Future<void> changeSelectedYear(int year) async {
    _selectedYear = year;
    await _loadYearlyStats();
    notifyListeners();
  }

  /// Обновить данные
  Future<void> refresh() async {
    if (_selectedChild != null) {
      await selectChild(_selectedChild!.id);
    } else {
      await _initialize();
    }
  }

  /// Получить события для конкретной даты
  List<dynamic> getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _calendarEvents[normalizedDay] ?? [];
  }

  /// Проверить, есть ли события в указанный день
  bool hasEventsOnDay(DateTime day) {
    return getEventsForDay(day).isNotEmpty;
  }
}
