import 'package:flutter/foundation.dart';
import '../../data/database/database.dart';
import '../../services/api_service.dart';

/// Состояние генерации QR
enum QRGenerationState {
  idle,
  loading,
  success,
  error,
}

/// Провайдер для работы с QR токенами
class QRProvider with ChangeNotifier {
  final AppDatabase database;
  final ApiService apiService;

  QRProvider({
    required this.database,
    required this.apiService,
  });

  QRGenerationState _state = QRGenerationState.idle;
  QRGenerationState get state => _state;

  QRTokenResponse? _currentToken;
  QRTokenResponse? get currentToken => _currentToken;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<Child> _children = [];
  List<Child> get children => _children;

  Child? _selectedChild;
  Child? get selectedChild => _selectedChild;

  List<Episode> _childEpisodes = [];
  List<Episode> get childEpisodes => _childEpisodes;

  Episode? _selectedEpisode;
  Episode? get selectedEpisode => _selectedEpisode;

  int _expireHours = 48;
  int get expireHours => _expireHours;

  /// Загрузка списка детей
  Future<void> loadChildren() async {
    try {
      _children = await database.childDao.getAllChildren();
      if (_children.isNotEmpty && _selectedChild == null) {
        _selectedChild = _children.first;
        await loadChildEpisodes(_selectedChild!.id);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading children: $e');
    }
  }

  /// Загрузка эпизодов выбранного ребёнка
  Future<void> loadChildEpisodes(int childId) async {
    try {
      _childEpisodes = await database.episodeDao.getEpisodesByChild(childId);
      // Сортировка: активные первыми, затем по дате начала (новые первыми)
      _childEpisodes.sort((a, b) {
        if (a.status == 'active' && b.status != 'active') return -1;
        if (a.status != 'active' && b.status == 'active') return 1;
        return b.startDate.compareTo(a.startDate);
      });
      // Автоматически выбрать первый (последний активный) эпизод
      _selectedEpisode = _childEpisodes.isNotEmpty ? _childEpisodes.first : null;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading episodes: $e');
      _childEpisodes = [];
      _selectedEpisode = null;
      notifyListeners();
    }
  }

  /// Выбор ребёнка
  void selectChild(Child child) {
    _selectedChild = child;
    loadChildEpisodes(child.id);
  }

  /// Выбор эпизода
  void selectEpisode(Episode? episode) {
    _selectedEpisode = episode;
    notifyListeners();
  }

  /// Установка времени действия токена
  void setExpireHours(int hours) {
    _expireHours = hours;
    notifyListeners();
  }

  /// Генерация QR токена
  Future<void> generateQRToken() async {
    if (_selectedChild == null) {
      _state = QRGenerationState.error;
      _errorMessage = 'Выберите ребёнка';
      notifyListeners();
      return;
    }

    _state = QRGenerationState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await apiService.generateQRToken(
        childId: _selectedChild!.id,
        episodeId: _selectedEpisode?.id,
        description: 'Доступ для врача',
        expireHours: _expireHours,
      );

      _currentToken = response;
      _state = QRGenerationState.success;
      notifyListeners();
    } catch (e) {
      _state = QRGenerationState.error;
      _errorMessage = 'Ошибка генерации QR: ${e.toString()}';
      notifyListeners();
      debugPrint('Error generating QR: $e');
    }
  }

  /// Деактивация текущего токена
  Future<void> invalidateCurrentToken() async {
    if (_currentToken == null) return;

    try {
      final success = await apiService.invalidateQRToken(_currentToken!.token);
      if (success) {
        _currentToken = null;
        _state = QRGenerationState.idle;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error invalidating token: $e');
    }
  }

  /// Сброс состояния
  void reset() {
    _state = QRGenerationState.idle;
    _currentToken = null;
    _errorMessage = null;
    _selectedEpisode = null;
    notifyListeners();
  }
}
