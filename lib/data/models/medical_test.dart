import 'package:hive/hive.dart';

part 'medical_test.g.dart';

/// Модель данных медицинского анализа
/// Хранит информацию об анализах и тестах
@HiveType(typeId: 5)
class MedicalTest {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String illnessId; // Связь с болезнью

  @HiveField(2)
  final String childId;

  @HiveField(3)
  final String testType; // Тип анализа (кровь, моча и т.д.)

  @HiveField(4)
  final DateTime testDate;

  @HiveField(5)
  final Map<String, String> results; // Результаты анализов (параметр: значение)

  @HiveField(6)
  final String? laboratory; // Лаборатория

  @HiveField(7)
  final String? notes; // Заметки врача

  @HiveField(8)
  final List<String>? attachments; // Пути к файлам результатов

  @HiveField(9)
  final DateTime createdAt;

  @HiveField(10)
  final DateTime updatedAt;

  MedicalTest({
    required this.id,
    required this.illnessId,
    required this.childId,
    required this.testType,
    required this.testDate,
    required this.results,
    this.laboratory,
    this.notes,
    this.attachments,
    required this.createdAt,
    required this.updatedAt,
  });

  MedicalTest copyWith({
    String? id,
    String? illnessId,
    String? childId,
    String? testType,
    DateTime? testDate,
    Map<String, String>? results,
    String? laboratory,
    String? notes,
    List<String>? attachments,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MedicalTest(
      id: id ?? this.id,
      illnessId: illnessId ?? this.illnessId,
      childId: childId ?? this.childId,
      testType: testType ?? this.testType,
      testDate: testDate ?? this.testDate,
      results: results ?? this.results,
      laboratory: laboratory ?? this.laboratory,
      notes: notes ?? this.notes,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
