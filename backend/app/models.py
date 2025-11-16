"""
SQLAlchemy модели для PostgreSQL
"""
from sqlalchemy import Column, Integer, String, DateTime, Boolean, ForeignKey, Text, Date, JSON
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from .database import Base


class Child(Base):
    """Модель ребёнка"""
    __tablename__ = "children"

    id = Column(Integer, primary_key=True, index=True)
    mobile_id = Column(Integer, unique=True, index=True)  # ID из мобильного приложения
    name = Column(String(200), nullable=False)
    birth_date = Column(Date, nullable=False)
    blood_group = Column(String(10), default="")
    allergies = Column(JSON, default=list)  # Список аллергий
    chronic_conditions = Column(JSON, default=list)  # Хронические заболевания
    avatar = Column(String(500))
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relationships
    episodes = relationship("Episode", back_populates="child", cascade="all, delete-orphan")
    qr_tokens = relationship("QRToken", back_populates="child", cascade="all, delete-orphan")


class Episode(Base):
    """Модель эпизода болезни"""
    __tablename__ = "episodes"

    id = Column(Integer, primary_key=True, index=True)
    mobile_id = Column(Integer, unique=True, index=True)
    child_id = Column(Integer, ForeignKey("children.id", ondelete="CASCADE"), nullable=False)
    parent_episode_id = Column(Integer, ForeignKey("episodes.id", ondelete="SET NULL"))
    diagnosis = Column(String(200), nullable=False)
    start_date = Column(DateTime, nullable=False)
    end_date = Column(DateTime)
    status = Column(String(50), default="active")  # active, closed
    notes = Column(Text, default="")
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relationships
    child = relationship("Child", back_populates="episodes")
    parent_episode = relationship("Episode", remote_side=[id], backref="child_episodes")
    prescriptions = relationship("Prescription", back_populates="episode", cascade="all, delete-orphan")
    tests = relationship("Test", back_populates="episode", cascade="all, delete-orphan")
    procedures = relationship("Procedure", back_populates="episode", cascade="all, delete-orphan")
    attachments = relationship("Attachment", back_populates="episode", cascade="all, delete-orphan")


class Prescription(Base):
    """Модель назначения лекарств"""
    __tablename__ = "prescriptions"

    id = Column(Integer, primary_key=True, index=True)
    mobile_id = Column(Integer, unique=True, index=True)
    episode_id = Column(Integer, ForeignKey("episodes.id", ondelete="CASCADE"), nullable=False)
    drug_name = Column(String(200), nullable=False)
    dose = Column(String(100), nullable=False)
    schedule = Column(String(200), nullable=False)  # "08:00, 14:00, 20:00"
    start_date = Column(DateTime, nullable=False)
    end_date = Column(DateTime)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relationships
    episode = relationship("Episode", back_populates="prescriptions")
    intakes = relationship("Intake", back_populates="prescription", cascade="all, delete-orphan")


class Intake(Base):
    """Модель приёма лекарства"""
    __tablename__ = "intakes"

    id = Column(Integer, primary_key=True, index=True)
    mobile_id = Column(Integer, unique=True, index=True)
    prescription_id = Column(Integer, ForeignKey("prescriptions.id", ondelete="CASCADE"), nullable=False)
    at_datetime = Column(DateTime, nullable=False)
    taken = Column(Boolean, default=False)
    reason_skip = Column(Text, default="")
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    prescription = relationship("Prescription", back_populates="intakes")


class Test(Base):
    """Модель анализа"""
    __tablename__ = "tests"

    id = Column(Integer, primary_key=True, index=True)
    mobile_id = Column(Integer, unique=True, index=True)
    episode_id = Column(Integer, ForeignKey("episodes.id", ondelete="CASCADE"), nullable=False)
    kind = Column(String(100), nullable=False)  # Тип анализа
    at_datetime = Column(DateTime, nullable=False)
    result_text = Column(Text, default="")
    attachment_id = Column(Integer, ForeignKey("attachments.id", ondelete="SET NULL"))
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    episode = relationship("Episode", back_populates="tests")
    attachment = relationship("Attachment", foreign_keys=[attachment_id])


class Procedure(Base):
    """Модель процедуры"""
    __tablename__ = "procedures"

    id = Column(Integer, primary_key=True, index=True)
    mobile_id = Column(Integer, unique=True, index=True)
    episode_id = Column(Integer, ForeignKey("episodes.id", ondelete="CASCADE"), nullable=False)
    kind = Column(String(100), nullable=False)
    at_datetime = Column(DateTime, nullable=False)
    status = Column(String(50), default="scheduled")  # completed, scheduled, cancelled
    note = Column(Text, default="")
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    episode = relationship("Episode", back_populates="procedures")


class Attachment(Base):
    """Модель вложения (файлы)"""
    __tablename__ = "attachments"

    id = Column(Integer, primary_key=True, index=True)
    mobile_id = Column(Integer, unique=True, index=True)
    episode_id = Column(Integer, ForeignKey("episodes.id", ondelete="CASCADE"), nullable=False)
    kind = Column(String(50), nullable=False)  # photo, pdf, document
    local_path = Column(String(500), default="")  # Путь на устройстве (для справки)
    cloud_key = Column(String(500))  # Ключ в Object Storage
    cloud_url = Column(String(1000))  # Публичный URL
    file_size = Column(Integer)  # Размер в байтах
    at_datetime = Column(DateTime, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    episode = relationship("Episode", back_populates="attachments")


class QRToken(Base):
    """Модель QR токена для доступа врача"""
    __tablename__ = "qr_tokens"

    id = Column(Integer, primary_key=True, index=True)
    child_id = Column(Integer, ForeignKey("children.id", ondelete="CASCADE"), nullable=False)
    episode_id = Column(Integer, ForeignKey("episodes.id", ondelete="CASCADE"))
    token = Column(String(128), unique=True, index=True, nullable=False)
    expires_at = Column(DateTime, nullable=False)
    is_active = Column(Boolean, default=True)
    description = Column(String(500), default="")
    accessed_count = Column(Integer, default=0)  # Счётчик обращений
    last_accessed_at = Column(DateTime)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    child = relationship("Child", back_populates="qr_tokens")
