"""
Public Demo Routes - No Authentication Required
For website visitors to test the model
File: app/routes/demo.py
"""

from fastapi import APIRouter, UploadFile, File, HTTPException, status
import os
from datetime import datetime
from pathlib import Path
import time
import logging
import librosa
import uuid

from app.services.ml_service import ml_service

router = APIRouter()
logger = logging.getLogger(__name__)

# Create demo upload directory
DEMO_DIR = Path("uploads/demo")
DEMO_DIR.mkdir(parents=True, exist_ok=True)

# Supported audio formats
SUPPORTED_FORMATS = {'.wav', '.flac', '.mp3', '.ogg'}


@router.post("/quick-test")
async def quick_test_audio(
    file: UploadFile = File(..., description="Audio file (.wav, .flac, .mp3, .ogg)")
):
    """
    🎯 PUBLIC DEMO ENDPOINT - No authentication required
    
    Test the tractor audio anomaly detection model without signing up.
    
    **Perfect for:**
    - Website visitors trying the product
    - Quick model testing
    
    **Limitations:**
    - No baseline comparison (uses ResNet only)
    - No history tracking
    - Files deleted after analysis
    
    **Supported formats:** .wav, .flac, .mp3, .ogg
    """
    
    start_time = time.time()
    
    try:
        # Validate file format
        file_ext = os.path.splitext(file.filename)[1].lower()
        
        if file_ext not in SUPPORTED_FORMATS:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Audio format '{file_ext}' not supported. Please use: {', '.join(sorted(SUPPORTED_FORMATS))}"
            )
        
        # Check file size (max 10MB for demo)
        content = await file.read()
        file_size = len(content)
        
        if file_size > 10 * 1024 * 1024:  # 10MB
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="File too large. Maximum size: 10MB"
            )
        
        # Save file with unique ID
        demo_id = str(uuid.uuid4())[:8]
        timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        filename = f"demo_{timestamp}_{demo_id}{file_ext}"
        file_path = DEMO_DIR / filename
        
        logger.info(f"📁 Demo upload: {filename} ({file_size / 1024:.2f} KB)")
        
        with open(file_path, "wb") as f:
            f.write(content)
        
        # Get audio metadata
        try:
            y, sr = librosa.load(str(file_path), duration=None)
            duration = float(len(y) / sr)
            sample_rate = int(sr)
            
            if duration > 30.0:
                logger.warning(f"⚠️  Audio too long: {duration:.1f}s, using first 30s")
                duration = 30.0
            
            logger.info(f"🎵 Audio: {duration:.2f}s @ {sample_rate}Hz")
        except Exception as e:
            logger.warning(f"⚠️  Could not read audio metadata: {e}")
            duration = 10.0
            sample_rate = 16000
        
        # Make prediction
        logger.info("🤖 Running demo prediction...")
        prediction_start = time.time()
        
        prediction_result = await ml_service.predict_audio(
            audio_path=str(file_path),
            tractor_id="DEMO"
        )
        
        processing_time = (time.time() - prediction_start) * 1000
        total_time = (time.time() - start_time) * 1000
        
        # Clean up file immediately
        try:
            os.remove(file_path)
            logger.info(f"🗑️  Cleaned up demo file: {filename}")
        except Exception as e:
            logger.warning(f"⚠️  Could not delete demo file: {e}")
        
        # Get prediction details
        prediction_class = prediction_result["prediction_class"].lower()
        confidence = prediction_result["confidence"]
        anomaly_score = prediction_result.get("anomaly_score", 0.0)
        anomaly_type = prediction_result.get("anomaly_type", "unknown")
        
        # Create user-friendly interpretation
        if prediction_class == "normal":
            interpretation = "✅ Sound appears normal"
            recommendation = "No immediate concerns detected in the audio"
            severity = "low"
        elif anomaly_score < 0.6:
            interpretation = "⚠️ Minor irregularity detected"
            recommendation = "Monitor the equipment, but no urgent action needed"
            severity = "low"
        elif anomaly_score < 0.75:
            interpretation = "⚠️ Unusual sound pattern detected"
            recommendation = "Consider scheduling an inspection"
            severity = "medium"
        elif anomaly_score < 0.9:
            interpretation = "🔴 High vibration or unusual noise detected"
            recommendation = "Schedule maintenance soon"
            severity = "high"
        else:
            interpretation = "🔴 Critical anomaly detected"
            recommendation = "Immediate inspection recommended"
            severity = "critical"
        
        # Log result
        logger.info(
            f"✅ Demo prediction: {prediction_class} "
            f"(confidence: {confidence:.2%}, "
            f"processing: {processing_time:.0f}ms)"
        )
        
        # Return comprehensive demo response
        return {
            "success": True,
            
            "prediction": {
                "class": prediction_class,
                "confidence": round(confidence, 4),
                "anomaly_score": round(anomaly_score, 4),
                "anomaly_type": anomaly_type
            },
            
            "interpretation": {
                "message": interpretation,
                "recommendation": recommendation,
                "severity": severity
            },
            
            "audio_info": {
                "duration_seconds": round(duration, 2),
                "sample_rate": sample_rate,
                "file_size_kb": round(file_size / 1024, 2)
            },
            
            "message": "This is a demo prediction using General model only. Sign up to get personalized baseline analysis for YOUR specific tractor!",
            
            "features_with_account": [
                "Create baseline from YOUR tractor's normal sound",
                "Get personalized anomaly detection",
                "Track audio changes over time",
                "Maintenance scheduling and alerts",
                "Full history and trend analysis"
            ]
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Demo prediction error: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error processing audio. Please try again with a different file."
        )