"""
Database Models for TractorCare
SQLAlchemy ORM models for all database tables
"""
from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, Enum, Boolean, Text, JSON
from sqlalchemy.orm import relationship
from datetime import datetime
import enum

from database import Base

# ============================================================================
# ENUMS
# ============================================================================

class TractorModel(enum.Enum):
    MF_240 = "MF_240"
    MF_375 = "MF_375"
    MF_385 = "MF_385"
    JOHN_DEERE_5075E = "JOHN_DEERE_5075E"
    NEW_HOLLAND_TD5 = "NEW_HOLLAND_TD5"

class UsageIntensity(enum.Enum):
    light = "light"
    moderate = "moderate"
    heavy = "heavy"

class AlertSeverity(enum.Enum):
    info = "info"
    warning = "warning"
    critical = "critical"

# ============================================================================
# USER MODEL
# ============================================================================

class User(Base):
    __tablename__ = "users"
    
    user_id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True, nullable=False)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    full_name = Column(String, nullable=False)
    phone_number = Column(String)
    role = Column(String, default="operator")  # admin, manager, operator
    coop_id = Column(String, ForeignKey("cooperatives.coop_id"))
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.now)
    last_login = Column(DateTime)
    
    # Relationships
    cooperative = relationship("Cooperative", back_populates="users")

# ============================================================================
# COOPERATIVE MODEL
# ============================================================================

class Cooperative(Base):
    __tablename__ = "cooperatives"
    
    coop_id = Column(String, primary_key=True, index=True)
    name = Column(String, nullable=False)
    location = Column(String)
    district = Column(String)
    province = Column(String)
    contact_person = Column(String)
    phone_number = Column(String)
    email = Column(String)
    registration_date = Column(DateTime, default=datetime.now)
    total_members = Column(Integer, default=0)
    
    # Relationships
    tractors = relationship("Tractor", back_populates="cooperative")
    members = relationship("Member", back_populates="cooperative")
    users = relationship("User", back_populates="cooperative")

# ============================================================================
# TRACTOR MODEL
# ============================================================================

class Tractor(Base):
    __tablename__ = "tractors"
    
    tractor_id = Column(String, primary_key=True, index=True)
    coop_id = Column(String, ForeignKey("cooperatives.coop_id"), nullable=False)
    model = Column(Enum(TractorModel), nullable=False)
    serial_number = Column(String, unique=True)
    purchase_date = Column(DateTime)
    engine_hours = Column(Float, default=0)
    usage_intensity = Column(Enum(UsageIntensity), default=UsageIntensity.moderate)
    current_status = Column(String, default="available")
    last_maintenance_date = Column(DateTime)
    created_at = Column(DateTime, default=datetime.now)
    updated_at = Column(DateTime, default=datetime.now, onupdate=datetime.now)
    
    # Relationships
    cooperative = relationship("Cooperative", back_populates="tractors")
    bookings = relationship("Booking", back_populates="tractor")
    maintenance_records = relationship("MaintenanceRecord", back_populates="tractor")
    predictions = relationship("MaintenancePrediction", back_populates="tractor")

# ============================================================================
# MEMBER MODEL
# ============================================================================

class Member(Base):
    __tablename__ = "members"
    
    member_id = Column(String, primary_key=True, index=True)
    coop_id = Column(String, ForeignKey("cooperatives.coop_id"), nullable=False)
    name = Column(String, nullable=False)
    phone_number = Column(String)
    id_number = Column(String)
    is_premium = Column(Boolean, default=False)
    membership_status = Column(String, default="active")
    join_date = Column(DateTime, default=datetime.now)
    
    # Relationships
    cooperative = relationship("Cooperative", back_populates="members")
    bookings = relationship("Booking", back_populates="member")

# ============================================================================
# BOOKING MODEL
# ============================================================================

