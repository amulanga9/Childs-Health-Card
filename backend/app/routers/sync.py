"""
Эндпоинт синхронизации данных с мобильного приложения

SECURITY: Использует whitelist для защиты системных полей при update
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from typing import Dict, Set, Type
import logging
from ..database import get_db
from ..schemas import SyncRequest, SyncResponse
from ..models import Child, Episode, Prescription, Intake, Test, Procedure, Attachment
from ..auth import verify_api_key_header

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/sync", tags=["sync"])


# ============ WHITELISTED FIELDS (SECURITY) ============
#
# Защищенные поля (НИКОГДА не обновляются через API)
PROTECTED_FIELDS = {"id", "created_at", "updated_at"}

# Whitelisted поля для каждой модели (только эти можно обновлять)
ALLOWED_FIELDS: Dict[Type, Set[str]] = {
    Child: {
        "mobile_id", "name", "birth_date", "blood_group",
        "allergies", "chronic_conditions", "avatar"
    },
    Episode: {
        "mobile_id", "child_id", "parent_episode_id", "diagnosis",
        "start_date", "end_date", "status", "notes"
    },
    Prescription: {
        "mobile_id", "episode_id", "drug_name", "dose",
        "schedule", "start_date", "end_date"
    },
    Intake: {
        "mobile_id", "prescription_id", "at_datetime",
        "taken", "reason_skip"
    },
    Test: {
        "mobile_id", "episode_id", "kind", "at_datetime",
        "result_text", "attachment_id"
    },
    Procedure: {
        "mobile_id", "episode_id", "kind", "at_datetime",
        "status", "note"
    },
    Attachment: {
        "mobile_id", "episode_id", "kind", "local_path",
        "cloud_key", "cloud_url", "file_size", "at_datetime"
    },
}


def upsert_model(db: Session, model_class: Type, data: dict, auto_commit: bool = True) -> int:
    """
    Безопасная вставка или обновление записи по mobile_id

    SECURITY:
    - Использует whitelist разрешенных полей
    - Защищает системные поля (id, created_at, updated_at)
    - Предотвращает SQL injection через ORM

    PERFORMANCE:
    - Поддержка batch режима (auto_commit=False)
    - Позволяет обработать множество записей в одной транзакции

    Args:
        db: Database session
        model_class: SQLAlchemy model class
        data: Данные для upsert
        auto_commit: Автоматически коммитить изменения (по умолчанию True)

    Returns:
        ID созданной/обновлённой записи

    Raises:
        ValueError: Если mobile_id отсутствует или данные невалидны
        IntegrityError: При нарушении ограничений БД
    """
    mobile_id = data.get("mobile_id")

    if mobile_id is None:
        raise ValueError(f"mobile_id обязателен для {model_class.__name__}")

    # Получаем whitelist для данной модели
    allowed_fields = ALLOWED_FIELDS.get(model_class, set())

    if not allowed_fields:
        raise ValueError(f"Модель {model_class.__name__} не поддерживается для upsert")

    try:
        # Поиск существующей записи по mobile_id
        existing = db.query(model_class).filter(model_class.mobile_id == mobile_id).first()

        if existing:
            # UPDATE: Обновление только whitelisted полей
            updated_fields = []

            for key, value in data.items():
                # Пропускаем защищенные поля
                if key in PROTECTED_FIELDS:
                    logger.warning(f"⚠️  Попытка обновить защищенное поле '{key}' для {model_class.__name__}")
                    continue

                # Обновляем только разрешенные поля
                if key in allowed_fields and hasattr(existing, key):
                    setattr(existing, key, value)
                    updated_fields.append(key)

            if updated_fields:
                logger.debug(f"✅ Обновлены поля {updated_fields} для {model_class.__name__}[{mobile_id}]")

            if auto_commit:
                db.commit()
                db.refresh(existing)
            else:
                db.flush()  # Получаем ID без commit
            return existing.id

        else:
            # INSERT: Создание новой записи
            # Фильтруем только разрешенные поля
            safe_data = {
                k: v for k, v in data.items()
                if k in allowed_fields and k not in PROTECTED_FIELDS
            }

            new_obj = model_class(**safe_data)
            db.add(new_obj)

            if auto_commit:
                db.commit()
                db.refresh(new_obj)
            else:
                db.flush()  # Получаем ID без commit

            logger.debug(f"✅ Создана новая запись {model_class.__name__}[{mobile_id}] -> DB ID {new_obj.id}")
            return new_obj.id

    except IntegrityError as e:
        db.rollback()
        logger.error(f"❌ Ошибка целостности БД для {model_class.__name__}: {e}")
        raise HTTPException(
            status_code=409,
            detail=f"Нарушение ограничений БД: {str(e.orig)}"
        )
    except Exception as e:
        db.rollback()
        logger.error(f"❌ Ошибка upsert {model_class.__name__}: {e}")
        raise


@router.post("/", response_model=SyncResponse)
async def sync_data(
    request: SyncRequest,
    db: Session = Depends(get_db),
    api_key: str = Depends(verify_api_key_header),
):
    """
    Синхронизация данных с мобильного приложения

    SECURITY:
    - Требует аутентификации (X-API-Key header)
    - Использует whitelist полей при обновлении
    - Защита от SQL injection через Pydantic validation + ORM

    PERFORMANCE:
    - Batch операции: все записи обрабатываются в одной транзакции
    - Вместо N commits теперь 1 commit для всех данных

    Принимает все данные из мобильного приложения и сохраняет в PostgreSQL.
    Использует безопасную upsert логику (создание или обновление по mobile_id).

    Returns:
        Статистика синхронизации
    """
    try:
        synced_counts: Dict[str, int] = {}

        # PERFORMANCE: Используем одну транзакцию для всех операций
        # Отключаем autocommit в функции upsert_model

        # Синхронизация детей
        for child_data in request.children:
            upsert_model(db, Child, child_data.model_dump(), auto_commit=False)
        synced_counts["children"] = len(request.children)

        # Синхронизация эпизодов
        for episode_data in request.episodes:
            upsert_model(db, Episode, episode_data.model_dump(), auto_commit=False)
        synced_counts["episodes"] = len(request.episodes)

        # Синхронизация назначений
        for prescription_data in request.prescriptions:
            upsert_model(db, Prescription, prescription_data.model_dump(), auto_commit=False)
        synced_counts["prescriptions"] = len(request.prescriptions)

        # Синхронизация приёмов
        for intake_data in request.intakes:
            upsert_model(db, Intake, intake_data.model_dump(), auto_commit=False)
        synced_counts["intakes"] = len(request.intakes)

        # Синхронизация анализов
        for test_data in request.tests:
            upsert_model(db, Test, test_data.model_dump(), auto_commit=False)
        synced_counts["tests"] = len(request.tests)

        # Синхронизация процедур
        for procedure_data in request.procedures:
            upsert_model(db, Procedure, procedure_data.model_dump(), auto_commit=False)
        synced_counts["procedures"] = len(request.procedures)

        # Синхронизация вложений
        for attachment_data in request.attachments:
            upsert_model(db, Attachment, attachment_data.model_dump(), auto_commit=False)
        synced_counts["attachments"] = len(request.attachments)

        # PERFORMANCE: Единственный commit для всех данных (вместо N commits)
        db.commit()

        logger.info(f"✅ Синхронизация завершена: {synced_counts}")

        return SyncResponse(
            success=True,
            message="Синхронизация завершена успешно",
            synced_counts=synced_counts,
        )

    except HTTPException:
        # Пробрасываем HTTP исключения как есть
        raise
    except Exception as e:
        db.rollback()
        logger.error(f"❌ Критическая ошибка синхронизации: {e}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Ошибка синхронизации: {str(e)}"
        )
