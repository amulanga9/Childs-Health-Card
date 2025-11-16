"""
FastAPI приложение для Child's Health Card
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from .config import settings
from .database import init_db
from .routers import sync, qr, episodes


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifecycle events для приложения"""
    # Startup
    print("🚀 Запуск приложения...")
    print(f"📦 Версия: {settings.APP_VERSION}")
    print(f"🗄️  База данных: {settings.DATABASE_URL.split('@')[1] if '@' in settings.DATABASE_URL else 'локальная'}")

    # Инициализация БД
    try:
        init_db()
        print("✅ База данных инициализирована")
    except Exception as e:
        print(f"❌ Ошибка инициализации БД: {e}")

    yield

    # Shutdown
    print("👋 Остановка приложения...")


# Создание приложения
app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="API для приложения Карта здоровья ребёнка",
    lifespan=lifespan,
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Подключение роутеров
app.include_router(sync.router)
app.include_router(qr.router)
app.include_router(episodes.router)


@app.get("/")
async def root():
    """Корневой эндпоинт"""
    return {
        "app": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "status": "running",
        "docs": "/docs",
    }


@app.get("/health")
async def health_check():
    """Проверка здоровья приложения"""
    return {
        "status": "healthy",
        "timestamp": "2025-11-16T12:00:00Z",
    }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "app.main:app",
        host=settings.API_HOST,
        port=settings.API_PORT,
        reload=settings.API_RELOAD,
    )
