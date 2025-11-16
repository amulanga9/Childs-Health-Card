"""
Эндпоинт синхронизации данных с мобильного приложения
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import Dict
from ..database import get_db
from ..schemas import SyncRequest, SyncResponse
from ..models import Child, Episode, Prescription, Intake, Test, Procedure, Attachment


router = APIRouter(prefix="/sync", tags=["sync"])


def upsert_model(db: Session, model_class, data: dict) -> int:
    """
    Вставка или обновление записи по mobile_id

    Returns:
        ID созданной/обновлённой записи
    """
    mobile_id = data.get("mobile_id")

    # Поиск существующей записи
    existing = db.query(model_class).filter(model_class.mobile_id == mobile_id).first()

    if existing:
        # Обновление существующей записи
        for key, value in data.items():
            if hasattr(existing, key):
                setattr(existing, key, value)
        db.commit()
        db.refresh(existing)
        return existing.id
    else:
        # Создание новой записи
        new_obj = model_class(**data)
        db.add(new_obj)
        db.commit()
        db.refresh(new_obj)
        return new_obj.id


@router.post("/", response_model=SyncResponse)
async def sync_data(
    request: SyncRequest,
    db: Session = Depends(get_db),
):
    """
    Синхронизация данных с мобильного приложения

    Принимает все данные из мобильного приложения и сохраняет в PostgreSQL.
    Использует upsert логику (создание или обновление по mobile_id).

    Returns:
        Статистика синхронизации
    """
    try:
        synced_counts: Dict[str, int] = {}

        # Синхронизация детей
        for child_data in request.children:
            upsert_model(db, Child, child_data.model_dump())
        synced_counts["children"] = len(request.children)

        # Синхронизация эпизодов
        for episode_data in request.episodes:
            upsert_model(db, Episode, episode_data.model_dump())
        synced_counts["episodes"] = len(request.episodes)

        # Синхронизация назначений
        for prescription_data in request.prescriptions:
            upsert_model(db, Prescription, prescription_data.model_dump())
        synced_counts["prescriptions"] = len(request.prescriptions)

        # Синхронизация приёмов
        for intake_data in request.intakes:
            upsert_model(db, Intake, intake_data.model_dump())
        synced_counts["intakes"] = len(request.intakes)

        # Синхронизация анализов
        for test_data in request.tests:
            upsert_model(db, Test, test_data.model_dump())
        synced_counts["tests"] = len(request.tests)

        # Синхронизация процедур
        for procedure_data in request.procedures:
            upsert_model(db, Procedure, procedure_data.model_dump())
        synced_counts["procedures"] = len(request.procedures)

        # Синхронизация вложений
        for attachment_data in request.attachments:
            upsert_model(db, Attachment, attachment_data.model_dump())
        synced_counts["attachments"] = len(request.attachments)

        return SyncResponse(
            success=True,
            message="Синхронизация завершена успешно",
            synced_counts=synced_counts,
        )

    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Ошибка синхронизации: {str(e)}")
