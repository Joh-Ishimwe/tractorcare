"""
MongoDB Models using Beanie ODM
NO cost estimates - only verifiable data from manuals
"""

from datetime import datetime
# from typing import Optional, List
from typing import Dict, List, Optional
from enum import Enum
from beanie import Document, Indexed
from pydantic import BaseModel, Field, EmailStr
from bson import ObjectId


# ============================================================================
# ENUMS
# ============================================================================

class UsageIntensity(str, Enum):
    """Tractor usage intensity levels"""
    LIGHT = "light"
    MODERATE = "moderate"
    HEAVY = "heavy"
    EXTREME = "extreme"


class MaintenancePriority(str, Enum):
    """Maintenance priority levels"""
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


class MaintenanceStatus(str, Enum):
    """Maintenance task status"""
    SCHEDULED = "scheduled"
    DUE = "due"
    OVERDUE = "overdue"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    CANCELLED = "cancelled"


class AlertType(str, Enum):
    """Types of maintenance alerts"""
    ROUTINE_SCHEDULED = "routine_scheduled"
    ROUTINE_OVERDUE = "routine_overdue"
    AUDIO_ANOMALY = "audio_anomaly"
    CRITICAL_FAILURE = "critical_failure"
    TREND_DEGRADATION = "trend_degradation"


class PredictionClass(str, Enum):
    """Audio prediction classes"""
    NORMAL = "normal"
    ABNORMAL = "abnormal"
    UNKNOWN = "unknown"


class HealthStatus(str, Enum):
    """Tractor health status"""
    EXCELLENT = "excellent"
    GOOD = "good"
    FAIR = "fair"
    POOR = "poor"
    CRITICAL = "critical"


# ============================================================================
# EMBEDDED MODELS (Not stored as separate documents)
# ============================================================================

class Location(BaseModel):
    """Geographic location"""
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    address: Optional[str] = None
    district: Optional[str] = None
    sector: Optional[str] = None


class MaintenanceTaskInfo(BaseModel):
    """Maintenance task information from manual"""
    task_name: str
    description: str
    priority: MaintenancePriority
    interval_hours: float
    interval_days: int
    estimated_time_minutes: int
    source: str  # e.g., "MF 240 Manual, Section 7.2"
    category: str = "routine"  # routine, audio_triggered, emergency


class LastMaintenanceRecord(BaseModel):
    """Track last maintenance for each task"""
    date: datetime
    engine_hours: float
    record_id: Optional[str] = None


class AudioFeatures(BaseModel):
    """Extracted audio features"""
    mfcc_mean: Optional[List[float]] = None
    mfcc_std: Optional[List[float]] = None
    spectral_centroid: Optional[float] = None
    spectral_rolloff: Optional[float] = None
    zero_crossing_rate: Optional[float] = None
    rms_energy: Optional[float] = None


# ============================================================================
# MAIN DOCUMENTS (Collections)
# ============================================================================

class User(Document):
    """User/Farmer model"""
    email: EmailStr
    phone: Optional[str] = None
    full_name: str
    hashed_password: Optional[str] = None
    is_active: bool = True
    is_verified: bool = False
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    location: Optional[Location] = None
    
    class Settings:
        name = "users"
        # indexes = ["email"]


class Tractor(Document):
    """Tractor model with maintenance tracking"""
    tractor_id: Indexed(str, unique=True)
    owner_id: Indexed(str)  # Reference to User
    model: str  # e.g., "MF_240", "MF_375"
    make: str = "Massey Ferguson"
    purchase_date: datetime
    engine_hours: float = 0.0
    usage_intensity: UsageIntensity = UsageIntensity.MODERATE
    baseline_status: str = "pending"  # pending, completed
    health_status: HealthStatus = HealthStatus.GOOD
    location: Optional[Location] = None
    
    # Maintenance tracking
    last_maintenance: Dict[str, LastMaintenanceRecord] = Field(default_factory=dict)
    parts_used: List[str] = Field(default_factory=list)
    # Metadata
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    
    class Settings:
        name = "tractors"
        indexes = ["tractor_id", "owner_id"]


