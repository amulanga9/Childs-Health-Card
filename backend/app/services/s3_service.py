"""
Сервис для работы с Yandex Object Storage (S3-compatible)
"""
import boto3
from botocore.exceptions import ClientError
from typing import Optional, BinaryIO
import hashlib
from datetime import datetime
import io
import logging
from PIL import Image
from ..config import settings

logger = logging.getLogger(__name__)


class S3Service:
    """Сервис для загрузки и управления файлами в Yandex Object Storage"""

    def __init__(self):
        """Инициализация клиента S3"""
        self.s3_client = boto3.client(
            "s3",
            endpoint_url=settings.YC_STORAGE_ENDPOINT,
            aws_access_key_id=settings.YC_STORAGE_ACCESS_KEY,
            aws_secret_access_key=settings.YC_STORAGE_SECRET_KEY,
            region_name=settings.YC_STORAGE_REGION,
        )
        self.bucket_name = settings.YC_STORAGE_BUCKET_NAME

    def generate_key(self, child_id: int, episode_id: int, filename: str) -> str:
        """
        Генерация уникального ключа для файла

        Структура: child_{child_id}/episode_{episode_id}/{timestamp}_{hash}_{filename}
        """
        timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        file_hash = hashlib.md5(f"{child_id}{episode_id}{filename}{timestamp}".encode()).hexdigest()[:8]

        return f"child_{child_id}/episode_{episode_id}/{timestamp}_{file_hash}_{filename}"

    def compress_image(self, image_data: bytes, max_size: int = 1024 * 1024) -> bytes:
        """
        Сжатие изображения если размер превышает max_size

        Args:
            image_data: Байты изображения
            max_size: Максимальный размер в байтах (по умолчанию 1MB)

        Returns:
            Сжатые байты изображения

        Raises:
            ValueError: Если данные не являются валидным изображением
        """
        if len(image_data) <= max_size:
            return image_data

        try:
            # Открываем изображение
            image = Image.open(io.BytesIO(image_data))
        except Exception as e:
            logger.error(f"Ошибка открытия изображения: {e}")
            raise ValueError(f"Невалидное изображение: {e}")

        # Конвертируем в RGB если необходимо
        if image.mode in ("RGBA", "P"):
            image = image.convert("RGB")

        # Начальное качество
        quality = 85
        output = io.BytesIO()

        while quality > 20:
            output.seek(0)
            output.truncate()
            image.save(output, format="JPEG", quality=quality, optimize=True)

            if output.tell() <= max_size:
                break

            quality -= 5

        return output.getvalue()

    def upload_file(
        self,
        file_data: bytes,
        key: str,
        content_type: str = "application/octet-stream",
        compress: bool = True,
    ) -> dict:
        """
        Загрузка файла в Object Storage

        Args:
            file_data: Данные файла в байтах
            key: Ключ для сохранения
            content_type: MIME тип файла
            compress: Сжимать ли изображения

        Returns:
            dict с информацией о загруженном файле
        """
        try:
            # Сжатие изображений
            if compress and content_type.startswith("image/"):
                file_data = self.compress_image(file_data)

            # Загрузка файла с ПРИВАТНЫМ доступом (медицинские данные!)
            self.s3_client.put_object(
                Bucket=self.bucket_name,
                Key=key,
                Body=file_data,
                ContentType=content_type,
                ACL="private",  # ПРИВАТНЫЙ доступ - безопасность медицинских данных
                ServerSideEncryption="AES256",  # Шифрование на стороне сервера
            )

            # Генерация временной presigned URL (действует 24 часа)
            url = self.get_file_url(key, expires_in=86400)

            if not url:
                logger.error(f"Не удалось сгенерировать presigned URL для {key}")
                return {
                    "success": False,
                    "error": "Ошибка генерации временного URL",
                }

            return {
                "success": True,
                "key": key,
                "url": url,
                "size": len(file_data),
            }

        except ClientError as e:
            logger.error(f"Ошибка загрузки файла в S3: {e}")
            return {
                "success": False,
                "error": str(e),
            }
        except Exception as e:
            logger.error(f"Неожиданная ошибка при загрузке файла: {e}")
            return {
                "success": False,
                "error": str(e),
            }

    def delete_file(self, key: str) -> bool:
        """
        Удаление файла из Object Storage

        Args:
            key: Ключ файла

        Returns:
            True если успешно, False при ошибке
        """
        try:
            self.s3_client.delete_object(
                Bucket=self.bucket_name,
                Key=key,
            )
            logger.info(f"Файл успешно удален: {key}")
            return True
        except ClientError as e:
            logger.error(f"Ошибка удаления файла {key}: {e}")
            return False

    def get_file_url(self, key: str, expires_in: int = 3600) -> Optional[str]:
        """
        Генерация временной presigned ссылки на файл

        ВАЖНО: Используется для безопасного доступа к приватным медицинским файлам

        Args:
            key: Ключ файла
            expires_in: Время жизни ссылки в секундах (по умолчанию 1 час)

        Returns:
            Временная presigned ссылка или None при ошибке
        """
        try:
            url = self.s3_client.generate_presigned_url(
                "get_object",
                Params={
                    "Bucket": self.bucket_name,
                    "Key": key,
                },
                ExpiresIn=expires_in,
            )
            return url
        except ClientError as e:
            logger.error(f"Ошибка генерации presigned URL для {key}: {e}")
            return None
        except Exception as e:
            logger.error(f"Неожиданная ошибка при генерации URL: {e}")
            return None

    def file_exists(self, key: str) -> bool:
        """
        Проверка существования файла

        Args:
            key: Ключ файла

        Returns:
            True если файл существует
        """
        try:
            self.s3_client.head_object(
                Bucket=self.bucket_name,
                Key=key,
            )
            return True
        except ClientError:
            return False


# Singleton instance
s3_service = S3Service()
