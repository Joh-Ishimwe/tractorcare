"""
Baseline Management Routes
File: app/routes/baseline.py
"""

from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Query
from typing import Optional
from datetime import datetime
import logging

from app.models import User, Tractor, LoadCondition
from app.core.security import get_current_user
from app.services.baseline_service import baseline_service
from pathlib import Path

router = APIRouter()
logger = logging.getLogger(__name__)

# Upload directory for baseline samples
BASELINE_DIR = Path("uploads/baseline")
BASELINE_DIR.mkdir(parents=True, exist_ok=True)


@router.post("/{tractor_id}/start")
async def start_baseline_collection(
    tractor_id: str,
    target_samples: int = Query(5, ge=3, le=10, description="Number of samples to collect (3-10)"),
    current_user: User = Depends(get_current_user)
):
    """
    Start baseline collection for a tractor
    
    **Steps:**
    1. Call this endpoint to start collection
    2. Upload 3-10 audio samples when tractor is healthy
    3. Finalize baseline when done
    
    **Requirements:**
    - Record when engine is warmed up
    - Normal operating conditions
    - No unusual sounds
    - Same load condition for all samples
    """
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
        
        # Start collection
        from app.models import BaselineMetadata
        metadata = await baseline_service.start_baseline_collection(
            tractor_id=tractor_id.upper(),
            target_samples=target_samples,
            BaselineMetadataModel=BaselineMetadata
        )
        
        return {
            "message": "Baseline collection started",
            "tractor_id": metadata.tractor_id,
            "target_samples": metadata.target_samples,
            "collected_samples": metadata.collected_samples,
            "status": metadata.status,
            "instructions": metadata.instructions,
            "next_step": f"Upload {target_samples} audio samples using POST /baseline/{tractor_id}/add-sample"
        }
        
    except Exception as e:
        logger.error(f"Error starting baseline collection: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/{tractor_id}/add-sample")
