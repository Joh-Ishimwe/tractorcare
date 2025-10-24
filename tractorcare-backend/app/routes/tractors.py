"""
Tractor Management Routes
"""

from fastapi import APIRouter, HTTPException, status, Depends
from typing import List
from datetime import datetime
from app.schemas import (
    TractorCreate,
    TractorUpdate,
    TractorResponse,
    MaintenanceSummary
)
from app.models import Tractor, User, MaintenanceSchedule, LastMaintenanceRecord
from app.core.security import get_current_user
from app.services.maintenance_service import UnifiedMaintenanceEngine

router = APIRouter()


@router.post("/", response_model=TractorResponse, status_code=status.HTTP_201_CREATED)
async def create_tractor(
    tractor_data: TractorCreate,
    current_user: User = Depends(get_current_user)
):
    """Create a new tractor"""
    # Check if tractor_id already exists
    existing = await Tractor.find_one({"tractor_id": tractor_data.tractor_id})
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Tractor ID already exists"
        )
    
    # Create tractor
    tractor = Tractor(
        tractor_id=tractor_data.tractor_id.upper(),
        owner_id=str(current_user.id),
        model=tractor_data.model,
        purchase_date=tractor_data.purchase_date,
        engine_hours=tractor_data.engine_hours,
        usage_intensity=tractor_data.usage_intensity
    )
    
    # Initialize last_maintenance tracking
    schedule = await MaintenanceSchedule.find_one({"model": tractor_data.model})
    
    if schedule:
        for task in schedule.tasks:
            tractor.last_maintenance[task.task_name] = LastMaintenanceRecord(
                date=tractor.purchase_date,
                engine_hours=tractor.engine_hours
            )
    
    await tractor.insert()
    
    return TractorResponse(
        id=str(tractor.id),
        tractor_id=tractor.tractor_id,
        owner_id=tractor.owner_id,
        model=tractor.model,
        make=tractor.make,
        purchase_date=tractor.purchase_date,
        engine_hours=tractor.engine_hours,
        usage_intensity=tractor.usage_intensity,
        health_status=tractor.health_status,
        baseline_status=tractor.baseline_status,
        created_at=tractor.created_at
    )


@router.get("/", response_model=List[TractorResponse])
async def get_user_tractors(current_user: User = Depends(get_current_user)):
    """Get all tractors for current user"""
    tractors = await Tractor.find({"owner_id": str(current_user.id)}).to_list()
    
    return [
        TractorResponse(
            id=str(t.id),
            tractor_id=t.tractor_id,
            owner_id=t.owner_id,
            model=t.model,
            make=t.make,
            purchase_date=t.purchase_date,
            engine_hours=t.engine_hours,
            usage_intensity=t.usage_intensity,
            health_status=t.health_status,
            baseline_status=t.baseline_status,
            created_at=t.created_at
        )
        for t in tractors
    ]


@router.get("/{tractor_id}", response_model=TractorResponse)
async def get_tractor(
    tractor_id: str,
    current_user: User = Depends(get_current_user)
):
    """Get specific tractor"""
    tractor = await Tractor.find_one({
        "tractor_id": tractor_id.upper(),
        "owner_id": str(current_user.id)
    })
    
    if not tractor:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Tractor not found"
        )
    
    return TractorResponse(
        id=str(tractor.id),
        tractor_id=tractor.tractor_id,
        owner_id=tractor.owner_id,
        model=tractor.model,
        make=tractor.make,
        purchase_date=tractor.purchase_date,
        engine_hours=tractor.engine_hours,
        usage_intensity=tractor.usage_intensity,
        health_status=tractor.health_status,
        baseline_status=tractor.baseline_status,
        created_at=tractor.created_at
    )


@router.put("/{tractor_id}", response_model=TractorResponse)
async def update_tractor(
    tractor_id: str,
    update_data: TractorUpdate,
    current_user: User = Depends(get_current_user)
):
    """Update tractor information"""
    tractor = await Tractor.find_one({
        "tractor_id": tractor_id.upper(),
        "owner_id": str(current_user.id)
    })
    
    if not tractor:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Tractor not found"
        )
    
    # Update fields
    if update_data.engine_hours is not None:
        if update_data.engine_hours < tractor.engine_hours:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Engine hours cannot be decreased"
            )
        tractor.engine_hours = update_data.engine_hours
    
    if update_data.usage_intensity is not None:
        tractor.usage_intensity = update_data.usage_intensity
    
    if update_data.health_status is not None:
        tractor.health_status = update_data.health_status
    
    tractor.updated_at = datetime.utcnow()
    await tractor.save()
    
    return TractorResponse(
        id=str(tractor.id),
        tractor_id=tractor.tractor_id,
        owner_id=tractor.owner_id,
        model=tractor.model,
        make=tractor.make,
        purchase_date=tractor.purchase_date,
        engine_hours=tractor.engine_hours,
        usage_intensity=tractor.usage_intensity,
        health_status=tractor.health_status,
        baseline_status=tractor.baseline_status,
        created_at=tractor.created_at
    )


@router.get("/{tractor_id}/summary", response_model=MaintenanceSummary)
async def get_tractor_summary(
    tractor_id: str,
    current_user: User = Depends(get_current_user)
):
    """Get comprehensive maintenance summary for tractor"""
    tractor = await Tractor.find_one({
        "tractor_id": tractor_id.upper(),
        "owner_id": str(current_user.id)
    })
    
    if not tractor:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Tractor not found"
        )
    
    # Generate summary using maintenance engine
    engine = UnifiedMaintenanceEngine(tractor)
    summary_dict = await engine.get_maintenance_summary()
    
    # Convert alerts to response format
    from app.schemas import MaintenanceAlertResponse
    
    alert_responses = [
        MaintenanceAlertResponse(
            id=str(alert.id) if hasattr(alert, 'id') else "pending",
            tractor_id=alert.tractor_id,
            alert_type=alert.alert_type,
            priority=alert.priority,
            status=alert.status,
            task_name=alert.task_name,
            description=alert.description,
            estimated_time_minutes=alert.estimated_time_minutes,
            source=alert.source,
            due_date=alert.due_date,
            created_at=alert.created_at,
            audio_anomaly_score=alert.audio_anomaly_score
        )
        for alert in summary_dict["alerts"]
    ]
    
    return MaintenanceSummary(
        tractor_id=summary_dict["tractor_id"],
        model=summary_dict["model"],
        engine_hours=summary_dict["engine_hours"],
        health_score=summary_dict["health_score"],
        health_status=summary_dict["health_status"],
        total_alerts=summary_dict["alerts_summary"]["total"],
        critical_alerts=summary_dict["alerts_summary"]["critical"],
        high_priority_alerts=summary_dict["alerts_summary"]["high"],
        overdue_alerts=summary_dict["alerts_summary"]["overdue"],
        total_estimated_time_minutes=summary_dict["estimated_maintenance"]["total_time_minutes"],
        total_estimated_time_hours=summary_dict["estimated_maintenance"]["total_time_hours"],
        total_spent_rwf=(summary_dict.get("user_tracked_costs") or {}).get("total_spent_rwf"),
        maintenance_records_count=summary_dict.get("user_tracked_costs", {}).get("records_count"),
        recent_anomaly_count=summary_dict["recent_anomaly_count"],
        last_maintenance_date=summary_dict["last_maintenance_date"],
        alerts=alert_responses
    )