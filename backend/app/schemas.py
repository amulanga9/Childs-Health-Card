"""
Pydantic схемы для валидации запросов и ответов

SECURITY: Все поля имеют валидацию для защиты от DoS и инъекций
"""
from pydantic import BaseModel, Field, field_validator, model_validator
from typing import Optional, List, Literal
from datetime import datetime, date
from enum import Enum


# ============ Enums для типобезопасности ============

class BloodGroup(str, Enum):
    """Группы крови"""
    A_POSITIVE = "A+"
    A_NEGATIVE = "A-"
    B_POSITIVE = "B+"
    B_NEGATIVE = "B-"
    AB_POSITIVE = "AB+"
    AB_NEGATIVE = "AB-"
    O_POSITIVE = "O+"
    O_NEGATIVE = "O-"
    UNKNOWN = ""


class EpisodeStatus(str, Enum):
    """Статусы эпизода"""
    ACTIVE = "active"
    RECOVERED = "recovered"
    CHRONIC = "chronic"


class ProcedureStatus(str, Enum):
    """Статусы процедуры"""
    SCHEDULED = "scheduled"
    COMPLETED = "completed"
    CANCELLED = "cancelled"


class AttachmentKind(str, Enum):
    """Типы вложений"""
    PHOTO = "photo"
    PDF = "pdf"
    DOCUMENT = "document"
    TEST_RESULT = "test_result"


# ============ Child ============

class ChildBase(BaseModel):
    mobile_id: int = Field(ge=0, description="ID с мобильного устройства")
    name: str = Field(min_length=1, max_length=100, description="Имя ребенка")
    birth_date: date = Field(description="Дата рождения")
    blood_group: str = Field(default="", max_length=5, description="Группа крови")
    allergies: List[str] = Field(default_factory=list, max_length=50, description="Список аллергий")
    chronic_conditions: List[str] = Field(default_factory=list, max_length=50, description="Хронические заболевания")
    avatar: Optional[str] = Field(default=None, max_length=500, description="Путь к аватару")

    @field_validator('blood_group')
    @classmethod
    def validate_blood_group(cls, v: str) -> str:
        """Валидация группы крови"""
        if v == "":
            return v
        valid_groups = {"A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"}
        if v not in valid_groups:
            raise ValueError(f'Неверная группа крови. Допустимые: {", ".join(valid_groups)}')
        return v

    @field_validator('allergies', 'chronic_conditions')
    @classmethod
    def validate_string_list(cls, v: List[str]) -> List[str]:
        """Валидация списков строк"""
        if len(v) > 50:
            raise ValueError('Слишком много элементов в списке (максимум 50)')
        for item in v:
            if len(item) > 200:
                raise ValueError('Элемент списка слишком длинный (максимум 200 символов)')
        return v

    @field_validator('birth_date')
    @classmethod
    def validate_birth_date(cls, v: date) -> date:
        """Валидация даты рождения"""
        if v > date.today():
            raise ValueError('Дата рождения не может быть в будущем')
        if v.year < 1900:
            raise ValueError('Дата рождения слишком далеко в прошлом')
        return v


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
    mobile_id: int = Field(ge=0, description="ID с мобильного устройства")
    child_id: int = Field(gt=0, description="ID ребенка")
    parent_episode_id: Optional[int] = Field(default=None, gt=0, description="ID родительского эпизода")
    diagnosis: str = Field(min_length=1, max_length=200, description="Диагноз")
    start_date: datetime = Field(description="Дата начала")
    end_date: Optional[datetime] = Field(default=None, description="Дата окончания")
    status: str = Field(default="active", max_length=20, description="Статус эпизода")
    notes: str = Field(default="", max_length=5000, description="Примечания")

    @field_validator('status')
    @classmethod
    def validate_status(cls, v: str) -> str:
        """Валидация статуса"""
        valid_statuses = {"active", "recovered", "chronic"}
        if v not in valid_statuses:
            raise ValueError(f'Неверный статус. Допустимые: {", ".join(valid_statuses)}')
        return v

    @model_validator(mode='after')
    def validate_dates(self) -> 'EpisodeBase':
        """Валидация дат"""
        if self.end_date and self.end_date < self.start_date:
            raise ValueError('Дата окончания не может быть раньше даты начала')
        return self


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
    mobile_id: int = Field(ge=0, description="ID с мобильного устройства")
    episode_id: int = Field(gt=0, description="ID эпизода")
    drug_name: str = Field(min_length=1, max_length=200, description="Название препарата")
    dose: str = Field(min_length=1, max_length=100, description="Дозировка")
    schedule: str = Field(min_length=1, max_length=200, description="Расписание приема")
    start_date: datetime = Field(description="Дата начала приема")
    end_date: Optional[datetime] = Field(default=None, description="Дата окончания приема")

    @model_validator(mode='after')
    def validate_dates(self) -> 'PrescriptionBase':
        """Валидация дат"""
        if self.end_date and self.end_date < self.start_date:
            raise ValueError('Дата окончания не может быть раньше даты начала')
        return self


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
    mobile_id: int = Field(ge=0, description="ID с мобильного устройства")
    prescription_id: int = Field(gt=0, description="ID назначения")
    at_datetime: datetime = Field(description="Дата и время приема")
    taken: bool = Field(description="Принято или пропущено")
    reason_skip: str = Field(default="", max_length=500, description="Причина пропуска")


