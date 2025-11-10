"""
Pydantic Schemas for API Request/Response
UPDATED: Added AudioPredictionListResponse for pagination
"""

from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, Field, EmailStr, validator
from app.models import (
    UsageIntensity,
    MaintenancePriority,
    MaintenanceStatus,
    AlertType,
    PredictionClass,
    HealthStatus,
)


# ============================================================================
# USER SCHEMAS
# ============================================================================
# Add these schemas

class DailyUsageCreate(BaseModel):
    """Schema for recording daily usage"""
    end_hours: float = Field(..., gt=0, description="Current engine hours")
    notes: Optional[str] = Field(None, max_length=500)

class DailyUsageResponse(BaseModel):
    """Schema for daily usage response"""
    id: str
    tractor_id: str
    date: datetime
    start_hours: float
    end_hours: float
    hours_used: float
    notes: Optional[str]
    created_at: datetime
class UserCreate(BaseModel):
    """Schema for creating a new user"""
    email: EmailStr
    password: str = Field(..., min_length=8)
    full_name: str = Field(..., min_length=2)
    phone: Optional[str] = None


class UserLogin(BaseModel):
    """Schema for user login"""
    email: EmailStr
    password: str


class UserResponse(BaseModel):
    """Schema for user response"""
    id: str
    email: EmailStr
    full_name: str
    phone: Optional[str] = None
    is_active: bool
    created_at: datetime
    
    class Config:
        from_attributes = True


class Token(BaseModel):
    """JWT token response"""
    access_token: str
    token_type: str = "bearer"


# ============================================================================
# TRACTOR SCHEMAS
# ============================================================================

class TractorCreate(BaseModel):
    """Schema for creating a new tractor"""
    tractor_id: str = Field(..., min_length=3, max_length=20)
    model: str = Field(..., pattern="^(MF_240|MF_375)$")
    purchase_date: datetime
    engine_hours: float = Field(default=0.0, ge=0)
    usage_intensity: UsageIntensity = UsageIntensity.MODERATE
    
    @validator("tractor_id")
    def validate_tractor_id(cls, v):
        if not v.isalnum():
            raise ValueError("Tractor ID must be alphanumeric")
        return v.upper()


class TractorUpdate(BaseModel):
    """Schema for updating tractor"""
    engine_hours: Optional[float] = Field(None, ge=0)
    usage_intensity: Optional[UsageIntensity] = None
    health_status: Optional[HealthStatus] = None


class TractorResponse(BaseModel):
    """Schema for tractor response"""
    id: str
    tractor_id: str
    owner_id: str
    model: str
    make: str
    purchase_date: datetime
    engine_hours: float
    usage_intensity: UsageIntensity
    health_status: HealthStatus
    baseline_status: str
    created_at: datetime
    
    class Config:
        from_attributes = True


# ============================================================================
# MAINTENANCE SCHEMAS
# ============================================================================

class MaintenanceRecordCreate(BaseModel):
    """Schema for recording completed maintenance"""
    task_name: str
    description: str
    completion_date: datetime
    completion_hours: float = Field(..., ge=0)
    actual_time_minutes: int = Field(..., gt=0)
    
    # Optional user-entered cost
    actual_cost_rwf: Optional[int] = Field(None, ge=0)
    service_location: Optional[str] = None
    service_provider: Optional[str] = None
    
    notes: Optional[str] = None
    performed_by: Optional[str] = None
    parts_used: Optional[List[str]] = Field(default_factory=list)


class MaintenanceTaskCreate(BaseModel):
    """Schema for creating a new maintenance task"""
    type: str = Field(..., description="Type of maintenance (oil_change, inspection, etc.)")
    task_name: str = Field(..., description="Name of the maintenance task")
    description: str = Field(..., description="Detailed description of the task")
    
    # Scheduling
    due_date: Optional[datetime] = None
    due_at_hours: Optional[float] = Field(None, ge=0, description="Engine hours when task is due")
    
    # Task properties
    priority: str = Field(default="MEDIUM", description="Priority level (LOW, MEDIUM, HIGH)")
    trigger_type: str = Field(default="MANUAL", description="How task was created (MANUAL, ABNORMAL_SOUND, USAGE_INTERVAL)")
    prediction_id: Optional[str] = Field(None, description="Related prediction ID if triggered by abnormal sound")
    
    # Estimates
    estimated_time_minutes: Optional[int] = Field(None, gt=0)
    estimated_cost: Optional[float] = Field(None, ge=0)
    
    notes: Optional[str] = None


class MaintenanceTaskResponse(BaseModel):
    """Schema for maintenance task response"""
    id: str
    tractor_id: str
    type: str
    task_name: str
    description: str
    
    # Scheduling
    due_date: Optional[datetime] = None
    due_at_hours: Optional[float] = None
    
    # Task properties
    priority: str
    trigger_type: str
    prediction_id: Optional[str] = None
    status: str = "PENDING"
    
    # Estimates
    estimated_time_minutes: Optional[int] = None
    estimated_cost: Optional[float] = None
    
    notes: Optional[str] = None
    created_at: datetime
    
    class Config:
        from_attributes = True


