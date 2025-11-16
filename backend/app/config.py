"""
Конфигурация приложения
"""
from pydantic_settings import BaseSettings
from typing import List


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

    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()