class IntakeCreate(IntakeBase):
    pass


class IntakeResponse(IntakeBase):
    id: int
    created_at: datetime

    class Config:
        from_attributes = True


# ============ Test ============

class TestBase(BaseModel):
    mobile_id: int = Field(ge=0, description="ID с мобильного устройства")
    episode_id: int = Field(gt=0, description="ID эпизода")
    kind: str = Field(min_length=1, max_length=100, description="Тип анализа")
    at_datetime: datetime = Field(description="Дата и время анализа")
    result_text: str = Field(default="", max_length=5000, description="Результаты анализа")
    attachment_id: Optional[int] = Field(default=None, gt=0, description="ID вложения")


class TestCreate(TestBase):
    pass


class TestResponse(TestBase):
    id: int
    created_at: datetime

    class Config:
        from_attributes = True


# ============ Procedure ============

class ProcedureBase(BaseModel):
    mobile_id: int = Field(ge=0, description="ID с мобильного устройства")
    episode_id: int = Field(gt=0, description="ID эпизода")
    kind: str = Field(min_length=1, max_length=100, description="Тип процедуры")
    at_datetime: datetime = Field(description="Дата и время процедуры")
    status: str = Field(default="scheduled", max_length=20, description="Статус процедуры")
    note: str = Field(default="", max_length=2000, description="Примечание")

    @field_validator('status')
    @classmethod
    def validate_status(cls, v: str) -> str:
        """Валидация статуса"""
        valid_statuses = {"scheduled", "completed", "cancelled"}
        if v not in valid_statuses:
            raise ValueError(f'Неверный статус. Допустимые: {", ".join(valid_statuses)}')
        return v


class ProcedureCreate(ProcedureBase):
    pass


class ProcedureResponse(ProcedureBase):
    id: int
    created_at: datetime

    class Config:
        from_attributes = True


# ============ Attachment ============

class AttachmentBase(BaseModel):
    mobile_id: int = Field(ge=0, description="ID с мобильного устройства")
    episode_id: int = Field(gt=0, description="ID эпизода")
    kind: str = Field(min_length=1, max_length=50, description="Тип вложения")
    local_path: str = Field(default="", max_length=500, description="Локальный путь")
    cloud_key: Optional[str] = Field(default=None, max_length=500, description="Ключ в облаке")
    cloud_url: Optional[str] = Field(default=None, max_length=1000, description="URL в облаке")
    file_size: Optional[int] = Field(default=None, ge=0, le=100_000_000, description="Размер файла (макс 100MB)")
    at_datetime: datetime = Field(description="Дата и время создания")

    @field_validator('kind')
    @classmethod
    def validate_kind(cls, v: str) -> str:
        """Валидация типа вложения"""
        valid_kinds = {"photo", "pdf", "document", "test_result"}
        if v not in valid_kinds:
            raise ValueError(f'Неверный тип вложения. Допустимые: {", ".join(valid_kinds)}')
        return v


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
    children: List[ChildCreate] = Field(default_factory=list, max_length=100)
    episodes: List[EpisodeCreate] = Field(default_factory=list, max_length=1000)
    prescriptions: List[PrescriptionCreate] = Field(default_factory=list, max_length=1000)
    intakes: List[IntakeCreate] = Field(default_factory=list, max_length=5000)
    tests: List[TestCreate] = Field(default_factory=list, max_length=1000)
    procedures: List[ProcedureCreate] = Field(default_factory=list, max_length=1000)
    attachments: List[AttachmentCreate] = Field(default_factory=list, max_length=500)


class SyncResponse(BaseModel):
    """Ответ на синхронизацию"""
    success: bool
    message: str
    synced_counts: dict


# ============ QR Token ============

class QRTokenCreate(BaseModel):
    """Запрос на создание QR токена"""
    child_id: int = Field(gt=0, description="ID ребенка")
    episode_id: Optional[int] = Field(default=None, gt=0, description="ID эпизода")
    description: str = Field(default="", max_length=500, description="Описание")
    expire_hours: int = Field(default=48, ge=1, le=168, description="Срок действия (1-168 часов)")


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
    year: int = Field(ge=1900, le=2100)
    episodes_count: int = Field(ge=0)
    average_duration_days: float = Field(ge=0.0)
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
    cloud_key: str = Field(max_length=500)
    cloud_url: str = Field(max_length=1000)
    file_size: int = Field(ge=0, le=100_000_000, description="Размер файла (макс 100MB)")
