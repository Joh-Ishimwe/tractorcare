from fastapi import FastAPI, File, UploadFile, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from datetime import datetime

from app.database import connect_to_mongo, close_mongo_connection, get_database
from app.models import (
    PredictionResponse, 
    BaselineRequest, 
    BaselineResponse,
    FeedbackRequest, 
    FeedbackResponse,
    HistoryResponse
)
from app.audio_processing import extract_mfcc
from app.prediction import vgg_predictor
from app.baseline import (
    get_or_create_baseline,
    update_baseline,
    calculate_drift_score,
    determine_status
)

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    await connect_to_mongo()
    vgg_predictor.load_model()
    yield
    # Shutdown
    await close_mongo_connection()

app = FastAPI(
    title="TractorCare API",
    description="AI-powered predictive maintenance for tractors using audio analysis",
    version="1.0.0",
    lifespan=lifespan
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
async def root():
    """Root endpoint - API health check"""
    return {
        "message": "TractorCare API is running",
        "version": "1.0.0",
        "status": "healthy"
    }

@app.post("/api/predict-audio", response_model=PredictionResponse)
async def predict_audio(
    tractor_id: str,
    audio: UploadFile = File(...),
    db = Depends(get_database)
):
    """
    Predict tractor engine health from audio recording
    
    - **tractor_id**: Unique identifier for the tractor
    - **audio**: Audio file (WAV, MP3, etc.) - should be ~10 seconds
    
    Returns health status: GOOD, WARNING, or CRITICAL
    """
    try:
        # Read audio file
        audio_bytes = await audio.read()
        
        # Basic size check
        file_size_mb = len(audio_bytes) / (1024 * 1024)
        if file_size_mb > 50:
            raise HTTPException(
                status_code=400, 
                detail="Audio file too large (max 50 MB)"
            )
        
        # Extract MFCC features (includes validation)
        mfcc_features = extract_mfcc(audio_bytes)
        
        # Get prediction from model
        global_score = vgg_predictor.predict(mfcc_features)
        
        # Get or update baseline
        baseline_features = await get_or_create_baseline(db, tractor_id)
        
        # Calculate drift score if baseline exists
        drift_score = None
        if baseline_features is not None:
            drift_score = calculate_drift_score(mfcc_features, baseline_features)
        else:
            # Add to baseline (first 5 recordings)
            await update_baseline(db, tractor_id, mfcc_features)
        
        # Determine status and recommendation
        status, message, recommendation = determine_status(global_score, drift_score)
        
        # Save prediction to database
        prediction_record = {
            "tractor_id": tractor_id,
            "timestamp": datetime.utcnow(),
            "global_score": global_score,
            "drift_score": drift_score,
            "status": status,
            "message": message,
            "recommendation": recommendation,
            "mfcc_features": mfcc_features.flatten().tolist()
        }
        
        await db.predictions.insert_one(prediction_record)
        
        return PredictionResponse(
            tractor_id=tractor_id,
            timestamp=datetime.utcnow(),
            global_score=global_score,
            drift_score=drift_score,
            status=status,
            message=message,
            recommendation=recommendation
        )
    
    except ValueError as e:
        # Validation errors from extract_mfcc
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        import traceback
        print(f"❌ Error in predict_audio: {str(e)}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Prediction failed: {str(e)}")

@app.post("/api/register-tractor", response_model=BaselineResponse)
async def register_tractor(
    request: BaselineRequest,
    db = Depends(get_database)
):
    """Register a new tractor to start baseline tracking"""
    existing = await db.tractors.find_one({"_id": request.tractor_id})
    
    if existing:
        return BaselineResponse(
            message="Tractor already registered",
            tractor_id=request.tractor_id,
            baseline_established=existing.get("baseline", {}).get("established", False),
            recordings_needed=max(0, 5 - existing.get("baseline", {}).get("recording_count", 0))
        )
    
    await db.tractors.insert_one({
        "_id": request.tractor_id,
        "model": request.model,
        "registration": request.registration,
        "baseline": {
            "established": False,
            "recording_count": 0
        },
        "created_at": datetime.utcnow()
    })
    
    return BaselineResponse(
        message="Tractor registered. Record 5 engine sounds to establish baseline.",
        tractor_id=request.tractor_id,
        baseline_established=False,
        recordings_needed=5
    )

@app.get("/api/history/{tractor_id}", response_model=HistoryResponse)
async def get_history(tractor_id: str, db = Depends(get_database)):
    """Get prediction history for a tractor"""
    predictions = await db.predictions.find(
        {"tractor_id": tractor_id}
    ).sort("timestamp", -1).limit(50).to_list(length=50)
    
    # Convert ObjectId to string
    for pred in predictions:
        pred["_id"] = str(pred["_id"])
    
    return HistoryResponse(
        tractor_id=tractor_id,
        history=predictions,
        count=len(predictions)
    )

@app.post("/api/feedback", response_model=FeedbackResponse)
async def submit_feedback(request: FeedbackRequest, db = Depends(get_database)):
    """Submit feedback on a prediction"""
    await db.feedback.insert_one({
        "recording_id": request.recording_id,
        "tractor_id": request.tractor_id,
        "was_correct": request.was_correct,
        "user_notes": request.user_notes,
        "timestamp": datetime.utcnow()
    })
    
    return FeedbackResponse(
        message="Feedback received. Thank you for helping improve TractorCare!"
    )