class MaintenanceRecordResponse(BaseModel):
    """Schema for maintenance record response"""
    id: str
    tractor_id: str
    task_name: str
    description: str
    completion_date: datetime
    completion_hours: float
    actual_time_minutes: int
    actual_cost_rwf: Optional[int] = None
    service_location: Optional[str] = None
    notes: Optional[str] = None
    created_at: datetime
    
    class Config:
        from_attributes = True


# ============================================================================
# ALERT SCHEMAS
# ============================================================================

class MaintenanceAlertResponse(BaseModel):
    """
    Schema for maintenance alert response
    NO COST ESTIMATES - user contacts mechanic for pricing
    """
    id: str
    tractor_id: str
    alert_type: AlertType
    priority: MaintenancePriority
    status: MaintenanceStatus
    
    task_name: str
    description: str
    estimated_time_minutes: int
    source: str
    
    due_date: datetime
    created_at: datetime
    
    # Audio anomaly specific
    audio_anomaly_score: Optional[float] = None
    
    # Cost note instead of estimate
    cost_note: str = "Contact your mechanic for pricing quote"
    
    class Config:
        from_attributes = True


class AlertUpdateStatus(BaseModel):
    """Schema for updating alert status"""
    status: MaintenanceStatus
    notes: Optional[str] = None


# ============================================================================
# AUDIO PREDICTION SCHEMAS
# ============================================================================

class AudioUploadResponse(BaseModel):
    """Schema for audio upload response"""
    prediction_id: str
    prediction_class: PredictionClass
    confidence: float
    ml_model: str
    duration_seconds: float
    processing_time_ms: float
    recorded_at: datetime
    
    # Recommendation based on prediction
    recommendation: str
    
    class Config:
        from_attributes = True


class AudioPredictionResponse(BaseModel):
    """Schema for audio prediction response"""
    id: str
    tractor_id: str
    filename: str
    prediction_class: str
    confidence: float
    anomaly_score: Optional[float] = None
    file_path: str  # ← Changed from audio_file_path to file_path
    recorded_at: datetime
    ml_model: str
    duration_seconds: float
    baseline_comparison: Optional[dict] = None
    
    class Config:
        from_attributes = True


class AudioPredictionListResponse(BaseModel):
    """Schema for paginated list of audio predictions"""
    predictions: List[AudioPredictionResponse]
    total: int
    skip: int
    limit: int
    
    class Config:
        from_attributes = True


# ============================================================================
# MAINTENANCE SUMMARY SCHEMAS
# ============================================================================

class MaintenanceSummary(BaseModel):
    """
    Comprehensive maintenance summary
    NO COST ESTIMATES!
    """
    tractor_id: str
    model: str
    engine_hours: float
    health_score: float
    health_status: HealthStatus
    
    # Alerts summary
    total_alerts: int
    critical_alerts: int
    high_priority_alerts: int
    overdue_alerts: int
    
    # Estimated time (from manuals)
    total_estimated_time_minutes: int
    total_estimated_time_hours: float
    
    # User-tracked costs (if available)
    total_spent_rwf: Optional[int] = None
    maintenance_records_count: Optional[int] = None
    
    # Recent activity
    recent_anomaly_count: int
    last_maintenance_date: Optional[datetime] = None
    
    # Cost note
    cost_note: str = "Contact local mechanic for pricing. You can track your actual costs in the app."
    
    # Alerts list
    alerts: List[MaintenanceAlertResponse] = Field(default_factory=list)


class HealthScoreResponse(BaseModel):
    """Simple health score response"""
    tractor_id: str
    health_score: float
    health_status: HealthStatus
    last_updated: datetime


# ============================================================================
# STATISTICS SCHEMAS
# ============================================================================

class MaintenanceStatistics(BaseModel):
    """Statistics for user's maintenance history"""
    total_maintenance_count: int
    total_spent_rwf: Optional[int] = None  # Only if user entered costs
    average_cost_per_service: Optional[float] = None
    most_common_tasks: List[dict]  # [{"task_name": "...", "count": ...}]
    maintenance_by_month: List[dict]  # [{"month": "2024-10", "count": ...}]


class FleetStatistics(BaseModel):
    """Statistics for all user's tractors"""
    total_tractors: int
    total_alerts: int
    tractors_needing_attention: int
    total_engine_hours: float
    average_health_score: float


# ============================================================================
# PREDICTION REQUEST SCHEMAS
# ============================================================================

class PredictionRequest(BaseModel):
    """Request for rule-based predictions"""
    tractor_id: str
    current_engine_hours: Optional[float] = None


class BulkPredictionRequest(BaseModel):
    """Request predictions for multiple tractors"""
    tractor_ids: List[str]


# ============================================================================
# VALIDATORS
# ============================================================================

class DateRangeQuery(BaseModel):
    """Schema for date range queries"""
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    
    @validator("end_date")
    def validate_date_range(cls, v, values):
        if v and "start_date" in values and values["start_date"]:
            if v < values["start_date"]:
                raise ValueError("end_date must be after start_date")
        return v


# ============================================================================
# ERROR RESPONSE SCHEMA
# ============================================================================

class ErrorResponse(BaseModel):
    """Standard error response"""
    detail: str
    error_code: Optional[str] = None
    timestamp: datetime = Field(default_factory=datetime.utcnow)