from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    # MongoDB
    MONGODB_URL: str
    DATABASE_NAME: str = "tractorcare_db"
    
    # Model path - MUST be the .h5 file
    MODEL_PATH: str = "models/best_vgg_model.h5"  # ← Changed from .keras to .h5
    
    # Audio preprocessing (MUST match training)
    SAMPLE_RATE: int = 16000
    AUDIO_DURATION: float = 10.0
    MFCC_FEATURES: int = 40
    MAX_TIME_FRAMES: int = 100
    
    # High-pass filter
    HIGHPASS_CUTOFF: float = 100.0
    FILTER_ORDER: int = 5
    
    class Config:
        env_file = ".env"

settings = Settings()