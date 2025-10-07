"""
Pydantic schemas for request/response validation
"""
from pydantic import BaseModel, Field, validator
from typing import List, Optional, Dict
from datetime import datetime
from enum import Enum

# ============================================================================
# ENUMS
# ============================================================================

class UsageIntensityEnum(str, Enum):
    LIGHT = "light"
    MODERATE = "moderate"
    HEAVY = "heavy"
    EXTREME = "extreme"

class TractorModelEnum(str, Enum):
    MF_240 = "MF_240"
    MF_375 = "MF_375"

# ============================================================================
# REQUEST SCHEMAS
# ============================================================================

class CooperativeCreate(BaseModel):
    coop_id: str
    name: str
    location: Optional[str]
    district: str
    contact_person: str
    phone_number: str
    email: Optional[str]

class MemberCreate(BaseModel):
    member_id: str
    coop_id: str
    name: str
    phone_number: str
    national_id: str
    plot_size_hectares: Optional[float]
    location: Optional[str]
    is_premium: bool = False

class TractorCreate(BaseModel):
    tractor_id: str
    coop_id: str
    model: TractorModelEnum
    serial_number: str
    purchase_date: str
    engine_hours: float = 0.0
    usage_intensity: UsageIntensityEnum = UsageIntensityEnum.MODERATE
    
    @validator('purchase_date')
    def validate_date(cls, v):
        try:
            datetime.strptime(v, "%Y-%m-%d")
        except ValueError:
            raise ValueError("Date must be YYYY-MM-DD format")
        return v

class TractorUpdate(BaseModel):
    engine_hours: Optional[float]
    usage_intensity: Optional[UsageIntensityEnum]
    current_status: Optional[str]
    gps_latitude: Optional[float]
    gps_longitude: Optional[float]

class MaintenanceRecordCreate(BaseModel):
    tractor_id: str
    task_name: str
    task_description: Optional[str]
    date: str
    engine_hours_at_service: float
    cost_rwf: Optional[int]
    performed_by: Optional[str]
    notes: Optional[str]

class BookingCreate(BaseModel):
    tractor_id: str
    member_id: str
    coop_id: str
    start_date: str
    end_date: str
    plot_location: Optional[str]
    service_type: str
    estimated_hours: float
    payment_amount_rwf: int

# ============================================================================
# RESPONSE SCHEMAS
# ============================================================================

class TractorResponse(BaseModel):
    tractor_id: str
    coop_id: str
    model: str
    engine_hours: float
    usage_intensity: str
    current_status: str
    last_maintenance_date: Optional[datetime]
    
    class Config:
        orm_mode = True

class MaintenanceRecordResponse(BaseModel):
    record_id: int
    tractor_id: str
    task_name: str
    date: datetime
    cost_rwf: Optional[int]
    
    class Config:
        orm_mode = True

class BookingResponse(BaseModel):
    booking_id: int
    tractor_id: str
    member_id: str
    start_date: datetime
    end_date: datetime
    booking_status: str
    payment_status: str
    
    class Config:
        orm_mode = True