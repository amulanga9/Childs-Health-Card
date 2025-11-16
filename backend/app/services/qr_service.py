"""
Сервис для генерации QR-кодов
"""
import qrcode
from io import BytesIO
import secrets
from datetime import datetime, timedelta
from sqlalchemy.orm import Session
from ..models import QRToken, Child, Episode
from ..config import settings
from .s3_service import s3_service


class QRService:
    """Сервис для работы с QR токенами"""

    @staticmethod
    def generate_token() -> str:
        """Генерация случайного токена"""
        return secrets.token_urlsafe(32)

    @staticmethod
    def create_qr_token(
        db: Session,
        child_id: int,
        episode_id: int = None,
        description: str = "",
        expire_hours: int = 48,
    ) -> QRToken:
        """
        Создание QR токена в базе данных

        Args:
            db: Сессия БД
            child_id: ID ребёнка
            episode_id: ID эпизода (опционально)
            description: Описание
            expire_hours: Время жизни в часах

        Returns:
            Созданный QRToken
        """
        # Генерация уникального токена
        token = QRService.generate_token()

        # Время истечения
        expires_at = datetime.utcnow() + timedelta(hours=expire_hours)

        # Создание записи в БД
        qr_token = QRToken(
            child_id=child_id,
            episode_id=episode_id,
            token=token,
            expires_at=expires_at,
            is_active=True,
            description=description,
        )

        db.add(qr_token)
        db.commit()
        db.refresh(qr_token)

        return qr_token

    @staticmethod
    def generate_qr_image(data: str, size: int = 300) -> bytes:
        """
        Генерация QR-кода в формате PNG

        Args:
            data: Данные для QR-кода (обычно URL)
            size: Размер изображения в пикселях

        Returns:
            Байты PNG изображения
        """
        qr = qrcode.QRCode(
            version=1,
            error_correction=qrcode.constants.ERROR_CORRECT_L,
            box_size=10,
            border=4,
        )

        qr.add_data(data)
        qr.make(fit=True)

        # Создание изображения
        img = qr.make_image(fill_color="black", back_color="white")

        # Изменение размера
        img = img.resize((size, size))

        # Сохранение в байты
        buffer = BytesIO()
        img.save(buffer, format="PNG")
        buffer.seek(0)

        return buffer.getvalue()

    @staticmethod
    def upload_qr_image(token: str, web_url: str) -> str:
        """
        Генерация и загрузка QR-кода в Object Storage

        Args:
            token: Токен QR
            web_url: URL для кодирования

        Returns:
            URL загруженного изображения
        """
        # Генерация QR изображения
        qr_image = QRService.generate_qr_image(web_url)

        # Ключ для хранения
        key = f"qr_codes/{token}.png"

        # Загрузка в S3
        result = s3_service.upload_file(
            file_data=qr_image,
            key=key,
            content_type="image/png",
            compress=False,  # QR коды не сжимаем
        )

        if result["success"]:
            return result["url"]
        else:
            raise Exception(f"Ошибка загрузки QR: {result['error']}")

    @staticmethod
    def validate_token(db: Session, token: str) -> QRToken:
        """
        Валидация и получение токена

        Args:
            db: Сессия БД
            token: Токен для проверки

        Returns:
            QRToken если валиден

        Raises:
            ValueError: Если токен невалиден
        """
        qr_token = db.query(QRToken).filter(QRToken.token == token).first()

        if not qr_token:
            raise ValueError("Токен не найден")

        if not qr_token.is_active:
            raise ValueError("Токен деактивирован")

        if qr_token.expires_at < datetime.utcnow():
            raise ValueError("Токен истёк")

        # Обновление счётчика доступа
        qr_token.accessed_count += 1
        qr_token.last_accessed_at = datetime.utcnow()
        db.commit()

        return qr_token

    @staticmethod
    def invalidate_token(db: Session, token: str) -> bool:
        """
        Деактивация токена

        Args:
            db: Сессия БД
            token: Токен для деактивации

        Returns:
            True если успешно
        """
        qr_token = db.query(QRToken).filter(QRToken.token == token).first()

        if qr_token:
            qr_token.is_active = False
            db.commit()
            return True

        return False

    @staticmethod
    def cleanup_expired_tokens(db: Session) -> int:
        """
        Удаление истёкших токенов

        Args:
            db: Сессия БД

        Returns:
            Количество удалённых токенов
        """
        count = (
            db.query(QRToken)
            .filter(QRToken.expires_at < datetime.utcnow())
            .delete()
        )
        db.commit()
        return count


# Singleton instance
qr_service = QRService()
