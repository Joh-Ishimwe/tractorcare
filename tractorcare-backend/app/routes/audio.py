"""
Audio prediction routes with baseline integration
Complete file for: app/routes/audio.py
FIXED: Corrected schema imports
"""

from fastapi import APIRouter, UploadFile, File, Depends, HTTPException, status, Query
from typing import Optional, List
import os
from datetime import datetime, timedelta
from pathlib import Path
import time
import logging
import librosa
import numpy as np

from app.models import User, Tractor, AudioPrediction, MaintenanceAlert, AlertType, MaintenancePriority, MaintenanceStatus
from app.core.security import get_current_user

# ===== FIXED IMPORT - Use your actual schemas location =====
# If you have app/schemas.py (single file):
from app.schemas import AudioPredictionResponse, AudioPredictionListResponse

# OR if you have app/schemas/audio.py (separate files):
# from app.schemas.audio import AudioPredictionResponse, AudioPredictionListResponse

from app.services.ml_service import ml_service

# ===== ROUTER DEFINITION =====
router = APIRouter()

logger = logging.getLogger(__name__)

# Create upload directory
UPLOAD_DIR = Path("uploads/audio")
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

# Supported audio formats
SUPPORTED_FORMATS = {'.wav', '.flac', '.mp3', '.ogg', '.m4a'}


