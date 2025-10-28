"""
MongoDB Models using Beanie ODM
NO cost estimates - only verifiable data from manuals
UPDATED: Added baseline models for personalized audio predictions
"""

from datetime import datetime
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


class BaselineStatus(str, Enum):
    """Status of baseline establishment"""
    ESTABLISHING = "establishing"
    ACTIVE = "active"
    ARCHIVED = "archived"
    INVALID = "invalid"


class LoadCondition(str, Enum):
    """Tractor load condition during recording"""
    IDLE = "idle"
    LIGHT = "light"
    NORMAL = "normal"
    HEAVY = "heavy"


class TrendStatus(str, Enum):
    """Health trend status"""
    NORMAL = "normal"
    WATCH = "watch"
    WARNING = "warning"
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
    anomaly_score: Optional[float] = None
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
# BASELINE MODELS (For Personalized Audio Predictions)
# ============================================================================

class TractorBaseline(Document):
    """
    Store baseline "normal" sound signature for each tractor
    This is the reference for what THIS specific tractor sounds like when healthy
    """
    tractor_id: str = Field(..., description="Tractor identifier")
    
    # Baseline MFCC features
    baseline_mean: List[float] = Field(..., description="Mean MFCC features (4000 values)")
    baseline_std: List[float] = Field(..., description="Standard deviation of MFCCs")
    
    # When baseline was established
    created_at: datetime = Field(default_factory=datetime.utcnow)
    tractor_hours: float = Field(..., description="Engine hours when baseline created")
    
    # Baseline quality metrics
    num_samples: int = Field(..., description="Number of recordings used")
    sample_files: List[str] = Field(default_factory=list, description="Paths to baseline recordings")
    confidence: float = Field(default=1.0, description="Baseline quality score (0-1)")
    
    # Recording conditions
    load_condition: LoadCondition = Field(default=LoadCondition.NORMAL)
    temperature_celsius: Optional[float] = None
    location: Optional[str] = None
    
    # Status
    status: BaselineStatus = Field(default=BaselineStatus.ACTIVE)
    is_active: bool = Field(default=True)
    
    # Metadata
    notes: str = Field(default="")
    created_by: str = Field(default="system")
    
    # Reference to previous baseline (if updated)
    previous_baseline_id: Optional[str] = None
    update_reason: Optional[str] = None  # e.g., "post_maintenance", "degradation_reset"
    
    class Settings:
        name = "tractor_baselines"
        indexes = [
            "tractor_id",
            [("tractor_id", 1), ("is_active", -1)],  # Find active baseline
            "created_at"
        ]


class AudioTrend(Document):
    """
    Track audio changes over time for a tractor
    Each prediction creates a trend point
    """
    tractor_id: str = Field(..., description="Tractor identifier")
    
    # Time tracking
    recorded_at: datetime = Field(default_factory=datetime.utcnow)
    tractor_hours: float = Field(..., description="Engine hours at recording")
    
    # Scores
    resnet_score: float = Field(..., description="ResNet anomaly probability (0-1)")
    deviation_score: float = Field(..., description="Deviation from baseline (std deviations)")
    combined_score: float = Field(..., description="Weighted combination of both scores")
    
    # Classification
    status: TrendStatus = Field(..., description="Health status classification")
    anomaly_type: Optional[str] = None  # minor_anomaly, unusual_noise, etc.
    
    # References
    baseline_id: str = Field(..., description="Which baseline was used")
    prediction_id: str = Field(..., description="Link to AudioPrediction")
    
    # Comparison data
    deviation_percentage: float = Field(default=0.0, description="% of features that are anomalous")
    max_deviation: float = Field(default=0.0, description="Maximum single feature deviation")
    
    class Settings:
        name = "audio_trends"
        indexes = [
            "tractor_id",
            [("tractor_id", 1), ("tractor_hours", 1)],  # For trend analysis
            "recorded_at",
            "status"
        ]


class BaselineMetadata(Document):
    """
    Metadata about baseline establishment process
    Tracks the collection of samples for a baseline
    """
    tractor_id: str
    baseline_id: Optional[str] = None  # Set when baseline is finalized
    
    # Collection status
    target_samples: int = Field(default=5, description="Target number of samples")
    collected_samples: int = Field(default=0)
    sample_files: List[str] = Field(default_factory=list)
    
    # Collection period
    started_at: datetime = Field(default_factory=datetime.utcnow)
    completed_at: Optional[datetime] = None
    
    # Instructions for user
    instructions: str = Field(
        default="Record tractor audio when: 1) Engine warmed up, 2) Normal operating conditions, 3) No unusual sounds"
    )
    
    status: BaselineStatus = Field(default=BaselineStatus.ESTABLISHING)
    
    class Settings:
        name = "baseline_metadata"
        indexes = ["tractor_id", "status"]


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
        TractorBaseline,        # NEW: Baseline model
        AudioTrend,             # NEW: Trend tracking
        BaselineMetadata,       # NEW: Baseline metadata
    ]