class Booking(Base):
    __tablename__ = "bookings"
    
    booking_id = Column(Integer, primary_key=True, index=True)
    tractor_id = Column(String, ForeignKey("tractors.tractor_id"), nullable=False)
    member_id = Column(String, ForeignKey("members.member_id"), nullable=False)
    coop_id = Column(String, ForeignKey("cooperatives.coop_id"), nullable=False)
    start_date = Column(DateTime, nullable=False)
    end_date = Column(DateTime, nullable=False)
    booking_status = Column(String, default="pending")
    payment_status = Column(String, default="unpaid")
    payment_amount_rwf = Column(Integer)
    created_at = Column(DateTime, default=datetime.now)
    updated_at = Column(DateTime, default=datetime.now, onupdate=datetime.now)
    
    # Relationships
    tractor = relationship("Tractor", back_populates="bookings")
    member = relationship("Member", back_populates="bookings")

# ============================================================================
# MAINTENANCE RECORD MODEL
# ============================================================================

class MaintenanceRecord(Base):
    __tablename__ = "maintenance_records"
    
    record_id = Column(Integer, primary_key=True, index=True)
    tractor_id = Column(String, ForeignKey("tractors.tractor_id"), nullable=False)
    task_name = Column(String, nullable=False)
    description = Column(Text)
    date = Column(DateTime, nullable=False)
    engine_hours_at_service = Column(Float)
    cost_rwf = Column(Integer)
    performed_by = Column(String)
    notes = Column(Text)
    created_at = Column(DateTime, default=datetime.now)
    
    # Relationships
    tractor = relationship("Tractor", back_populates="maintenance_records")

# ============================================================================
# MAINTENANCE PREDICTION MODEL
# ============================================================================

class MaintenancePrediction(Base):
    __tablename__ = "maintenance_predictions"
    
    prediction_id = Column(Integer, primary_key=True, index=True)
    tractor_id = Column(String, ForeignKey("tractors.tractor_id"), nullable=False)
    task_name = Column(String, nullable=False)
    description = Column(Text)
    status = Column(String)  # overdue, urgent, due_soon, upcoming
    urgency_level = Column(Integer)
    priority = Column(String)
    hours_remaining = Column(Float)
    days_remaining = Column(Integer)
    estimated_cost_rwf = Column(Integer)
    recommendation = Column(Text)
    prediction_date = Column(DateTime, default=datetime.now)
    
    # Relationships
    tractor = relationship("Tractor", back_populates="predictions")

# ============================================================================
# ML PREDICTION MODEL
# ============================================================================

class MLPrediction(Base):
    __tablename__ = "ml_predictions"
    
    prediction_id = Column(Integer, primary_key=True, index=True)
    tractor_id = Column(String, ForeignKey("tractors.tractor_id"), nullable=False)
    prediction_class = Column(String)  # good, warning, critical
    confidence = Column(Float)
    probabilities = Column(JSON)
    model_used = Column(String)
    engine_hours_at_prediction = Column(Float)
    created_at = Column(DateTime, default=datetime.now)

# ============================================================================
# ALERT MODEL
# ============================================================================

class Alert(Base):
    __tablename__ = "alerts"
    
    alert_id = Column(Integer, primary_key=True, index=True)
    tractor_id = Column(String, ForeignKey("tractors.tractor_id"))
    coop_id = Column(String, ForeignKey("cooperatives.coop_id"), nullable=False)
    severity = Column(Enum(AlertSeverity), nullable=False)
    title = Column(String, nullable=False)
    message = Column(Text, nullable=False)
    action_required = Column(String)
    is_dismissed = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.now)

# ============================================================================
# SYNC LOG MODEL (for offline/online sync tracking)
# ============================================================================

class SyncLog(Base):
    __tablename__ = "sync_logs"
    
    sync_id = Column(Integer, primary_key=True, index=True)
    device_id = Column(String, nullable=False)
    sync_timestamp = Column(DateTime, default=datetime.now)
    sync_type = Column(String)  # upload, download, bidirectional
    data_type = Column(String)  # tractors, bookings, predictions, etc.
    records_count = Column(Integer)
    status = Column(String)  # success, failed, partial
    error_message = Column(Text)