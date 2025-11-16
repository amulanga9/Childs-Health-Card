# Child's Health Card API

FastAPI backend для приложения "Карта здоровья ребёнка" с интеграцией Yandex Object Storage и генерацией QR-кодов для врачей.

## Возможности

- ✅ Синхронизация данных с мобильного приложения
- ✅ Хранение медицинских файлов в Yandex Object Storage
- ✅ Автоматическое сжатие изображений
- ✅ Генерация QR-кодов для врачей с временным доступом (1-2 дня)
- ✅ PostgreSQL для надёжного хранения данных
- ✅ REST API документация (Swagger/OpenAPI)

## Архитектура

```
┌─────────────────┐
│  Flutter App    │
└────────┬────────┘
         │ HTTP/REST
         ▼
┌─────────────────┐      ┌──────────────────┐
│   FastAPI       │─────►│   PostgreSQL     │
│   (Backend)     │      │   (Данные)       │
└────────┬────────┘      └──────────────────┘
         │
         │ boto3 (S3)
         ▼
┌─────────────────┐
│ Yandex Object   │
│ Storage (Файлы) │
└─────────────────┘
```

## Быстрый старт

### 1. Клонирование репозитория

```bash
git clone <repository-url>
cd backend
```

### 2. Установка зависимостей

```bash
# Создание виртуального окружения
python -m venv venv
source venv/bin/activate  # Linux/Mac
# или
venv\Scripts\activate  # Windows

# Установка зависимостей
pip install -r requirements.txt
```

### 3. Настройка переменных окружения

```bash
# Копирование примера
cp .env.example .env

# Редактирование .env
nano .env
```

### 4. Запуск с Docker Compose (рекомендуется)

```bash
# Запуск
docker-compose up -d

# Просмотр логов
docker-compose logs -f

# Остановка
docker-compose down
```

### 5. Запуск без Docker

```bash
# Запуск PostgreSQL (требуется установленный PostgreSQL)
# Создайте базу данных вручную

# Запуск приложения
python -m app.main
# или
uvicorn app.main:app --reload
```

API будет доступен по адресу: http://localhost:8000

Документация: http://localhost:8000/docs

## Эндпоинты API

### Синхронизация

```http
POST /sync
Content-Type: application/json

{
  "children": [...],
  "episodes": [...],
  "prescriptions": [...],
  "intakes": [...],
  "tests": [...],
  "procedures": [...],
  "attachments": [...]
}
```

### Генерация QR токена

```http
POST /qr/generate
Content-Type: application/json

{
  "child_id": 1,
  "episode_id": 5,
  "description": "Для осмотра у педиатра",
  "expire_hours": 48
}
```

**Ответ:**
```json
{
  "token": "xYz123...",
  "qr_image_url": "https://storage.yandexcloud.net/...",
  "expires_at": "2025-11-18T12:00:00Z",
  "web_url": "https://yourdomain.com/doctor/view/xYz123..."
}
```

### Получение данных по QR токену

```http
GET /qr/{token}
```

**Ответ:**
```json
{
  "child": {
    "id": 1,
    "name": "Иван Иванов",
    "birth_date": "2020-05-15",
    ...
  },
  "latest_episode": {
    "diagnosis": "ОРВИ",
    "start_date": "2025-11-10T08:00:00Z",
    "prescriptions": [...],
    "tests": [...],
    "attachments": [...]
  },
  "yearly_stats": {
    "year": 2025,
    "episodes_count": 3,
    "average_duration_days": 5.2,
    "top_diagnoses": [...]
  },
  "expires_at": "2025-11-18T12:00:00Z"
}
```

### Загрузка файлов

```http
POST /episodes/{episode_id}/upload
Content-Type: multipart/form-data

file: <binary_data>
```

## Структура проекта

```
backend/
├── app/
│   ├── main.py              # Главный файл приложения
│   ├── config.py            # Конфигурация
│   ├── database.py          # Подключение к БД
│   ├── models.py            # SQLAlchemy модели
│   ├── schemas.py           # Pydantic схемы
│   ├── routers/             # Эндпоинты
│   │   ├── sync.py          # POST /sync
│   │   ├── qr.py            # /qr/* эндпоинты
│   │   └── episodes.py      # /episodes/* эндпоинты
│   └── services/            # Бизнес-логика
│       ├── s3_service.py    # Работа с Object Storage
│       └── qr_service.py    # Генерация QR
├── requirements.txt         # Python зависимости
├── Dockerfile              # Docker образ
├── docker-compose.yml      # Локальная разработка
├── .env.example           # Пример переменных окружения
└── README.md              # Этот файл
```

