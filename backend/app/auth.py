"""
Модуль аутентификации для API

ВАЖНО:
- API ключи должны быть отдельны от JWT_SECRET_KEY
- Используется timing-safe сравнение для защиты от timing attacks
- В production обязательно настроить отдельные API ключи
"""
from fastapi import Header, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from typing import Optional, Set
import secrets
import hashlib
import logging
from .config import settings

logger = logging.getLogger(__name__)


security = HTTPBearer(auto_error=False)


class APIKeyAuth:
    """
    Аутентификация по API ключу для мобильных приложений

    SECURITY:
    - API ключи ОТДЕЛЬНЫ от JWT_SECRET_KEY
    - Используется secrets.compare_digest для защиты от timing attacks
    - В production обязательно установите API_KEY в переменных окружения
    """

    # Валидные API ключи (в production загружать из БД)
    _valid_api_keys: Set[str] = set()

    @staticmethod
    def _initialize_api_keys():
        """
        Инициализация валидных API ключей

        В PRODUCTION: загружайте из базы данных
        Для разработки: используйте переменную окружения API_KEY
        """
        if not APIKeyAuth._valid_api_keys:
            # Production: используем отдельный API_KEY из env
            if hasattr(settings, 'API_KEY') and settings.API_KEY:
                APIKeyAuth._valid_api_keys.add(settings.API_KEY)

            # Fallback для разработки (если API_KEY не установлен)
            if settings.DEBUG and not APIKeyAuth._valid_api_keys:
                # ВРЕМЕННО: для разработки генерируем детерминированный ключ
                # НЕ ИСПОЛЬЗОВАТЬ В PRODUCTION!
                dev_key = hashlib.sha256(b"dev_api_key_" + settings.JWT_SECRET_KEY.encode()).hexdigest()
                APIKeyAuth._valid_api_keys.add(dev_key)
                logger.warning(f"⚠️  РАЗРАБОТКА: Используется сгенерированный API ключ")
                logger.warning(f"⚠️  Установите переменную окружения API_KEY для production")

    @staticmethod
    def generate_api_key() -> str:
        """
        Генерация нового криптографически стойкого API ключа

        Returns:
            64-символьный API ключ
        """
        return secrets.token_urlsafe(48)

    @staticmethod
    def get_valid_api_key_hash() -> str:
        """
        Получение хеша валидного API ключа (для документации)

        Returns:
            SHA256 хеш первого валидного ключа
        """
        APIKeyAuth._initialize_api_keys()
        if APIKeyAuth._valid_api_keys:
            first_key = next(iter(APIKeyAuth._valid_api_keys))
            return hashlib.sha256(first_key.encode()).hexdigest()
        return ""

    @staticmethod
    def verify_api_key(api_key: str) -> bool:
        """
        Проверка API ключа с защитой от timing attacks

        Args:
            api_key: API ключ для проверки

        Returns:
            True если ключ валиден
        """
        APIKeyAuth._initialize_api_keys()

        if not api_key:
            return False

        # Timing-safe сравнение для защиты от timing attacks
        for valid_key in APIKeyAuth._valid_api_keys:
            if secrets.compare_digest(api_key, valid_key):
                return True

        return False


async def verify_api_key_header(
    x_api_key: Optional[str] = Header(None, description="API ключ для аутентификации")
) -> str:
    """
    Dependency для проверки API ключа в заголовке X-API-Key

    Args:
        x_api_key: API ключ из заголовка

    Returns:
        Валидный API ключ

    Raises:
        HTTPException: Если ключ отсутствует или невалиден
    """
    if not x_api_key:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="API ключ отсутствует. Добавьте заголовок: X-API-Key",
            headers={"WWW-Authenticate": "ApiKey"},
        )

    if not APIKeyAuth.verify_api_key(x_api_key):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Невалидный API ключ",
        )

    return x_api_key


async def optional_api_key_header(
    x_api_key: Optional[str] = Header(None)
) -> Optional[str]:
    """
    Опциональная проверка API ключа (для endpoint'ов с частичной защитой)

    Returns:
        API ключ если предоставлен и валиден, иначе None
    """
    if x_api_key and APIKeyAuth.verify_api_key(x_api_key):
        return x_api_key
    return None


def get_api_key_for_client() -> str:
    """
    Получение API ключа для настройки клиентского приложения

    ВАЖНО: Эта функция только для разработки!
    В продакшене: создавайте уникальные ключи для каждого пользователя/приложения

    Returns:
        API ключ для использования в Flutter приложении
    """
    APIKeyAuth._initialize_api_keys()

    if settings.DEBUG:
        # В режиме разработки возвращаем первый валидный ключ
        if APIKeyAuth._valid_api_keys:
            return next(iter(APIKeyAuth._valid_api_keys))
        return APIKeyAuth.generate_api_key()
    else:
        # В продакшене НЕ раскрываем ключи через API
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Получение API ключей запрещено в production. Используйте панель администратора."
        )
