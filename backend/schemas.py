"""
Pydantic schemas for request/response validation
"""
from pydantic import BaseModel, Field, validator, EmailStr
from typing import Optional, Dict, Any
from datetime import datetime
from enum import Enum

# Enums
class TractorModelEnum(str, Enum):
    MF_240 = "MF_240"
    MF_375 = "MF_375"
    MF_385 = "MF_385"
    JOHN_DEERE_5075E = "JOHN_DEERE_5075E"
    NEW_HOLLAND_TD5 = "NEW_HOLLAND_TD5"

class UsageIntensityEnum(str, Enum):
    light = "light"
    moderate = "moderate"
    heavy = "heavy"
    extreme = "extreme"

class AlertSeverityEnum(str, Enum):
    info = "info"
    warning = "warning"
    critical = "critical"

# Auth Schemas
class UserCreate(BaseModel):
    username: str = Field(..., min_length=3, max_length=50)
    email: EmailStr
    password: str = Field(..., min_length=6)
    full_name: str
    phone_number: Optional[str] = None
    role: str = "operator"
    coop_id: Optional[str] = None

class UserLogin(BaseModel):
    username: str
    password: str

class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"

class TokenData(BaseModel):
    user_id: Optional[str] = None
    username: Optional[str] = None
    role: Optional[str] = None
    coop_id: Optional[str] = None

# Cooperative Schemas
class CooperativeCreate(BaseModel):
    coop_id: str
    name: str
    location: Optional[str] = None
    district: Optional[str] = None
    province: Optional[str] = None
    contact_person: str
    phone_number: str
    email: Optional[EmailStr] = None

# Tractor Schemas
class TractorCreate(BaseModel):
    tractor_id: str
    coop_id: str
    model: TractorModelEnum
    serial_number: str
    purchase_date: str
    engine_hours: float = 0.0
    usage_intensity: UsageIntensityEnum = UsageIntensityEnum.moderate
    
    @validator('purchase_date')
    def validate_date(cls, v):
        try:
            datetime.strptime(v, "%Y-%m-%d")
        except ValueError:
            raise ValueError("Date must be YYYY-MM-DD format")
        return v

class TractorUpdate(BaseModel):
    engine_hours: Optional[float] = None
    usage_intensity: Optional[UsageIntensityEnum] = None
    current_status: Optional[str] = None

# Member Schemas
class MemberCreate(BaseModel):
    member_id: str
    coop_id: str
    name: str
    phone_number: str
    id_number: str
    is_premium: bool = False

# Booking Schemas
class BookingCreate(BaseModel):
    tractor_id: str
    member_id: str
    coop_id: str
    start_date: str
    end_date: str
    payment_amount_rwf: int
    
    @validator('start_date', 'end_date')
    def validate_dates(cls, v):
        try:
            datetime.strptime(v, "%Y-%m-%d")
        except ValueError:
            raise ValueError("Date must be YYYY-MM-DD format")
        return v

# Maintenance Schemas
class MaintenanceRecordCreate(BaseModel):
    tractor_id: str
    task_name: str
    description: Optional[str] = None
    date: str
    engine_hours_at_service: float
    cost_rwf: Optional[int] = None
    performed_by: Optional[str] = None
    notes: Optional[str] = None
    
    @validator('date')
    def validate_date(cls, v):
        try:
            datetime.strptime(v, "%Y-%m-%d")
        except ValueError:
            raise ValueError("Date must be YYYY-MM-DD format")
        return v