## Модели данных

### Child (Ребёнок)
- `id`, `mobile_id`, `name`, `birth_date`
- `blood_group`, `allergies`, `chronic_conditions`
- `avatar`

### Episode (Эпизод болезни)
- `id`, `mobile_id`, `child_id`, `parent_episode_id`
- `diagnosis`, `start_date`, `end_date`, `status`
- `notes`

### Prescription (Назначение лекарств)
- `id`, `mobile_id`, `episode_id`
- `drug_name`, `dose`, `schedule`
- `start_date`, `end_date`

### Intake (Приём лекарства)
- `id`, `mobile_id`, `prescription_id`
- `at_datetime`, `taken`, `reason_skip`

### Test (Анализ)
- `id`, `mobile_id`, `episode_id`
- `kind`, `at_datetime`, `result_text`
- `attachment_id`

### Procedure (Процедура)
- `id`, `mobile_id`, `episode_id`
- `kind`, `at_datetime`, `status`, `note`

### Attachment (Вложение)
- `id`, `mobile_id`, `episode_id`
- `kind`, `cloud_key`, `cloud_url`
- `file_size`, `at_datetime`

### QRToken (QR токен)
- `id`, `child_id`, `episode_id`
- `token`, `expires_at`, `is_active`
- `accessed_count`, `last_accessed_at`

## Разработка

### Запуск тестов

```bash
# Установка pytest
pip install pytest pytest-cov

# Запуск тестов
pytest

# С покрытием
pytest --cov=app tests/
```

### Миграции БД

```bash
# Инициализация Alembic
alembic init alembic

# Создание миграции
alembic revision --autogenerate -m "Initial migration"

# Применение миграций
alembic upgrade head
```

### Форматирование кода

```bash
# Установка инструментов
pip install black isort

# Форматирование
black app/
isort app/
```

## Деплой

См. [YANDEX_CLOUD_DEPLOY.md](../YANDEX_CLOUD_DEPLOY.md) для подробных инструкций по развёртыванию в Yandex Cloud.

## Безопасность

### Рекомендации:

1. **Изменить JWT_SECRET_KEY** в production
2. **Использовать HTTPS** для всех запросов
3. **Ограничить CORS** до конкретных доменов
4. **Регулярно обновлять** зависимости
5. **Включить rate limiting** для API
6. **Настроить файрволл** для БД
7. **Использовать strong passwords** для PostgreSQL

### Ограничение доступа к QR данным:

```python
# В production добавить authentication middleware
from fastapi import Security, HTTPException
from fastapi.security import HTTPBearer

security = HTTPBearer()

@router.get("/qr/{token}")
async def get_qr_data(
    token: str,
    credentials: HTTPAuthorizationCredentials = Security(security),
):
    # Проверка токена + дополнительная аутентификация
    ...
```

## Мониторинг

### Метрики для отслеживания:

- Количество запросов /sync в час
- Количество сгенерированных QR токенов
- Размер загруженных файлов в Object Storage
- Количество активных QR токенов
- Среднее время ответа API

### Логирование:

```bash
# Просмотр логов в Docker
docker-compose logs -f api

# Логи PostgreSQL
docker-compose logs -f postgres
```

## Troubleshooting

### Ошибка подключения к PostgreSQL

```bash
# Проверка контейнера
docker ps | grep postgres

# Проверка логов
docker logs childs_health_db

# Проверка подключения
psql "postgresql://childs_health:password@localhost:5432/childs_health_db"
```

### Ошибка доступа к Object Storage

```bash
# Проверка ключей в .env
cat .env | grep YC_STORAGE

# Тест подключения
aws s3 ls s3://your-bucket --endpoint-url https://storage.yandexcloud.net
```

### QR коды не генерируются

```bash
# Проверка библиотеки qrcode
python -c "import qrcode; print(qrcode.__version__)"

# Проверка PIL
python -c "from PIL import Image; print(Image.__version__)"
```

## Roadmap

- [ ] Добавить rate limiting
- [ ] Реализовать WebSocket для real-time синхронизации
- [ ] Добавить поддержку PDF экспорта эпизодов
- [ ] Интеграция с медицинскими системами (FHIR)
- [ ] Мультитенантность (для клиник)
- [ ] Telegram bot для уведомлений
- [ ] GraphQL API (опционально)

## Лицензия

Проприетарное ПО. Все права защищены.

## Контакты

- Email: support@example.com
- Документация: https://docs.example.com
- Issues: https://github.com/yourorg/childs-health-card/issues
