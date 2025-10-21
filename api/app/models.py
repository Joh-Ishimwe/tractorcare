from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime

class PredictionRequest(BaseModel):
    """Request schema for audio prediction"""
    tractor_id: str = Field(..., description="Unique tractor identifier")

class PredictionResponse(BaseModel):
    """Response schema for prediction results"""
    tractor_id: str
    timestamp: datetime
    global_score: float = Field(..., description="Normality score from VGG model (0-100)")
    drift_score: Optional[float] = Field(None, description="Similarity to baseline (0-1)")
    status: str = Field(..., description="GOOD, WARNING, or CRITICAL")
    message: str = Field(..., description="Human-readable status message")
    recommendation: str = Field(..., description="Recommended action")
    
    model_config = {
        "json_schema_extra": {
            "example": {
                "tractor_id": "tractor_001",
                "timestamp": "2025-09-25T10:30:00",
                "global_score": 85.5,
                "drift_score": 0.92,
                "status": "GOOD",
                "message": "Engine sounds normal (85.5% confidence, 0.92 similarity to baseline)",
                "recommendation": "✅ Tractor is operating within expected parameters"
            }
        }
    }

class BaselineRequest(BaseModel):
    """Request schema for establishing tractor baseline"""
    tractor_id: str = Field(..., description="Unique tractor identifier")
    model: str = Field(..., description="Tractor model (e.g., 'MF 240', 'MF 375')")
    registration: Optional[str] = Field(None, description="Tractor registration number")
    
    model_config = {
        "json_schema_extra": {
            "example": {
                "tractor_id": "tractor_001",
                "model": "MF 240",
                "registration": "RAC-123"
            }
        }
    }

class BaselineResponse(BaseModel):
    """Response schema for baseline establishment"""
    message: str
    tractor_id: str
    baseline_established: bool = False
    recordings_needed: int = 0
    
    model_config = {
        "json_schema_extra": {
            "example": {
                "message": "Tractor registered. Record 5 engine sounds to establish baseline.",
                "tractor_id": "tractor_001",
                "baseline_established": False,
                "recordings_needed": 5
            }
        }
    }

class FeedbackRequest(BaseModel):
    """Request schema for user feedback on predictions"""
    recording_id: str = Field(..., description="ID of the prediction record")
    tractor_id: str = Field(..., description="Tractor identifier")
    was_correct: bool = Field(..., description="Was the prediction accurate?")
    user_notes: Optional[str] = Field(None, description="Additional notes from user")
    
    model_config = {
        "json_schema_extra": {
            "example": {
                "recording_id": "pred_12345",
                "tractor_id": "tractor_001",
                "was_correct": False,
                "user_notes": "Model said WARNING but mechanic confirmed engine is fine"
            }
        }
    }

class FeedbackResponse(BaseModel):
    """Response schema for feedback submission"""
    message: str
    
    model_config = {
        "json_schema_extra": {
            "example": {
                "message": "Feedback received. Thank you for helping improve TractorCare!"
            }
        }
    }

class HistoryRecord(BaseModel):
    """Schema for a single history record"""
    id: str = Field(..., alias="_id")
    tractor_id: str
    timestamp: datetime
    global_score: float
    drift_score: Optional[float]
    status: str
    message: str
    recommendation: str
    
    model_config = {
        "populate_by_name": True,
        "json_schema_extra": {
            "example": {
                "_id": "pred_12345",
                "tractor_id": "tractor_001",
                "timestamp": "2025-09-25T10:30:00",
                "global_score": 85.5,
                "drift_score": 0.92,
                "status": "GOOD",
                "message": "Engine sounds normal",
                "recommendation": "Continue regular maintenance"
            }
        }
    }

class HistoryResponse(BaseModel):
    """Response schema for history endpoint"""
    tractor_id: str
    history: List[dict]
    count: int
    
    model_config = {
        "json_schema_extra": {
            "example": {
                "tractor_id": "tractor_001",
                "count": 5,
                "history": [
                    {
                        "_id": "pred_001",
                        "timestamp": "2025-09-25T10:30:00",
                        "global_score": 85.5,
                        "status": "GOOD"
                    }
                ]
            }
        }
    }

class HealthCheckResponse(BaseModel):
    """Response schema for health check endpoint"""
    status: str
    timestamp: datetime
    database_connected: bool = True
    ml_model_loaded: bool = True
    
    model_config = {
        "protected_namespaces": (),
        "json_schema_extra": {
            "example": {
                "status": "healthy",
                "timestamp": "2025-09-25T10:30:00",
                "database_connected": True,
                "ml_model_loaded": True
            }
        }
    }