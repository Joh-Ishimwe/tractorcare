"""
Maintenance Management Routes
"""

from fastapi import APIRouter, HTTPException, status, Depends
from typing import List
from datetime import datetime
from app.schemas import (
    MaintenanceRecordCreate,
    MaintenanceRecordResponse,
    MaintenanceAlertResponse,
    AlertUpdateStatus
)
from app.models import (
    Tractor,
    MaintenanceRecord,
    MaintenanceAlert,
    User,
    MaintenanceStatus,
    LastMaintenanceRecord
)
from app.core.security import get_current_user

router = APIRouter()


@router.post("/{tractor_id}/records", response_model=MaintenanceRecordResponse)
async def record_maintenance(
    tractor_id: str,
    record_data: MaintenanceRecordCreate,
    current_user: User = Depends(get_current_user)
):
    """Record completed maintenance"""
    # Get tractor
    tractor = await Tractor.find_one({
        "tractor_id": tractor_id.upper(),
        "owner_id": str(current_user.id)
    })
    
    if not tractor:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Tractor not found"
        )
    
    # Create record
    record = MaintenanceRecord(
        tractor_id=tractor.tractor_id,
        task_name=record_data.task_name,
        description=record_data.description,
        completion_date=record_data.completion_date,
        completion_hours=record_data.completion_hours,
        actual_time_minutes=record_data.actual_time_minutes,
        actual_cost_rwf=record_data.actual_cost_rwf,
        service_location=record_data.service_location,
        service_provider=record_data.service_provider,
        notes=record_data.notes,
        performed_by=record_data.performed_by,
        parts_used=record_data.parts_used or []
    )
    
    await record.insert()
    
    # Update tractor's last_maintenance
    tractor.last_maintenance[record_data.task_name] = LastMaintenanceRecord(
        date=record_data.completion_date,
        engine_hours=record_data.completion_hours,
        record_id=str(record.id)
    )
    tractor.updated_at = datetime.utcnow()
    await tractor.save()
    
    # Mark related alerts as completed
    alerts = await MaintenanceAlert.find({
        "tractor_id": tractor.tractor_id,
        "task_name": record_data.task_name,
        "status": {"$ne": MaintenanceStatus.COMPLETED}
    }).to_list()
    
    for alert in alerts:
        alert.status = MaintenanceStatus.COMPLETED
        alert.resolved_at = datetime.utcnow()
        await alert.save()
    
    return MaintenanceRecordResponse(
        id=str(record.id),
        tractor_id=record.tractor_id,
        task_name=record.task_name,
        description=record.description,
        completion_date=record.completion_date,
        completion_hours=record.completion_hours,
        actual_time_minutes=record.actual_time_minutes,
        actual_cost_rwf=record.actual_cost_rwf,
        service_location=record.service_location,
        notes=record.notes,
        created_at=record.created_at
    )


@router.get("/{tractor_id}/records", response_model=List[MaintenanceRecordResponse])
async def get_maintenance_history(
    tractor_id: str,
    current_user: User = Depends(get_current_user),
    limit: int = 50
):
    """Get maintenance history for tractor"""
    # Verify ownership
    tractor = await Tractor.find_one({
        "tractor_id": tractor_id.upper(),
        "owner_id": str(current_user.id)
    })
    
    if not tractor:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Tractor not found"
        )
    
    # Get records
    records = await MaintenanceRecord.find(
        {"tractor_id": tractor.tractor_id}
    ).sort("-completion_date").limit(limit).to_list()
    
    return [
        MaintenanceRecordResponse(
            id=str(r.id),
            tractor_id=r.tractor_id,
            task_name=r.task_name,
            description=r.description,
            completion_date=r.completion_date,
            completion_hours=r.completion_hours,
            actual_time_minutes=r.actual_time_minutes,
            actual_cost_rwf=r.actual_cost_rwf,
            service_location=r.service_location,
            notes=r.notes,
            created_at=r.created_at
        )
        for r in records
    ]


@router.get("/{tractor_id}/alerts", response_model=List[MaintenanceAlertResponse])
async def get_alerts(
    tractor_id: str,
    current_user: User = Depends(get_current_user)
):
    """Get maintenance alerts for tractor"""
    # Verify ownership
    tractor = await Tractor.find_one({
        "tractor_id": tractor_id.upper(),
        "owner_id": str(current_user.id)
    })
    
    if not tractor:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Tractor not found"
        )
    
    # Get alerts
    alerts = await MaintenanceAlert.find(
        {"tractor_id": tractor.tractor_id}
    ).sort("+due_date").to_list()
    
    return [
        MaintenanceAlertResponse(
            id=str(a.id),
            tractor_id=a.tractor_id,
            alert_type=a.alert_type,
            priority=a.priority,
            status=a.status,
            task_name=a.task_name,
            description=a.description,
            estimated_time_minutes=a.estimated_time_minutes,
            source=a.source,
            due_date=a.due_date,
            created_at=a.created_at,
            audio_anomaly_score=a.audio_anomaly_score
        )
        for a in alerts
    ]