async def add_baseline_sample(
    tractor_id: str,
    file: UploadFile = File(..., description="Audio file for baseline"),
    current_user: User = Depends(get_current_user)
):
    """
    Add an audio sample to baseline collection
    
    **Important:**
    - Upload audio when tractor is running normally
    - All samples should be from similar operating conditions
    - Minimum 3 samples, recommended 5 samples
    """
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
        
        # Save file
        timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        filename = f"baseline_{tractor_id}_{timestamp}.wav"
        file_path = BASELINE_DIR / filename
        
        content = await file.read()
        with open(file_path, "wb") as f:
            f.write(content)
        
        logger.info(f"💾 Saved baseline sample: {filename}")
        
        # Add to baseline
        from app.models import BaselineMetadata
        result = await baseline_service.add_baseline_sample(
            tractor_id=tractor_id.upper(),
            audio_file_path=str(file_path),
            BaselineMetadataModel=BaselineMetadata
        )
        
        response = {
            "message": f"Sample {result['collected_samples']}/{result['target_samples']} added",
            "tractor_id": result["tractor_id"],
            "progress": result["progress"],
            "collected_samples": result["collected_samples"],
            "target_samples": result["target_samples"],
            "ready_to_finalize": result["ready_to_finalize"]
        }
        
        if result["ready_to_finalize"]:
            response["next_step"] = f"All samples collected! Finalize baseline: POST /baseline/{tractor_id}/finalize"
        else:
            remaining = result["target_samples"] - result["collected_samples"]
            response["next_step"] = f"Upload {remaining} more sample(s)"
        
        return response
        
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"Error adding baseline sample: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/{tractor_id}/finalize")
async def finalize_baseline(
    tractor_id: str,
    tractor_hours: Optional[float] = Query(None, description="Current engine hours"),
    load_condition: LoadCondition = Query(LoadCondition.NORMAL, description="Operating load during recordings"),
    notes: str = Query("", description="Optional notes about this baseline"),
    current_user: User = Depends(get_current_user)
):
    """
    Finalize and activate baseline from collected samples
    
    **Requirements:**
    - At least 3 samples must be collected
    - All samples should be from healthy operation
    
    **What happens:**
    - Extracts audio features from all samples
    - Calculates average "normal" sound signature
    - Activates baseline for future comparisons
    - Archives any previous baseline
    """
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
        
        # Use tractor hours from query or database
        current_hours = tractor_hours if tractor_hours is not None else tractor.engine_hours
        
        # Finalize baseline
        from app.models import TractorBaseline, BaselineMetadata
        baseline = await baseline_service.finalize_baseline(
            tractor_id=tractor_id.upper(),
            tractor_hours=current_hours,
            load_condition=load_condition,
            notes=notes,
            TractorBaselineModel=TractorBaseline,
            BaselineMetadataModel=BaselineMetadata
        )
        
        # Update tractor baseline status
        tractor.baseline_status = "completed"
        await tractor.save()
        
        return {
            "message": "Baseline created successfully!",
            "baseline_id": str(baseline.id),
            "tractor_id": baseline.tractor_id,
            "tractor_hours": baseline.tractor_hours,
            "num_samples": baseline.num_samples,
            "confidence": baseline.confidence,
            "load_condition": baseline.load_condition,
            "status": baseline.status,
            "created_at": baseline.created_at,
            "next_step": "Future audio uploads will now be compared against this baseline for personalized analysis"
        }
        
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"Error finalizing baseline: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{tractor_id}/status")
async def get_baseline_status(
    tractor_id: str,
    current_user: User = Depends(get_current_user)
):
    """
    Get baseline status for a tractor
    
    **Returns:**
    - Active baseline info (if exists)
    - Collection progress (if collecting)
    - No baseline message (if none)
    """
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
        
        # Get status
        from app.models import TractorBaseline, BaselineMetadata
        status_info = await baseline_service.get_baseline_status(
            tractor_id=tractor_id.upper(),
            TractorBaselineModel=TractorBaseline,
            BaselineMetadataModel=BaselineMetadata
        )
        
        return status_info
        
    except Exception as e:
        logger.error(f"Error getting baseline status: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/{tractor_id}")
async def delete_baseline(
    tractor_id: str,
    current_user: User = Depends(get_current_user)
):
    """
    Delete baseline for a tractor
    
    **Warning:** This will delete:
    - Active baseline
    - In-progress collection
    - Future uploads will use ResNet only until new baseline is created
    """
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
        
        # Delete baseline
        from app.models import TractorBaseline, BaselineMetadata
        result = await baseline_service.delete_baseline(
            tractor_id=tractor_id.upper(),
            TractorBaselineModel=TractorBaseline,
            BaselineMetadataModel=BaselineMetadata
        )
        
        # Update tractor status
        tractor.baseline_status = "pending"
        await tractor.save()
        
        return result
        
    except Exception as e:
        logger.error(f"Error deleting baseline: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{tractor_id}/history")
async def get_baseline_history(
    tractor_id: str,
    current_user: User = Depends(get_current_user)
):
    """
    Get baseline history for a tractor (all baselines including archived)
    """
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
        
        # Get all baselines
        from app.models import TractorBaseline
        baselines = await TractorBaseline.find({
            "tractor_id": tractor_id.upper()
        }).sort("-created_at").to_list()
        
        history = []
        for baseline in baselines:
            history.append({
                "baseline_id": str(baseline.id),
                "created_at": baseline.created_at,
                "tractor_hours": baseline.tractor_hours,
                "num_samples": baseline.num_samples,
                "confidence": baseline.confidence,
                "status": baseline.status,
                "is_active": baseline.is_active,
                "load_condition": baseline.load_condition
            })
        
        return {
            "tractor_id": tractor_id.upper(),
            "total_baselines": len(history),
            "history": history
        }
        
    except Exception as e:
        logger.error(f"Error getting baseline history: {e}")
        raise HTTPException(status_code=500, detail=str(e))