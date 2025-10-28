"""
Core Configuration
Handles environment variables and settings
"""

from pydantic_settings import BaseSettings
from typing import List, Optional
from functools import lru_cache


class Settings(BaseSettings):
    """Application settings from environment variables"""
    
    # MongoDB
    MONGO_URL: str
    DATABASE_NAME: str = "tractorcare_db"
    
    # API Configuration
    API_VERSION: str = "v1"
    API_TITLE: str = "TractorCare API"
    API_DESCRIPTION: str = "Predictive Maintenance System for Tractors"
    DEBUG: bool = True
    
    # Security
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 43200  # 30 days
    
    # CORS
    ALLOWED_ORIGINS: str = "http://localhost:3000,http://localhost:8080"
    
    @property
    def allowed_origins_list(self) -> List[str]:
        return [origin.strip() for origin in self.ALLOWED_ORIGINS.split(",")]
    
    # File Upload
    MAX_AUDIO_SIZE_MB: int = 10
    ALLOWED_AUDIO_FORMATS: str = ".wav,.mp3,.m4a,.aac"
    
    @property
    def allowed_formats_list(self) -> List[str]:
        return [fmt.strip() for fmt in self.ALLOWED_AUDIO_FORMATS.split(",")]
    
    @property
    def max_audio_size_bytes(self) -> int:
        return self.MAX_AUDIO_SIZE_MB * 1024 * 1024
    
    # Audio Processing
    SAMPLE_RATE: int = 22050
    AUDIO_DURATION_SECONDS: int = 10
    
    # ML Models
    ML_MODEL_API_URL: str = "http://localhost:5000"
    ML_MODEL_TIMEOUT: int = 30
    MODEL_GDRIVE_ID: Optional[str] = None  # Google Drive ID for model download
    ML_MODEL_PATH: Optional[str] = None    # Local path to saved model
    
    # Logging
    LOG_LEVEL: str = "INFO"
    LOG_FILE: str = "tractorcare.log"
    
    # Environment
    ENVIRONMENT: str = "development"
    
    class Config:
        env_file = ".env"
        case_sensitive = True


@lru_cache()
def get_settings() -> Settings:
    """Get cached settings instance"""
    return Settings()


