import 'package:hive/hive.dart';

part 'procedure.g.dart';

/// Модель данных медицинской процедуры
/// Хранит информацию о процедурах (физиотерапия, операции и т.д.)
@HiveType(typeId: 6)
class MedicalProcedure {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String illnessId; // Связь с болезнью

  @HiveField(2)
  final String childId;

  @HiveField(3)
  final String title;

  @HiveField(4)
  final String description;

  @HiveField(5)
  final DateTime procedureDate;

  @HiveField(6)
  final String? location; // Где проводилась (больница, клиника)

  @HiveField(7)
  final String? performedBy; // Кто проводил

  @HiveField(8)
  final String? notes; // Дополнительные заметки

  @HiveField(9)
  final DateTime createdAt;

  @HiveField(10)
  final DateTime updatedAt;

  MedicalProcedure({
    required this.id,
    required this.illnessId,
    required this.childId,
    required this.title,
    required this.description,
    required this.procedureDate,
    this.location,
    this.performedBy,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  MedicalProcedure copyWith({
    String? id,
    String? illnessId,
    String? childId,
    String? title,
    String? description,
    DateTime? procedureDate,
    String? location,
    String? performedBy,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MedicalProcedure(
      id: id ?? this.id,
      illnessId: illnessId ?? this.illnessId,
      childId: childId ?? this.childId,
      title: title ?? this.title,
      description: description ?? this.description,
      procedureDate: procedureDate ?? this.procedureDate,
      location: location ?? this.location,
      performedBy: performedBy ?? this.performedBy,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
