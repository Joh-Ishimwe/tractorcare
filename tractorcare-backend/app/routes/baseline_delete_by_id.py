"""
Additional baseline delete endpoint for specific baseline IDs
This adds support for deleting specific archived baselines
"""

from fastapi import APIRouter, Depends, HTTPException, status
from app.models import User, Tractor, TractorBaseline
from app.core.security import get_current_user
import logging

router = APIRouter()
logger = logging.getLogger(__name__)

@router.delete("/{tractor_id}/{baseline_id}")
async def delete_specific_baseline(
    tractor_id: str,
    baseline_id: str,
    current_user: User = Depends(get_current_user)
):
    """
    Delete a specific baseline by ID
    
    **Warning:** This will delete the specified baseline.
    If it's the active baseline, future uploads will use ResNet only until a new baseline is created.
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
        
        # Find the specific baseline
        baseline = await TractorBaseline.get(baseline_id)
        
        if not baseline or baseline.tractor_id != tractor_id.upper():
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Baseline {baseline_id} not found for tractor {tractor_id}"
            )
        
        # Check if this is the active baseline
        is_active = baseline.is_active
        
        # Delete the baseline
        await baseline.delete()
        
        # If we deleted the active baseline, update tractor status
        if is_active:
            tractor.baseline_status = "pending"
            await tractor.save()
            
            # If there are other baselines, activate the most recent one
            other_baselines = await TractorBaseline.find({
                "tractor_id": tractor_id.upper()
            }).sort("-created_at").to_list()
            
            if other_baselines:
                # Activate the most recent remaining baseline
                latest_baseline = other_baselines[0]
                latest_baseline.is_active = True
                await latest_baseline.save()
                tractor.baseline_status = "completed"
                await tractor.save()
        
        return {
            "message": f"Baseline {baseline_id} deleted successfully",
            "baseline_id": baseline_id,
            "tractor_id": tractor_id.upper(),
            "was_active": is_active
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting specific baseline: {e}")
        raise HTTPException(status_code=500, detail=str(e))