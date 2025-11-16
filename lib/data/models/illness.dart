import 'package:hive/hive.dart';

part 'illness.g.dart';

/// Модель данных болезни/эпизода заболевания
/// Хранит информацию о конкретном случае болезни ребёнка
@HiveType(typeId: 2)
class Illness {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String childId;

  @HiveField(2)
  final String title;

  @HiveField(3)
  final String description;

  @HiveField(4)
  final DateTime startDate;

  @HiveField(5)
  final DateTime? endDate;

  @HiveField(6)
  final IllnessStatus status;

  @HiveField(7)
  final List<String> symptoms; // Симптомы

  @HiveField(8)
  final DateTime createdAt;

  @HiveField(9)
  final DateTime updatedAt;

  Illness({
    required this.id,
    required this.childId,
    required this.title,
    required this.description,
    required this.startDate,
    this.endDate,
    required this.status,
    this.symptoms = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// Продолжительность болезни в днях
  int get durationInDays {
    final end = endDate ?? DateTime.now();
    return end.difference(startDate).inDays;
  }

  Illness copyWith({
    String? id,
    String? childId,
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    IllnessStatus? status,
    List<String>? symptoms,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Illness(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      title: title ?? this.title,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      symptoms: symptoms ?? this.symptoms,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

@HiveType(typeId: 3)
enum IllnessStatus {
  @HiveField(0)
  active, // Активная болезнь

  @HiveField(1)
  recovered, // Выздоровел

  @HiveField(2)
  chronic, // Хроническое
}