@router.post("/upload", response_model=AudioPredictionResponse)
async def upload_audio(
    tractor_id: str = Query(..., description="Tractor ID"),
    file: UploadFile = File(..., description="Audio file (.wav, .flac, .mp3, .ogg, .m4a)"),
    tractor_hours: Optional[float] = Query(None, description="Current tractor hours"),
    current_user: User = Depends(get_current_user)
):
    """
    Upload audio file and get tractor health prediction with baseline comparison
    
    **New:** If baseline exists, compares against tractor-specific baseline
    **Supported formats:** .wav, .flac, .mp3, .ogg, .m4a
    
    The model analyzes audio patterns to detect:
    - Normal operation
    - Minor anomalies (0.5-0.6)
    - Unusual noise (0.6-0.75)
    - High vibration (0.75-0.9)
    - Critical anomalies (>0.9)
    
    **With Baseline:** Gets personalized analysis comparing to THIS tractor's normal sound
    **Without Baseline:** Uses general ResNet model only
    """
    
    start_time = time.time()
    
    try:
        # Verify tractor
        tractor = await Tractor.find_one({
            "tractor_id": tractor_id.upper(),
            "owner_id": str(current_user.id)
        })
        
        if not tractor:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Tractor {tractor_id} not found"
            )
        
        # Use tractor hours from query or database
        current_hours = tractor_hours if tractor_hours is not None else tractor.engine_hours
        
        # Validate audio format
        file_ext = os.path.splitext(file.filename)[1].lower()
        
        if file_ext not in SUPPORTED_FORMATS:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Audio format '{file_ext}' not supported. Please use one of: {', '.join(sorted(SUPPORTED_FORMATS))}"
            )
        
        # Save file
        timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        filename = f"{tractor_id}_{timestamp}{file_ext}"
        file_path = UPLOAD_DIR / filename
        
        logger.info(f"📁 Saving audio file: {filename}")
        content = await file.read()
        with open(file_path, "wb") as f:
            f.write(content)
        
        # Get file info
        file_size = len(content)
        logger.info(f"📊 File size: {file_size / 1024:.2f} KB")
        
        # Get audio metadata
        try:
            y, sr = librosa.load(str(file_path), duration=None)
            duration = float(len(y) / sr)
            sample_rate = int(sr)
            logger.info(f"🎵 Audio: {duration:.2f}s @ {sample_rate}Hz")
        except Exception as e:
            logger.warning(f"⚠️  Could not read audio metadata: {e}")
            duration = 10.0
            sample_rate = 16000
        
        # ===== NEW: Check for baseline =====
        try:
            from app.services.baseline_service import baseline_service
            from app.models import TractorBaseline, AudioTrend
            
            baseline = await baseline_service.get_active_baseline(
                tractor_id.upper(),
                TractorBaseline
            )
            
            has_baseline = baseline is not None
            
            if has_baseline:
                logger.info(f"✅ Using baseline (created at {baseline.tractor_hours}h)")
            else:
                logger.info(f"ℹ️  No baseline - using ResNet only")
        except ImportError:
            logger.warning("⚠️  Baseline service not available, using ResNet only")
            has_baseline = False
            baseline = None
        
        # Make prediction using ResNet transfer learning
        logger.info(f"🤖 Running ResNet CNN prediction for tractor: {tractor_id}")
        prediction_start = time.time()
        
        prediction_result = await ml_service.predict_audio(
            audio_path=str(file_path),
            tractor_id=tractor_id.upper()
        )
        
        processing_time = (time.time() - prediction_start) * 1000  # Convert to ms
        
        # ===== NEW: If baseline exists, calculate deviation =====
        deviation_info = None
        combined_analysis = None
        
        if has_baseline and baseline:
            try:
                # Extract MFCC from new audio
                new_mfcc = baseline_service.extract_mfcc_features(str(file_path))
                
                # Get baseline arrays
                baseline_mean = np.array(baseline.baseline_mean)
                baseline_std = np.array(baseline.baseline_std)
                
                # Calculate deviation
                deviation_info = baseline_service.calculate_deviation(
                    new_mfcc,
                    baseline_mean,
                    baseline_std
                )
                
                # Combine scores
                combined_analysis = baseline_service.combine_scores(
                    resnet_score=prediction_result["anomaly_score"],
                    deviation_score=deviation_info["average_deviation"]
                )
                
                logger.info(f"📊 Baseline comparison: {deviation_info['average_deviation']:.2f}σ deviation")
                logger.info(f"🎯 Combined status: {combined_analysis['status']}")
                
            except Exception as e:
                logger.error(f"❌ Error in baseline comparison: {e}")
                # Continue with ResNet-only prediction
                has_baseline = False
        
        # Determine final values
        if has_baseline and combined_analysis:
            # Use combined analysis
            final_class = combined_analysis["status"]
            final_confidence = combined_analysis["combined_score"]
            final_anomaly_score = combined_analysis["combined_score"]
            final_model = "ResNet_with_Baseline"
        else:
            # Use ResNet only
            final_class = prediction_result["prediction_class"].lower()
            final_confidence = prediction_result["confidence"]
            final_anomaly_score = prediction_result.get("anomaly_score", 0.0)
            final_model = "ResNet_Transfer_Learning"
        
        # Map status to prediction_class (normal/abnormal)
        if final_class in ["normal"]:
            prediction_class = "normal"
        else:
            prediction_class = "abnormal"
        
        # Create prediction record
        audio_prediction = AudioPrediction(
            tractor_id=tractor_id.upper(),
            # File info
            filename=filename,
            file_path=str(file_path),
            file_size_bytes=file_size,
            duration_seconds=duration,
            # Prediction
            prediction_class=prediction_class,
            confidence=final_confidence,
            ml_model=final_model,
            # Analysis metadata
            processing_time_ms=processing_time,
            sample_rate=sample_rate,
            # Timestamps
            recorded_at=datetime.utcnow(),
            processed_at=datetime.utcnow()
        )
        
        await audio_prediction.insert()
        prediction_id = str(audio_prediction.id)
        
        # ===== AUTO-CREATE MAINTENANCE ALERT FOR ABNORMAL SOUNDS =====
        if prediction_class == "abnormal" and final_confidence >= 0.85:
            try:
                # Check if we already have a recent alert for this tractor
                existing_alert = await MaintenanceAlert.find_one({
                    "tractor_id": tractor_id.upper(),
                    "alert_type": AlertType.AUDIO_ANOMALY,
                    "status": MaintenanceStatus.PENDING,
                    "created_at": {"$gte": datetime.utcnow() - timedelta(hours=24)}
                })
                
                if not existing_alert:
                    # Create maintenance alert for abnormal sound
                    maintenance_alert = MaintenanceAlert(
                        tractor_id=tractor_id.upper(),
                        alert_type=AlertType.AUDIO_ANOMALY,
                        priority=MaintenancePriority.HIGH,
                        status=MaintenanceStatus.PENDING,
                        
                        # Task details
                        task_name="Sound Analysis Inspection",
                        description=f"Inspection required due to abnormal sound detection. Confidence: {final_confidence:.1%}",
                        estimated_time_minutes=30,
                        source="AI_Sound_Analysis",
                        
                        # Timing
                        due_date=datetime.utcnow() + timedelta(days=1),  # Due tomorrow
                        created_at=datetime.utcnow(),
                        
                        # Audio anomaly specific
                        audio_anomaly_score=final_confidence,
                        related_prediction_id=prediction_id
                    )
                    
                    await maintenance_alert.insert()
                    logger.info(f"🚨 Maintenance alert created for abnormal sound (confidence: {final_confidence:.1%})")
                else:
                    logger.info(f"⏭️ Maintenance alert already exists for recent abnormal sound")
                    
            except Exception as e:
                logger.error(f"❌ Failed to create maintenance alert: {e}")
        
        # ===== NEW: Save trend data if baseline exists =====
        if has_baseline and deviation_info and combined_analysis:
            try:
                trend = AudioTrend(
                    tractor_id=tractor_id.upper(),
                    recorded_at=datetime.utcnow(),
                    tractor_hours=current_hours,
                    resnet_score=float(prediction_result["anomaly_score"]),
                    deviation_score=float(deviation_info["average_deviation"]),
                    combined_score=float(combined_analysis["combined_score"]),
                    status=combined_analysis["status"],
                    anomaly_type=prediction_result.get("anomaly_type"),
                    baseline_id=str(baseline.id),
                    prediction_id=prediction_id,
                    deviation_percentage=float(deviation_info["percentage_anomalous"]),
                    max_deviation=float(deviation_info["max_deviation"])
                )
                await trend.insert()
                logger.info(f"📈 Trend data saved")
            except Exception as e:
                logger.error(f"⚠️  Could not save trend data: {e}")
        
        # Log result
        if has_baseline and deviation_info:
            logger.info(
                f"✅ Prediction saved: {prediction_class} "
                f"(combined: {final_confidence:.2%}, "
                f"deviation: {deviation_info['average_deviation']:.2f}σ, "
                f"{processing_time:.0f}ms)"
            )
        else:
            logger.info(
                f"✅ Prediction saved: {prediction_class} "
                f"(ResNet only: {final_confidence:.2%}, {processing_time:.0f}ms)"
            )
        
        # Build response
        response_data = {
            "id": prediction_id,
            "tractor_id": audio_prediction.tractor_id,
            "prediction_class": audio_prediction.prediction_class,
            "confidence": audio_prediction.confidence,
            "anomaly_score": final_anomaly_score,
            "file_path": audio_prediction.file_path,  # ← Changed from audio_file_path
            "recorded_at": audio_prediction.recorded_at,
            "filename": audio_prediction.filename,
            "ml_model": audio_prediction.ml_model,
            "duration_seconds": audio_prediction.duration_seconds
        }
        
        # Add baseline comparison info if available
        if has_baseline and deviation_info and combined_analysis:
            response_data["baseline_comparison"] = {
                "has_baseline": True,
                "baseline_id": str(baseline.id),
                "baseline_hours": baseline.tractor_hours,
                "current_hours": current_hours,
                "hours_since_baseline": current_hours - baseline.tractor_hours,
                "deviation_score": deviation_info["average_deviation"],
                "deviation_interpretation": f"{deviation_info['average_deviation']:.1f}σ from baseline",
                "percentage_anomalous": deviation_info["percentage_anomalous"],
                "combined_status": combined_analysis["status"],
                "recommendation": combined_analysis["recommendation"]
            }
        else:
            response_data["baseline_comparison"] = {
                "has_baseline": False,
                "message": "Create baseline to enable personalized analysis"
            }
        
        return AudioPredictionResponse(**response_data)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Error processing audio: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error processing audio: {str(e)}"
        )


