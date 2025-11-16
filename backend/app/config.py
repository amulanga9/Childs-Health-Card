"""
Конфигурация приложения
"""
from pydantic_settings import BaseSettings
from typing import List
import sys


class Settings(BaseSettings):
    """Настройки приложения из переменных окружения"""

    # Database
    DATABASE_URL: str

    # Yandex Object Storage
    YC_STORAGE_ACCESS_KEY: str
    YC_STORAGE_SECRET_KEY: str
    YC_STORAGE_BUCKET_NAME: str
    YC_STORAGE_ENDPOINT: str
    YC_STORAGE_REGION: str = "ru-central1"

    # JWT
    JWT_SECRET_KEY: str
    JWT_ALGORITHM: str = "HS256"

    # QR Token
    QR_TOKEN_EXPIRE_HOURS: int = 48

    # API
    API_HOST: str = "0.0.0.0"
    API_PORT: int = 8000
    API_RELOAD: bool = True

    # CORS
    CORS_ORIGINS: str = "http://localhost:3000"

    # Application
    APP_NAME: str = "Child's Health Card API"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = True

    @property
    def cors_origins_list(self) -> List[str]:
        """Преобразование CORS origins в список"""
        return [origin.strip() for origin in self.CORS_ORIGINS.split(",")]

    def validate_production_settings(self) -> None:
        """
        Валидация настроек для продакшена.
        Проверяет критические параметры безопасности.
        """
        errors = []

        # Проверка DATABASE_URL
        if not self.DATABASE_URL:
            errors.append("❌ DATABASE_URL не указан")
        elif "password" in self.DATABASE_URL.lower() and not self.DEBUG:
            errors.append("⚠️  DATABASE_URL содержит дефолтный пароль 'password'")

        # Проверка JWT_SECRET_KEY
        insecure_jwt_keys = [
            "your-secret-key-change-in-production",
            "dev-secret-key-change-in-production",
            "secret",
            "jwt-secret",
        ]
        if not self.JWT_SECRET_KEY:
            errors.append("❌ JWT_SECRET_KEY не указан")
        elif self.JWT_SECRET_KEY in insecure_jwt_keys:
            errors.append(f"⚠️  JWT_SECRET_KEY содержит небезопасное значение: '{self.JWT_SECRET_KEY}'")
        elif len(self.JWT_SECRET_KEY) < 32:
            errors.append(f"⚠️  JWT_SECRET_KEY слишком короткий (минимум 32 символа)")

        # Проверка Yandex Object Storage
        placeholder_values = ["your_access_key_here", "your_secret_key_here"]
        if self.YC_STORAGE_ACCESS_KEY in placeholder_values:
            errors.append("⚠️  YC_STORAGE_ACCESS_KEY содержит placeholder значение")
        if self.YC_STORAGE_SECRET_KEY in placeholder_values:
            errors.append("⚠️  YC_STORAGE_SECRET_KEY содержит placeholder значение")
        if not self.YC_STORAGE_BUCKET_NAME:
            errors.append("❌ YC_STORAGE_BUCKET_NAME не указан")

        # Проверка DEBUG режима в продакшене
        if not self.DEBUG:
            if "localhost" in self.CORS_ORIGINS:
                errors.append("⚠️  CORS_ORIGINS содержит localhost в продакшен-режиме")

        # Вывод ошибок
        if errors:
            print("\n" + "=" * 60)
            print("⚠️  ПРЕДУПРЕЖДЕНИЯ КОНФИГУРАЦИИ:")
            print("=" * 60)
            for error in errors:
                print(error)
            print("=" * 60)

            # В продакшене критические ошибки должны останавливать запуск
            if not self.DEBUG:
                critical_errors = [e for e in errors if e.startswith("❌")]
                if critical_errors:
                    print("\n🛑 КРИТИЧЕСКИЕ ОШИБКИ! Приложение не может быть запущено.")
                    print("Исправьте переменные окружения и перезапустите.\n")
                    sys.exit(1)
            else:
                print("\n⚠️  Режим разработки (DEBUG=True). Продолжаем с предупреждениями.\n")

    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()
settings.validate_production_settings()
