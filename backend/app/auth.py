"""
Модуль аутентификации для API
"""
from fastapi import Header, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from typing import Optional
import secrets
import hashlib
from .config import settings


security = HTTPBearer(auto_error=False)


class APIKeyAuth:
    """
    Аутентификация по API ключу для мобильных приложений

    В продакшене API ключи должны храниться в БД с хешированием.
    Для демо используем простую проверку по хешу от JWT_SECRET_KEY.
    """

    @staticmethod
    def generate_api_key() -> str:
        """
        Генерация нового API ключа

        Returns:
            32-символьный API ключ
        """
        return secrets.token_urlsafe(32)

    @staticmethod
    def get_valid_api_key_hash() -> str:
        """
        Получение хеша валидного API ключа

        В продакшене: загружайте из БД
        Для демо: хеш от JWT_SECRET_KEY
        """
        return hashlib.sha256(settings.JWT_SECRET_KEY.encode()).hexdigest()

    @staticmethod
    def verify_api_key(api_key: str) -> bool:
        """
        Проверка API ключа

        Args:
            api_key: API ключ для проверки

        Returns:
            True если ключ валиден
        """
        # Простая проверка для демо: API ключ = JWT_SECRET_KEY
        # В продакшене: проверка по БД с хешированием
        if settings.DEBUG:
            # В режиме отладки принимаем тестовый ключ
            test_keys = [
                settings.JWT_SECRET_KEY,
                "test-api-key",
                "dev-api-key"
            ]
            return api_key in test_keys
        else:
            # В продакшене проверяем строго
            return api_key == settings.JWT_SECRET_KEY


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

    Эта функция используется для документации и настройки.
    В продакшене: создавайте уникальные ключи для каждого пользователя/приложения.

    Returns:
        API ключ для использования в Flutter приложении
    """
    if settings.DEBUG:
        # В режиме разработки возвращаем тестовый ключ
        return "test-api-key"
    else:
        # В продакшене используем JWT_SECRET_KEY как API ключ
        # TODO: Реализовать систему управления API ключами в БД
        return settings.JWT_SECRET_KEY
