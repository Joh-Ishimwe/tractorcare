from pydantic import BaseModel
from datetime import datetime
from typing import Optional

class AudioPredictionResponse(BaseModel):
    id: str
    tractor_id: str
    prediction_class: str
    confidence: float
    anomaly_score: float
    audio_file_path: str
    recorded_at: datetime
    
    # Make these optional
    filename: Optional[str] = None
    model_used: Optional[str] = None
    duration_seconds: Optional[float] = None
    
    class Config:
        json_schema_extra = {
            "example": {
                "id": "67890abcdef",
                "tractor_id": "T001",
                "prediction_class": "Normal",
                "confidence": 0.989,
                "anomaly_score": 0.011,
                "audio_file_path": "uploads/audio/T001_20251024_120000.wav",
                "recorded_at": "2025-10-24T12:00:00.000Z"
            }
        }