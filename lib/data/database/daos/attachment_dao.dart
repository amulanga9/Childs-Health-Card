import 'package:drift/drift.dart';
import '../database.dart';
import '../tables.dart';

part 'attachment_dao.g.dart';

/// DAO для работы с вложениями (файлами)
@DriftAccessor(tables: [Attachments, Episodes])
class AttachmentDao extends DatabaseAccessor<AppDatabase> with _$AttachmentDaoMixin {
  AttachmentDao(AppDatabase db) : super(db);

  /// Получить все вложения
  Future<List<Attachment>> getAllAttachments() {
    return (select(attachments)
          ..orderBy([(t) => OrderingTerm(expression: t.atDatetime, mode: OrderingMode.desc)]))
        .get();
  }

  /// Получить вложение по ID
  Future<Attachment?> getAttachmentById(int id) =>
      (select(attachments)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Получить вложения для эпизода
  Future<List<Attachment>> getAttachmentsByEpisodeId(int episodeId) {
    return (select(attachments)
          ..where((t) => t.episodeId.equals(episodeId))
          ..orderBy([(t) => OrderingTerm(expression: t.atDatetime, mode: OrderingMode.desc)]))
        .get();
  }

  /// Получить вложения по типу
  Future<List<Attachment>> getAttachmentsByKind(String kind) {
    return (select(attachments)
          ..where((t) => t.kind.equals(kind))
          ..orderBy([(t) => OrderingTerm(expression: t.atDatetime, mode: OrderingMode.desc)]))
        .get();
  }

  /// Получить вложения эпизода по типу
  Future<List<Attachment>> getAttachmentsByEpisodeAndKind(int episodeId, String kind) {
    return (select(attachments)
          ..where((t) => t.episodeId.equals(episodeId) & t.kind.equals(kind))
          ..orderBy([(t) => OrderingTerm(expression: t.atDatetime, mode: OrderingMode.desc)]))
        .get();
  }

  /// Получить вложения без облачного ключа (не синхронизированные)
  Future<List<Attachment>> getUnsyncedAttachments() {
    return (select(attachments)
          ..where((t) => t.cloudKey.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.atDatetime, mode: OrderingMode.desc)]))
        .get();
  }

  /// Создать вложение
  Future<int> createAttachment(AttachmentsCompanion entry) => into(attachments).insert(entry);

  /// Обновить вложение
  Future<bool> updateAttachment(Attachment attachment) =>
      update(attachments).replace(attachment);

  /// Удалить вложение
  Future<int> deleteAttachment(int id) =>
      (delete(attachments)..where((t) => t.id.equals(id))).go();

  /// Установить облачный ключ (после синхронизации)
  Future<void> setCloudKey(int id, String cloudKey) {
    return (update(attachments)..where((t) => t.id.equals(id))).write(
      AttachmentsCompanion(cloudKey: Value(cloudKey)),
    );
  }

  /// Stream вложений для эпизода
  Stream<List<Attachment>> watchAttachmentsByEpisodeId(int episodeId) {
    return (select(attachments)
          ..where((t) => t.episodeId.equals(episodeId))
          ..orderBy([(t) => OrderingTerm(expression: t.atDatetime, mode: OrderingMode.desc)]))
        .watch();
  }
}
