import 'package:hive/hive.dart';

part 'doctor_visit.g.dart';

/// Модель данных визита к врачу
/// Хранит информацию о посещении врача
@HiveType(typeId: 4)
class DoctorVisit {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String illnessId; // Связь с болезнью

  @HiveField(2)
  final String childId;

  @HiveField(3)
  final DateTime visitDate;

  @HiveField(4)
  final String doctorName;

  @HiveField(5)
  final String specialization; // Специализация врача

  @HiveField(6)
  final String diagnosis;

  @HiveField(7)
  final String recommendations;

  @HiveField(8)
  final String? notes; // Дополнительные заметки

  @HiveField(9)
  final DateTime createdAt;

  @HiveField(10)
  final DateTime updatedAt;

  DoctorVisit({
    required this.id,
    required this.illnessId,
    required this.childId,
    required this.visitDate,
    required this.doctorName,
    required this.specialization,
    required this.diagnosis,
    required this.recommendations,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  DoctorVisit copyWith({
    String? id,
    String? illnessId,
    String? childId,
    DateTime? visitDate,
    String? doctorName,
    String? specialization,
    String? diagnosis,
    String? recommendations,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DoctorVisit(
      id: id ?? this.id,
      illnessId: illnessId ?? this.illnessId,
      childId: childId ?? this.childId,
      visitDate: visitDate ?? this.visitDate,
      doctorName: doctorName ?? this.doctorName,
      specialization: specialization ?? this.specialization,
      diagnosis: diagnosis ?? this.diagnosis,
      recommendations: recommendations ?? this.recommendations,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