@router.get("/{tractor_id}/predictions", response_model=AudioPredictionListResponse)
async def get_predictions(
    tractor_id: str,
    limit: int = Query(50, ge=1, le=100),
    skip: int = Query(0, ge=0),
    current_user: User = Depends(get_current_user)
):
    """Get all audio predictions for a tractor"""
    try:
        tractor = await Tractor.find_one({
            "tractor_id": tractor_id.upper(),
            "owner_id": str(current_user.id)
        })
        
        if not tractor:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Tractor {tractor_id} not found"
            )
        
        predictions = await AudioPrediction.find({
            "tractor_id": tractor_id.upper()
        }).sort("-recorded_at").skip(skip).limit(limit).to_list()
        
        total = await AudioPrediction.find({
            "tractor_id": tractor_id.upper()
        }).count()
        
        # Convert predictions to proper format
        prediction_responses = []
        for pred in predictions:
            prediction_responses.append(AudioPredictionResponse(
                id=str(pred.id),  # ← Convert ObjectId to string
                tractor_id=pred.tractor_id,
                filename=pred.filename,
                prediction_class=pred.prediction_class,
                confidence=pred.confidence,
                anomaly_score=pred.anomaly_score,
                file_path=pred.file_path,  # ← Use file_path not audio_file_path
                recorded_at=pred.recorded_at,
                ml_model=pred.ml_model,
                duration_seconds=pred.duration_seconds,
                baseline_comparison=None  # Add if available
            ))
        
        return AudioPredictionListResponse(
            predictions=prediction_responses,
            total=total,
            skip=skip,
            limit=limit
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting predictions: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{tractor_id}/predictions/{prediction_id}", response_model=AudioPredictionResponse)
async def get_prediction(
    tractor_id: str,
    prediction_id: str,
    current_user: User = Depends(get_current_user)
):
    """Get a specific prediction by ID"""
    try:
        tractor = await Tractor.find_one({
            "tractor_id": tractor_id.upper(),
            "owner_id": str(current_user.id)
        })
        
        if not tractor:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Tractor {tractor_id} not found"
            )
        
        prediction = await AudioPrediction.get(prediction_id)
        
        if not prediction or prediction.tractor_id != tractor_id.upper():
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Prediction not found"
            )
        
        # Return with proper format
        return AudioPredictionResponse(
            id=str(prediction.id),  # ← Convert ObjectId to string
            tractor_id=prediction.tractor_id,
            filename=prediction.filename,
            prediction_class=prediction.prediction_class,
            confidence=prediction.confidence,
            anomaly_score=prediction.anomaly_score,
            file_path=prediction.file_path,  # ← Use file_path not audio_file_path
            recorded_at=prediction.recorded_at,
            ml_model=prediction.ml_model,
            duration_seconds=prediction.duration_seconds,
            baseline_comparison=None  # Add if available
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting prediction: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/{tractor_id}/predictions/{prediction_id}")
async def delete_prediction(
    tractor_id: str,
    prediction_id: str,
    current_user: User = Depends(get_current_user)
):
    """Delete a prediction"""
    try:
        # Verify tractor ownership
        tractor = await Tractor.find_one({
            "tractor_id": tractor_id.upper(),
            "owner_id": str(current_user.id)
        })
        
        if not tractor:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Tractor {tractor_id} not found"
            )
        
        # Get and delete prediction
        prediction = await AudioPrediction.get(prediction_id)
        
        if not prediction or prediction.tractor_id != tractor_id.upper():
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Prediction not found"
            )
        
        # Delete audio file if exists
        if prediction.file_path and os.path.exists(prediction.file_path):
            os.remove(prediction.file_path)
        
        await prediction.delete()
        
        return {"message": "Prediction deleted successfully"}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting prediction: {e}")
        raise HTTPException(status_code=500, detail=str(e))