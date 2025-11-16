import 'package:hive/hive.dart';

part 'medication.g.dart';

/// Модель данных назначенного лекарства
/// Хранит информацию о назначениях лекарств
@HiveType(typeId: 7)
class Medication {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String illnessId; // Связь с болезнью

  @HiveField(2)
  final String childId;

  @HiveField(3)
  final String name; // Название лекарства

  @HiveField(4)
  final String dosage; // Дозировка

  @HiveField(5)
  final String frequency; // Частота приёма (напр. "3 раза в день")

  @HiveField(6)
  final DateTime startDate;

  @HiveField(7)
  final DateTime? endDate;

  @HiveField(8)
  final String? instructions; // Инструкции по применению

  @HiveField(9)
  final String? prescribedBy; // Кто назначил

  @HiveField(10)
  final bool isActive; // Активное назначение

  @HiveField(11)
  final DateTime createdAt;

  @HiveField(12)
  final DateTime updatedAt;

  Medication({
    required this.id,
    required this.illnessId,
    required this.childId,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.startDate,
    this.endDate,
    this.instructions,
    this.prescribedBy,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Курс приёма в днях
  int? get durationInDays {
    if (endDate == null) return null;
    return endDate!.difference(startDate).inDays;
  }

  Medication copyWith({
    String? id,
    String? illnessId,
    String? childId,
    String? name,
    String? dosage,
    String? frequency,
    DateTime? startDate,
    DateTime? endDate,
    String? instructions,
    String? prescribedBy,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Medication(
      id: id ?? this.id,
      illnessId: illnessId ?? this.illnessId,
      childId: childId ?? this.childId,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      instructions: instructions ?? this.instructions,
      prescribedBy: prescribedBy ?? this.prescribedBy,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