# Maintenance schedules data source
# This would typically be in a separate file or database
MAINTENANCE_SCHEDULES = {
    "MF_240": {
        "model": "MF_240",
        "make": "Massey Ferguson",
        "source": "Massey Ferguson MF 240 Operator Manual",
        "tasks": [
            {
                "task_name": "engine_oil_change",
                "description": "Engine oil and filter change",
                "priority": "high",
                "interval_hours": 250,
                "interval_days": 180,
                "estimated_time_minutes": 45,
                "source": "MF 240 Manual, Section 7.2"
            },
            {
                "task_name": "air_filter_check",
                "description": "Air filter inspection and cleaning",
                "priority": "medium",
                "interval_hours": 100,
                "interval_days": 60,
                "estimated_time_minutes": 20,
                "source": "MF 240 Manual, Section 7.3"
            },
            {
                "task_name": "air_filter_replace",
                "description": "Air filter replacement",
                "priority": "medium",
                "interval_hours": 500,
                "interval_days": 365,
                "estimated_time_minutes": 30,
                "source": "MF 240 Manual, Section 7.3"
            },
            {
                "task_name": "fuel_filter_replace",
                "description": "Fuel filter replacement",
                "priority": "high",
                "interval_hours": 300,
                "interval_days": 180,
                "estimated_time_minutes": 30,
                "source": "MF 240 Manual, Section 7.4"
            },
            {
                "task_name": "hydraulic_oil_change",
                "description": "Hydraulic oil and filter change",
                "priority": "high",
                "interval_hours": 600,
                "interval_days": 365,
                "estimated_time_minutes": 60,
                "source": "MF 240 Manual, Section 7.5"
            },
            {
                "task_name": "coolant_check",
                "description": "Coolant level check and top-up",
                "priority": "medium",
                "interval_hours": 50,
                "interval_days": 30,
                "estimated_time_minutes": 10,
                "source": "MF 240 Manual, Section 7.6"
            },
            {
                "task_name": "battery_check",
                "description": "Battery terminals and electrolyte check",
                "priority": "medium",
                "interval_hours": 100,
                "interval_days": 60,
                "estimated_time_minutes": 15,
                "source": "MF 240 Manual, Section 7.7"
            },
            {
                "task_name": "belt_inspection",
                "description": "Fan and alternator belt inspection",
                "priority": "medium",
                "interval_hours": 200,
                "interval_days": 120,
                "estimated_time_minutes": 20,
                "source": "MF 240 Manual, Section 7.8"
            },
            {
                "task_name": "tire_pressure_check",
                "description": "Tire pressure inspection and adjustment",
                "priority": "medium",
                "interval_hours": 50,
                "interval_days": 30,
                "estimated_time_minutes": 15,
                "source": "MF 240 Manual, Section 7.9"
            },
            {
                "task_name": "grease_points",
                "description": "Lubricate all grease points",
                "priority": "medium",
                "interval_hours": 50,
                "interval_days": 30,
                "estimated_time_minutes": 30,
                "source": "MF 240 Manual, Section 7.10"
            }
        ]
    },
    "MF_375": {
        "model": "MF_375",
        "make": "Massey Ferguson",
        "source": "Massey Ferguson MF 375 Operator Manual",
        "tasks": [
            {
                "task_name": "engine_oil_change",
                "description": "Engine oil and filter change",
                "priority": "high",
                "interval_hours": 300,
                "interval_days": 180,
                "estimated_time_minutes": 50,
                "source": "MF 375 Manual, Section 8.2"
            },
            {
                "task_name": "air_filter_check",
                "description": "Air filter inspection and cleaning",
                "priority": "medium",
                "interval_hours": 120,
                "interval_days": 60,
                "estimated_time_minutes": 25,
                "source": "MF 375 Manual, Section 8.3"
            },
            {
                "task_name": "air_filter_replace",
                "description": "Air filter replacement",
                "priority": "medium",
                "interval_hours": 600,
                "interval_days": 365,
                "estimated_time_minutes": 35,
                "source": "MF 375 Manual, Section 8.3"
            },
            {
                "task_name": "fuel_filter_replace",
                "description": "Fuel filter replacement",
                "priority": "high",
                "interval_hours": 350,
                "interval_days": 180,
                "estimated_time_minutes": 35,
                "source": "MF 375 Manual, Section 8.4"
            },
            {
                "task_name": "hydraulic_oil_change",
                "description": "Hydraulic oil and filter change",
                "priority": "high",
                "interval_hours": 700,
                "interval_days": 365,
                "estimated_time_minutes": 70,
                "source": "MF 375 Manual, Section 8.5"
            },
            {
                "task_name": "coolant_check",
                "description": "Coolant level check and top-up",
                "priority": "medium",
                "interval_hours": 60,
                "interval_days": 30,
                "estimated_time_minutes": 15,
                "source": "MF 375 Manual, Section 8.6"
            },
            {
                "task_name": "battery_check",
                "description": "Battery terminals and electrolyte check",
                "priority": "medium",
                "interval_hours": 120,
                "interval_days": 60,
                "estimated_time_minutes": 20,
                "source": "MF 375 Manual, Section 8.7"
            },
            {
                "task_name": "belt_inspection",
                "description": "Fan and alternator belt inspection",
                "priority": "medium",
                "interval_hours": 250,
                "interval_days": 120,
                "estimated_time_minutes": 25,
                "source": "MF 375 Manual, Section 8.8"
            },
            {
                "task_name": "tire_pressure_check",
                "description": "Tire pressure inspection and adjustment",
                "priority": "medium",
                "interval_hours": 60,
                "interval_days": 30,
                "estimated_time_minutes": 20,
                "source": "MF 375 Manual, Section 8.9"
            },
            {
                "task_name": "grease_points",
                "description": "Lubricate all grease points",
                "priority": "medium",
                "interval_hours": 60,
                "interval_days": 30,
                "estimated_time_minutes": 35,
                "source": "MF 375 Manual, Section 8.10"
            }
        ]
    }
}

# Audio anomaly to maintenance task mapping
ANOMALY_TASK_MAPPING = {
    "high_vibration": ["belt_inspection", "engine_oil_change"],
    "unusual_noise": ["engine_oil_change", "belt_inspection", "air_filter_check"],
    "knocking_sound": ["engine_oil_change", "fuel_filter_replace"],
    "whining_sound": ["hydraulic_oil_change", "belt_inspection"],
    "overheating": ["coolant_check", "air_filter_check"],
    "grinding_noise": ["belt_inspection", "grease_points"],
}