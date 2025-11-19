"""
Эндпоинты для работы с QR токенами
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session, selectinload
from sqlalchemy import func, extract
from datetime import datetime, timedelta
from typing import Optional
from ..database import get_db
from ..schemas import (
    QRTokenCreate,
    QRTokenResponse,
    QRDataResponse,
    QRDataEpisode,
    YearlyStats,
    ChildResponse,
    PrescriptionResponse,
    TestResponse,
    ProcedureResponse,
    AttachmentResponse,
)
from ..models import QRToken, Child, Episode, Prescription, Test, Procedure, Attachment
from ..services.qr_service import qr_service
from ..config import settings
from ..auth import verify_api_key_header


router = APIRouter(prefix="/qr", tags=["qr"])


@router.post("/generate", response_model=QRTokenResponse)
async def generate_qr_token(
    request: QRTokenCreate,
    db: Session = Depends(get_db),
    api_key: str = Depends(verify_api_key_header),
):
    """
    Генерация QR токена для доступа врача

    Требует аутентификации: добавьте заголовок X-API-Key

    Args:
        request: Данные для создания токена

    Returns:
        QR токен и ссылка на изображение
    """
    try:
        # Проверка существования ребёнка
        child = db.query(Child).filter(Child.id == request.child_id).first()
        if not child:
            raise HTTPException(status_code=404, detail="Ребёнок не найден")

        # Проверка эпизода если указан
        if request.episode_id:
            episode = db.query(Episode).filter(Episode.id == request.episode_id).first()
            if not episode:
                raise HTTPException(status_code=404, detail="Эпизод не найден")
            if episode.child_id != request.child_id:
                raise HTTPException(
                    status_code=400,
                    detail="Эпизод не принадлежит указанному ребёнку",
                )

        # Создание токена
        qr_token = qr_service.create_qr_token(
            db=db,
            child_id=request.child_id,
            episode_id=request.episode_id,
            description=request.description,
            expire_hours=request.expire_hours,
        )

        # URL для веб-интерфейса врача
        web_url = f"https://yourdomain.com/doctor/view/{qr_token.token}"

        # Генерация и загрузка QR изображения
        qr_image_url = qr_service.upload_qr_image(qr_token.token, web_url)

        return QRTokenResponse(
            token=qr_token.token,
            qr_image_url=qr_image_url,
            expires_at=qr_token.expires_at,
            web_url=web_url,
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Ошибка генерации QR: {str(e)}")


@router.get("/{token}", response_model=QRDataResponse)
async def get_qr_data(
    token: str,
    db: Session = Depends(get_db),
):
    """
    Получение данных по QR токену

    Возвращает:
    - Информацию о ребёнке
    - Последний эпизод (если есть)
    - Статистику за последний год

    Args:
        token: QR токен

    Returns:
        Данные для врача
    """
    try:
        # Валидация токена
        qr_token = qr_service.validate_token(db, token)

        # Получение данных ребёнка
        child = db.query(Child).filter(Child.id == qr_token.child_id).first()
        if not child:
            raise HTTPException(status_code=404, detail="Ребёнок не найден")

        # Получение последнего эпизода или указанного
        # PERFORMANCE: Используем selectinload для eager loading всех связанных данных (исправлен N+1 queries)
        latest_episode = None
        if qr_token.episode_id:
            # Если указан конкретный эпизод
            episode = (
                db.query(Episode)
                .options(
                    selectinload(Episode.prescriptions),
                    selectinload(Episode.tests),
                    selectinload(Episode.procedures),
                    selectinload(Episode.attachments),
                )
                .filter(Episode.id == qr_token.episode_id)
                .first()
            )
        else:
            # Последний эпизод ребёнка
            episode = (
                db.query(Episode)
                .options(
                    selectinload(Episode.prescriptions),
                    selectinload(Episode.tests),
                    selectinload(Episode.procedures),
                    selectinload(Episode.attachments),
                )
                .filter(Episode.child_id == child.id)
                .order_by(Episode.start_date.desc())
                .first()
            )

        if episode:
            # Связанные данные уже загружены через selectinload (1 запрос вместо 4)
            prescriptions = episode.prescriptions
            tests = episode.tests
            procedures = episode.procedures
            attachments = episode.attachments

            latest_episode = QRDataEpisode(
                diagnosis=episode.diagnosis,
                start_date=episode.start_date,
                end_date=episode.end_date,
                status=episode.status,
                notes=episode.notes,
                prescriptions=[PrescriptionResponse.from_orm(p) for p in prescriptions],
                tests=[TestResponse.from_orm(t) for t in tests],
                procedures=[ProcedureResponse.from_orm(p) for p in procedures],
                attachments=[AttachmentResponse.from_orm(a) for a in attachments],
            )

        # Статистика за последний год
        current_year = datetime.now().year
        yearly_stats = _calculate_yearly_stats(db, child.id, current_year)

        return QRDataResponse(
            child=ChildResponse.from_orm(child),
            latest_episode=latest_episode,
            yearly_stats=yearly_stats,
            generated_at=qr_token.created_at,
            expires_at=qr_token.expires_at,
        )

    except ValueError as e:
        raise HTTPException(status_code=401, detail=str(e))
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Ошибка получения данных: {str(e)}")


@router.delete("/{token}")
async def invalidate_qr_token(
    token: str,
    db: Session = Depends(get_db),
    api_key: str = Depends(verify_api_key_header),
):
    """
    Деактивация QR токена

    Требует аутентификации: добавьте заголовок X-API-Key

    Args:
        token: QR токен для деактивации

    Returns:
        Статус операции
    """
    success = qr_service.invalidate_token(db, token)

    if success:
        return {"success": True, "message": "Токен деактивирован"}
    else:
        raise HTTPException(status_code=404, detail="Токен не найден")


def _calculate_yearly_stats(db: Session, child_id: int, year: int) -> YearlyStats:
    """
    Расчёт статистики эпизодов за год

    Args:
        db: Сессия БД
        child_id: ID ребёнка
        year: Год для расчёта

    Returns:
        Статистика за год
    """
    # Эпизоды за год
    episodes = (
        db.query(Episode)
        .filter(
            Episode.child_id == child_id,
            extract("year", Episode.start_date) == year,
        )
        .all()
    )

    episodes_count = len(episodes)

    # Средняя длительность
    if episodes_count > 0:
        total_days = 0
        for episode in episodes:
            end_date = episode.end_date or datetime.utcnow()
            duration = (end_date - episode.start_date).days
            total_days += duration

        average_duration = total_days / episodes_count
    else:
        average_duration = 0.0

    # Топ диагнозов
    diagnoses_count = {}
    for episode in episodes:
        diagnoses_count[episode.diagnosis] = diagnoses_count.get(episode.diagnosis, 0) + 1

    top_diagnoses = [
        {"diagnosis": diagnosis, "count": count}
        for diagnosis, count in sorted(
            diagnoses_count.items(),
            key=lambda x: x[1],
            reverse=True,
        )[:5]
    ]

    return YearlyStats(
        year=year,
        episodes_count=episodes_count,
        average_duration_days=round(average_duration, 1),
        top_diagnoses=top_diagnoses,
    )
