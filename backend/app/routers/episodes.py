"""
Эндпоинты для работы с эпизодами
"""
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.orm import Session
from typing import List
from ..database import get_db
from ..schemas import EpisodeResponse, AttachmentResponse, FileUploadResponse
from ..models import Episode, Attachment
from ..services.s3_service import s3_service
from ..auth import verify_api_key_header


router = APIRouter(prefix="/episodes", tags=["episodes"])


@router.get("/{episode_id}", response_model=EpisodeResponse)
async def get_episode(
    episode_id: int,
    db: Session = Depends(get_db),
    api_key: str = Depends(verify_api_key_header),
):
    """
    Получение эпизода по ID

    Args:
        episode_id: ID эпизода

    Returns:
        Данные эпизода
    """
    episode = db.query(Episode).filter(Episode.id == episode_id).first()

    if not episode:
        raise HTTPException(status_code=404, detail="Эпизод не найден")

    return EpisodeResponse.from_orm(episode)


@router.get("/{episode_id}/attachments", response_model=List[AttachmentResponse])
async def get_episode_attachments(
    episode_id: int,
    db: Session = Depends(get_db),
    api_key: str = Depends(verify_api_key_header),
):
    """
    Получение вложений эпизода

    Args:
        episode_id: ID эпизода

    Returns:
        Список вложений
    """
    # Проверка существования эпизода
    episode = db.query(Episode).filter(Episode.id == episode_id).first()
    if not episode:
        raise HTTPException(status_code=404, detail="Эпизод не найден")

    # Получение вложений
    attachments = (
        db.query(Attachment)
        .filter(Attachment.episode_id == episode_id)
        .order_by(Attachment.at_datetime.desc())
        .all()
    )

    return [AttachmentResponse.from_orm(a) for a in attachments]


@router.post("/{episode_id}/upload", response_model=FileUploadResponse)
async def upload_file_to_episode(
    episode_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    api_key: str = Depends(verify_api_key_header),
):
    """
    Загрузка файла для эпизода в Yandex Object Storage

    Args:
        episode_id: ID эпизода
        file: Файл для загрузки

    Returns:
        Информация о загруженном файле
    """
    # Проверка существования эпизода
    episode = db.query(Episode).filter(Episode.id == episode_id).first()
    if not episode:
        raise HTTPException(status_code=404, detail="Эпизод не найден")

    try:
        # Чтение файла
        file_data = await file.read()

        # Определение типа файла
        content_type = file.content_type or "application/octet-stream"

        # Определение kind на основе content_type
        if content_type.startswith("image/"):
            kind = "photo"
        elif content_type == "application/pdf":
            kind = "pdf"
        else:
            kind = "document"

        # Генерация ключа для хранения
        key = s3_service.generate_key(
            child_id=episode.child_id,
            episode_id=episode_id,
            filename=file.filename or "unknown",
        )

        # Загрузка в Object Storage
        result = s3_service.upload_file(
            file_data=file_data,
            key=key,
            content_type=content_type,
            compress=(kind == "photo"),  # Сжимаем только фото
        )

        if not result["success"]:
            raise HTTPException(
                status_code=500,
                detail=f"Ошибка загрузки файла: {result.get('error')}",
            )

        # Создание записи вложения в БД
        attachment = Attachment(
            mobile_id=0,  # Будет обновлено при синхронизации
            episode_id=episode_id,
            kind=kind,
            cloud_key=result["key"],
            cloud_url=result["url"],
            file_size=result["size"],
            at_datetime=datetime.utcnow(),
        )

        db.add(attachment)
        db.commit()
        db.refresh(attachment)

        return FileUploadResponse(
            success=True,
            cloud_key=result["key"],
            cloud_url=result["url"],
            file_size=result["size"],
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Ошибка обработки файла: {str(e)}",
        )
