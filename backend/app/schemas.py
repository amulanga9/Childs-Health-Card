"""
Pydantic схемы для валидации запросов и ответов
"""
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime, date


# ============ Child ============

class ChildBase(BaseModel):
    mobile_id: int
    name: str
    birth_date: date
    blood_group: str = ""
    allergies: List[str] = []
    chronic_conditions: List[str] = []
    avatar: Optional[str] = None


class ChildCreate(ChildBase):
    pass


class ChildResponse(ChildBase):
    id: int
    created_at: datetime
    updated_at: Optional[datetime]

    class Config:
        from_attributes = True


# ============ Episode ============

class EpisodeBase(BaseModel):
    mobile_id: int
    child_id: int
    parent_episode_id: Optional[int] = None
    diagnosis: str
    start_date: datetime
    end_date: Optional[datetime] = None
    status: str = "active"
    notes: str = ""


class EpisodeCreate(EpisodeBase):
    pass


class EpisodeResponse(EpisodeBase):
    id: int
    created_at: datetime
    updated_at: Optional[datetime]

    class Config:
        from_attributes = True


# ============ Prescription ============

class PrescriptionBase(BaseModel):
    mobile_id: int
    episode_id: int
    drug_name: str
    dose: str
    schedule: str
    start_date: datetime
    end_date: Optional[datetime] = None


class PrescriptionCreate(PrescriptionBase):
    pass


class PrescriptionResponse(PrescriptionBase):
    id: int
    created_at: datetime
    updated_at: Optional[datetime]

    class Config:
        from_attributes = True


# ============ Intake ============

class IntakeBase(BaseModel):
    mobile_id: int
    prescription_id: int
    at_datetime: datetime
    taken: bool
    reason_skip: str = ""


class IntakeCreate(IntakeBase):
    pass


class IntakeResponse(IntakeBase):
    id: int
    created_at: datetime

    class Config:
        from_attributes = True


# ============ Test ============

class TestBase(BaseModel):
    mobile_id: int
    episode_id: int
    kind: str
    at_datetime: datetime
    result_text: str = ""
    attachment_id: Optional[int] = None


class TestCreate(TestBase):
    pass


class TestResponse(TestBase):
    id: int
    created_at: datetime

    class Config:
        from_attributes = True


# ============ Procedure ============

class ProcedureBase(BaseModel):
    mobile_id: int
    episode_id: int
    kind: str
    at_datetime: datetime
    status: str = "scheduled"
    note: str = ""


class ProcedureCreate(ProcedureBase):
    pass


class ProcedureResponse(ProcedureBase):
    id: int
    created_at: datetime

    class Config:
        from_attributes = True


# ============ Attachment ============

class AttachmentBase(BaseModel):
    mobile_id: int
    episode_id: int
    kind: str
    local_path: str = ""
    cloud_key: Optional[str] = None
    cloud_url: Optional[str] = None
    file_size: Optional[int] = None
    at_datetime: datetime


class AttachmentCreate(AttachmentBase):
    pass


class AttachmentResponse(AttachmentBase):
    id: int
    created_at: datetime

    class Config:
        from_attributes = True


# ============ Sync Request ============

class SyncRequest(BaseModel):
    """Запрос на синхронизацию данных с мобильного приложения"""
    children: List[ChildCreate] = []
    episodes: List[EpisodeCreate] = []
    prescriptions: List[PrescriptionCreate] = []
    intakes: List[IntakeCreate] = []
    tests: List[TestCreate] = []
    procedures: List[ProcedureCreate] = []
    attachments: List[AttachmentCreate] = []


class SyncResponse(BaseModel):
    """Ответ на синхронизацию"""
    success: bool
    message: str
    synced_counts: dict


# ============ QR Token ============

class QRTokenCreate(BaseModel):
    """Запрос на создание QR токена"""
    child_id: int
    episode_id: Optional[int] = None
    description: str = ""
    expire_hours: int = Field(default=48, ge=1, le=168)  # От 1 часа до 7 дней


class QRTokenResponse(BaseModel):
    """Ответ с QR токеном"""
    token: str
    qr_image_url: str
    expires_at: datetime
    web_url: str

    class Config:
        from_attributes = True


# ============ QR Data Response ============

class QRDataEpisode(BaseModel):
    """Эпизод для QR данных"""
    diagnosis: str
    start_date: datetime
    end_date: Optional[datetime]
    status: str
    notes: str
    prescriptions: List[PrescriptionResponse]
    tests: List[TestResponse]
    procedures: List[ProcedureResponse]
    attachments: List[AttachmentResponse]

    class Config:
        from_attributes = True


class YearlyStats(BaseModel):
    """Статистика за год"""
    year: int
    episodes_count: int
    average_duration_days: float
    top_diagnoses: List[dict]


class QRDataResponse(BaseModel):
    """Данные доступные по QR токену"""
    child: ChildResponse
    latest_episode: Optional[QRDataEpisode]
    yearly_stats: YearlyStats
    generated_at: datetime
    expires_at: datetime


# ============ File Upload ============

class FileUploadResponse(BaseModel):
    """Ответ на загрузку файла"""
    success: bool
    cloud_key: str
    cloud_url: str
    file_size: int
