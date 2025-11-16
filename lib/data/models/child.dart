import 'package:hive/hive.dart';

part 'child.g.dart';

/// Модель данных ребёнка
/// Хранит основную информацию о ребёнке
@HiveType(typeId: 0)
class Child {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final DateTime birthDate;

  @HiveField(3)
  final Gender gender;

  @HiveField(4)
  final String? photoPath;

  @HiveField(5)
  final DateTime createdAt;

  @HiveField(6)
  final DateTime updatedAt;

  Child({
    required this.id,
    required this.name,
    required this.birthDate,
    required this.gender,
    this.photoPath,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Возраст ребёнка в годах
  int get age {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Child copyWith({
    String? id,
    String? name,
    DateTime? birthDate,
    Gender? gender,
    String? photoPath,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Child(
      id: id ?? this.id,
      name: name ?? this.name,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      photoPath: photoPath ?? this.photoPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

@HiveType(typeId: 1)
enum Gender {
  @HiveField(0)
  male,

  @HiveField(1)
  female,
}
