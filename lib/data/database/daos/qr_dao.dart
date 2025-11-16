import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database.dart';
import '../tables.dart';

part 'qr_dao.g.dart';

/// DAO для работы с QR-токенами
/// Управление токенами для быстрого доступа к медицинским данным
@DriftAccessor(tables: [QRTokens, Children, Episodes])
class QrDao extends DatabaseAccessor<AppDatabase> with _$QrDaoMixin {
  QrDao(AppDatabase db) : super(db);

  final _uuid = const Uuid();

  /// Создать новый токен для ребёнка (доступ ко всей истории)
  ///
  /// [childId] - ID ребёнка
  /// [expiresAt] - дата истечения токена
  /// [description] - описание для чего создан токен
  ///
  /// Возвращает созданный токен (QRToken)
  Future<QRToken> createToken({
    required int childId,
    required DateTime expiresAt,
    int? episodeId,
    String description = '',
  }) async {
    final token = _uuid.v4();

    final id = await into(qRTokens).insert(
      QRTokensCompanion.insert(
        childId: childId,
        episodeId: Value(episodeId),
        token: token,
        expiresAt: expiresAt,
        description: Value(description),
      ),
    );

    return await getTokenById(id);
  }

  /// Создать токен с кастомным значением токена
  Future<QRToken> createTokenWithCustomValue({
    required int childId,
    required String tokenValue,
    required DateTime expiresAt,
    int? episodeId,
    String description = '',
  }) async {
    final id = await into(qRTokens).insert(
      QRTokensCompanion.insert(
        childId: childId,
        episodeId: Value(episodeId),
        token: tokenValue,
        expiresAt: expiresAt,
        description: Value(description),
      ),
    );

    return await getTokenById(id);
  }

  /// Получить токен по ID
  Future<QRToken> getTokenById(int id) async {
    final token = await (select(qRTokens)..where((t) => t.id.equals(id))).getSingle();
    return token;
  }

  /// Получить токен по значению токена
  Future<QRToken?> getTokenByValue(String tokenValue) {
    return (select(qRTokens)..where((t) => t.token.equals(tokenValue))).getSingleOrNull();
  }

  /// Проверить валидность токена
  /// Токен валиден если:
  /// 1. Существует
  /// 2. isActive = true
  /// 3. expiresAt > текущее время
  Future<bool> isTokenValid(String tokenValue) async {
    final token = await getTokenByValue(tokenValue);
    if (token == null) return false;
    if (!token.isActive) return false;
    if (token.expiresAt.isBefore(DateTime.now())) return false;
    return true;
  }

  /// Инвалидировать токен (установить isActive = false)
  Future<void> invalidateToken(int id) {
    return (update(qRTokens)..where((t) => t.id.equals(id))).write(
      const QRTokensCompanion(isActive: Value(false)),
    );
  }

  /// Инвалидировать токен по значению
  Future<void> invalidateTokenByValue(String tokenValue) async {
    await (update(qRTokens)..where((t) => t.token.equals(tokenValue))).write(
      const QRTokensCompanion(isActive: Value(false)),
    );
  }

  /// Получить все токены для ребёнка
  Future<List<QRToken>> getTokensByChildId(int childId) {
    return (select(qRTokens)
          ..where((t) => t.childId.equals(childId))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .get();
  }

  /// Получить активные токены для ребёнка
  Future<List<QRToken>> getActiveTokensByChildId(int childId) {
    final now = DateTime.now();
    return (select(qRTokens)
          ..where((t) =>
              t.childId.equals(childId) &
              t.isActive.equals(true) &
              t.expiresAt.isBiggerThanValue(now))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .get();
  }

  /// Получить токены для конкретного эпизода
  Future<List<QRToken>> getTokensByEpisodeId(int episodeId) {
    return (select(qRTokens)
          ..where((t) => t.episodeId.equals(episodeId))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .get();
  }

  /// Получить все истекшие токены
  Future<List<QRToken>> getExpiredTokens() {
    final now = DateTime.now();
    return (select(qRTokens)
          ..where((t) => t.expiresAt.isSmallerThanValue(now))
          ..orderBy([(t) => OrderingTerm(expression: t.expiresAt, mode: OrderingMode.desc)]))
        .get();
  }

  /// Удалить истекшие и неактивные токены (очистка)
  Future<int> cleanupExpiredTokens() async {
    final now = DateTime.now();
    return await (delete(qRTokens)
          ..where((t) => t.expiresAt.isSmallerThanValue(now) | t.isActive.equals(false)))
        .go();
  }

  /// Продлить срок действия токена
  Future<void> extendToken(int id, DateTime newExpiresAt) {
    return (update(qRTokens)..where((t) => t.id.equals(id))).write(
      QRTokensCompanion(expiresAt: Value(newExpiresAt)),
    );
  }

  /// Удалить токен
  Future<int> deleteToken(int id) {
    return (delete(qRTokens)..where((t) => t.id.equals(id))).go();
  }

  /// Stream активных токенов для ребёнка
  Stream<List<QRToken>> watchActiveTokensByChildId(int childId) {
    final now = DateTime.now();
    return (select(qRTokens)
          ..where((t) =>
              t.childId.equals(childId) &
              t.isActive.equals(true) &
              t.expiresAt.isBiggerThanValue(now))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .watch();
  }

  /// Получить количество активных токенов для ребёнка
  Future<int> getActiveTokensCount(int childId) async {
    final now = DateTime.now();
    final count = countAll();
    final query = selectOnly(qRTokens)
      ..addColumns([count])
      ..where(
        qRTokens.childId.equals(childId) &
            qRTokens.isActive.equals(true) &
            qRTokens.expiresAt.isBiggerThanValue(now),
      );
    return (await query.getSingle()).read(count) ?? 0;
  }
}