class MaintenanceRecord(Document):
    """Completed maintenance records"""
    tractor_id: Indexed(str)
    task_name: str
    description: str
    completion_date: datetime
    completion_hours: float  # Engine hours at completion
    actual_time_minutes: int
    
    # Optional: User can enter actual cost they paid
    actual_cost_rwf: Optional[int] = None
    service_location: Optional[str] = None
    service_provider: Optional[str] = None
    
    # Details
    notes: Optional[str] = None
    performed_by: Optional[str] = None
    parts_used: Optional[List[str]] = Field(default_factory=list)
    
    # Metadata
    created_at: datetime = Field(default_factory=datetime.utcnow)
    
    class Settings:
        name = "maintenance_records"
        indexes = ["tractor_id", "completion_date"]


class MaintenanceAlert(Document):
    """Maintenance alerts/predictions"""
    tractor_id: Indexed(str)
    alert_type: AlertType
    priority: MaintenancePriority
    status: MaintenanceStatus
    
    # Task details
    task_name: str
    description: str
    estimated_time_minutes: int
    source: str  # Reference to manual
    
    # Timing
    due_date: datetime
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    resolved_at: Optional[datetime] = None
    
    # Audio anomaly specific
    audio_anomaly_score: Optional[float] = None
    related_prediction_id: Optional[str] = None
    
    # NO COST ESTIMATES!
    # Cost is determined by user's mechanic
    
    class Settings:
        name = "maintenance_alerts"
        indexes = ["tractor_id", "status", "due_date"]


class AudioPrediction(Document):
    """Audio recording predictions"""
    tractor_id: Indexed(str)
    
    # File info
    filename: str
    file_path: str
    file_size_bytes: int
    duration_seconds: float
    
    # Prediction
    prediction_class: PredictionClass
    confidence: float
    anomaly_score: Optional[float] = None  # ← Add this line

    model_used: str
    
    # Audio features
    features: Optional[AudioFeatures] = None
    
    # Analysis metadata
    processing_time_ms: Optional[float] = None
    sample_rate: Optional[int] = None
    
    # Timestamps
    recorded_at: datetime = Field(default_factory=datetime.utcnow)
    processed_at: datetime = Field(default_factory=datetime.utcnow)
    
    class Settings:
        name = "audio_predictions"
        indexes = ["tractor_id", "prediction_class", "recorded_at"]


class Anomaly(Document):
    """Audio anomalies detected"""
    tractor_id: Indexed(str)
    prediction_id: str  # Reference to AudioPrediction
    
    anomaly_type: str  # e.g., "high_vibration", "unusual_noise"
    anomaly_score: float  # 0.0 to 1.0
    confidence: float
    
    description: str
    handled: bool = False  # Whether user acted on it
    
    # Related alerts
    generated_alert_ids: List[str] = Field(default_factory=list)
    
    created_at: datetime = Field(default_factory=datetime.utcnow)
    
    class Settings:
        name = "anomalies"
        indexes = ["tractor_id", "handled", "created_at"]


class MaintenanceSchedule(Document):
    """Maintenance schedule templates by model"""
    model: Indexed(str, unique=True)  # e.g., "MF_240"
    make: str
    tasks: List[MaintenanceTaskInfo]
    
    # Metadata
    source: str  # e.g., "Massey Ferguson MF 240 Operator Manual"
    last_updated: datetime = Field(default_factory=datetime.utcnow)
    
    class Settings:
        name = "maintenance_schedules"
        indexes = ["model"]


# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

async def get_all_document_models():
    """Return all document models for Beanie initialization"""
    return [
        User,
        Tractor,
        MaintenanceRecord,
        MaintenanceAlert,
        AudioPrediction,
        Anomaly,
        MaintenanceSchedule,
    ]