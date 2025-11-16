import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../data/database/database.dart';

/// Сервис для работы с backend API
class ApiService {
  final String baseUrl;
  final http.Client _client;

  ApiService({
    this.baseUrl = 'http://localhost:8000', // Изменить на production URL
  }) : _client = http.Client();

  /// Синхронизация данных с сервером
  Future<Map<String, dynamic>> syncData({
    required List<Child> children,
    required List<Episode> episodes,
    required List<Prescription> prescriptions,
    required List<Intake> intakes,
    required List<Test> tests,
    required List<Procedure> procedures,
    required List<Attachment> attachments,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/sync'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'children': children.map((c) => _childToJson(c)).toList(),
          'episodes': episodes.map((e) => _episodeToJson(e)).toList(),
          'prescriptions': prescriptions.map((p) => _prescriptionToJson(p)).toList(),
          'intakes': intakes.map((i) => _intakeToJson(i)).toList(),
          'tests': tests.map((t) => _testToJson(t)).toList(),
          'procedures': procedures.map((p) => _procedureToJson(p)).toList(),
          'attachments': attachments.map((a) => _attachmentToJson(a)).toList(),
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Ошибка синхронизации: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Ошибка соединения: $e');
    }
  }

  /// Генерация QR токена
  Future<QRTokenResponse> generateQRToken({
    required int childId,
    int? episodeId,
    String description = '',
    int expireHours = 48,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/qr/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'child_id': childId,
          'episode_id': episodeId,
          'description': description,
          'expire_hours': expireHours,
        }),
      );

      if (response.statusCode == 200) {
        return QRTokenResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Ошибка генерации QR: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Ошибка соединения: $e');
    }
  }

  /// Загрузка файла на сервер
  Future<FileUploadResponse> uploadFile({
    required int episodeId,
    required File file,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/episodes/$episodeId/upload'),
      );

      request.files.add(
        await http.MultipartFile.fromPath('file', file.path),
      );

      final streamedResponse = await _client.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return FileUploadResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Ошибка загрузки файла: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Ошибка соединения: $e');
    }
  }

  /// Деактивация QR токена
  Future<bool> invalidateQRToken(String token) async {
    try {
      final response = await _client.delete(
        Uri.parse('$baseUrl/qr/$token'),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    _client.close();
  }

  // ============ Конвертация моделей в JSON ============

  Map<String, dynamic> _childToJson(Child child) {
    return {
      'mobile_id': child.id,
      'name': child.name,
      'birth_date': child.birthDate.toIso8601String().split('T')[0],
      'blood_group': child.bloodGroup,
      'allergies': child.allergies.split(',').where((a) => a.isNotEmpty).toList(),
      'chronic_conditions': child.chronicConditions.split(',').where((c) => c.isNotEmpty).toList(),
      'avatar': child.avatar,
    };
  }

  Map<String, dynamic> _episodeToJson(Episode episode) {
    return {
      'mobile_id': episode.id,
      'child_id': episode.childId,
      'parent_episode_id': episode.parentEpisodeId,
      'diagnosis': episode.diagnosis,
      'start_date': episode.startDate.toIso8601String(),
      'end_date': episode.endDate?.toIso8601String(),
      'status': episode.status,
      'notes': episode.notes,
    };
  }

  Map<String, dynamic> _prescriptionToJson(Prescription prescription) {
    return {
      'mobile_id': prescription.id,
      'episode_id': prescription.episodeId,
      'drug_name': prescription.drugName,
      'dose': prescription.dose,
      'schedule': prescription.schedule,
      'start_date': prescription.startDate.toIso8601String(),
      'end_date': prescription.endDate?.toIso8601String(),
    };
  }

  Map<String, dynamic> _intakeToJson(Intake intake) {
    return {
      'mobile_id': intake.id,
      'prescription_id': intake.prescriptionId,
      'at_datetime': intake.atDatetime.toIso8601String(),
      'taken': intake.taken,
      'reason_skip': intake.reasonSkip,
    };
  }

  Map<String, dynamic> _testToJson(Test test) {
    return {
      'mobile_id': test.id,
      'episode_id': test.episodeId,
      'kind': test.kind,
      'at_datetime': test.atDatetime.toIso8601String(),
      'result_text': test.resultText,
      'attachment_id': test.attachmentId,
    };
  }

  Map<String, dynamic> _procedureToJson(Procedure procedure) {
    return {
      'mobile_id': procedure.id,
      'episode_id': procedure.episodeId,
      'kind': procedure.kind,
      'at_datetime': procedure.atDatetime.toIso8601String(),
      'status': procedure.status,
      'note': procedure.note,
    };
  }

  Map<String, dynamic> _attachmentToJson(Attachment attachment) {
    return {
      'mobile_id': attachment.id,
      'episode_id': attachment.episodeId,
      'kind': attachment.kind,
      'local_path': attachment.localPath,
      'cloud_key': attachment.cloudKey,
      'at_datetime': attachment.atDatetime.toIso8601String(),
    };
  }
}

/// Ответ на генерацию QR токена
class QRTokenResponse {
  final String token;
  final String qrImageUrl;
  final DateTime expiresAt;
  final String webUrl;

  QRTokenResponse({
    required this.token,
    required this.qrImageUrl,
    required this.expiresAt,
    required this.webUrl,
  });

  factory QRTokenResponse.fromJson(Map<String, dynamic> json) {
    return QRTokenResponse(
      token: json['token'],
      qrImageUrl: json['qr_image_url'],
      expiresAt: DateTime.parse(json['expires_at']),
      webUrl: json['web_url'],
    );
  }
}

/// Ответ на загрузку файла
class FileUploadResponse {
  final bool success;
  final String cloudKey;
  final String cloudUrl;
  final int fileSize;

  FileUploadResponse({
    required this.success,
    required this.cloudKey,
    required this.cloudUrl,
    required this.fileSize,
  });

  factory FileUploadResponse.fromJson(Map<String, dynamic> json) {
    return FileUploadResponse(
      success: json['success'],
      cloudKey: json['cloud_key'],
      cloudUrl: json['cloud_url'],
      fileSize: json['file_size'],
    );
  }
}
