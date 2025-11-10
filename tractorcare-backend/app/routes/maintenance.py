"""
Maintenance Management Routes
"""

from fastapi import APIRouter, HTTPException, status, Depends
from typing import List
from datetime import datetime, timezone, timedelta
import logging
from app.schemas import (
    MaintenanceRecordCreate,
    MaintenanceRecordResponse,
    MaintenanceTaskCreate,
    MaintenanceTaskResponse,
    MaintenanceAlertResponse,
    AlertUpdateStatus
)
from app.models import (
    Tractor,
    MaintenanceRecord,
    MaintenanceAlert,
    User,
    MaintenanceStatus,
    MaintenancePriority,
    AlertType,
    LastMaintenanceRecord
)
from app.core.security import get_current_user

logger = logging.getLogger(__name__)
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


@router.post("/{tractor_id}/tasks", response_model=MaintenanceTaskResponse)
async def create_maintenance_task(
    tractor_id: str,
    task_data: MaintenanceTaskCreate,
    current_user: User = Depends(get_current_user)
):
    """Create a new maintenance task"""
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
    
    # Map priority and determine alert type based on task type
    priority_map = {
        "LOW": MaintenancePriority.LOW,
        "MEDIUM": MaintenancePriority.MEDIUM,
        "HIGH": MaintenancePriority.HIGH
    }
    
    alert_type_map = {
        "inspection": AlertType.SCHEDULED,
        "oil_change": AlertType.SCHEDULED,
        "filter_change": AlertType.SCHEDULED,
        "repair": AlertType.URGENT,
        "service": AlertType.SCHEDULED
    }
    
    # Create maintenance alert (used as task)
    alert = MaintenanceAlert(
        tractor_id=tractor.tractor_id,
        alert_type=alert_type_map.get(task_data.type, AlertType.SCHEDULED),
        priority=priority_map.get(task_data.priority, MaintenancePriority.MEDIUM),
        status=MaintenanceStatus.SCHEDULED,
        task_name=task_data.task_name,
        description=task_data.description,
        estimated_time_minutes=task_data.estimated_time_minutes or 60,
        source=f"AUTO_{task_data.trigger_type}",
        due_date=task_data.due_date or datetime.now(timezone.utc),
        related_prediction_id=task_data.prediction_id
    )
    
    # Save the task
    await alert.insert()
    
    logger.info(f"Created maintenance task: {task_data.task_name} for tractor {tractor_id}")
    
    # Return response
    return MaintenanceTaskResponse(
        id=str(alert.id),
        tractor_id=alert.tractor_id,
        type=task_data.type,
        task_name=alert.task_name,
        description=alert.description,
        due_date=alert.due_date,
        due_at_hours=task_data.due_at_hours,
        priority=task_data.priority,
        trigger_type=task_data.trigger_type,
        prediction_id=task_data.prediction_id,
        status="PENDING",
        estimated_time_minutes=alert.estimated_time_minutes,
        estimated_cost=task_data.estimated_cost,
        notes=task_data.notes,
        created_at=alert.created_at
    )


@router.get("/{tractor_id}/alerts", response_model=List[MaintenanceAlertResponse])
async def get_alerts(
    tractor_id: str,
    current_user: User = Depends(get_current_user)
):
    """Get maintenance alerts for tractor"""
    try:
        # Verify ownership
        tractor = await Tractor.find_one({
            "tractor_id": tractor_id.upper(),
            "owner_id": str(current_user.id)
        })
        
        if not tractor:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Tractor {tractor_id} not found or access denied"
            )
        
        # Get alerts with error handling
        try:
            alerts = await MaintenanceAlert.find(
                {"tractor_id": tractor.tractor_id}
            ).sort("+due_date").to_list()
        except Exception as e:
            logger.error(f"Database error fetching alerts for {tractor_id}: {str(e)}")
            # Return empty list if database error, don't fail completely
            alerts = []
        
        # Convert to response format with safe attribute access
        alert_responses = []
        for alert in alerts:
            try:
                alert_response = MaintenanceAlertResponse(
                    id=str(alert.id) if hasattr(alert, 'id') and alert.id else "pending",
                    tractor_id=alert.tractor_id,
                    alert_type=getattr(alert, 'alert_type', None),
                    priority=getattr(alert, 'priority', None),
                    status=getattr(alert, 'status', None),
                    task_name=getattr(alert, 'task_name', ''),
                    description=getattr(alert, 'description', ''),
                    estimated_time_minutes=getattr(alert, 'estimated_time_minutes', 0),
                    source=getattr(alert, 'source', ''),
                    due_date=getattr(alert, 'due_date', None),
                    created_at=getattr(alert, 'created_at', None),
                    audio_anomaly_score=getattr(alert, 'audio_anomaly_score', None)
                )
                alert_responses.append(alert_response)
            except Exception as e:
                logger.warning(f"Skipping invalid alert for {tractor_id}: {str(e)}")
                continue
        
        return alert_responses
        
    except HTTPException:
        # Re-raise HTTP exceptions (like 404)
        raise
    except Exception as e:
        logger.error(f"Unexpected error in get_alerts for {tractor_id}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve maintenance alerts"
        )


@router.post("/{tractor_id}/test-alert")
async def create_test_alert(
    tractor_id: str,
    current_user: User = Depends(get_current_user)
):
    """Create a test maintenance alert for debugging"""
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
    
    # Create test alert
    test_alert = MaintenanceAlert(
        tractor_id=tractor.tractor_id,
        alert_type=AlertType.AUDIO_ANOMALY,
        priority=MaintenancePriority.HIGH,
        status=MaintenanceStatus.SCHEDULED,
        
        task_name="Test Sound Analysis Inspection",
        description="Test alert created manually for debugging",
        estimated_time_minutes=30,
        source="Manual_Test",
        
        due_date=datetime.now() + timedelta(days=1),
        created_at=datetime.now(),
        
        audio_anomaly_score=0.95,
        related_prediction_id="test_prediction"
    )
    
    await test_alert.insert()
    
    return {
        "message": "Test alert created successfully",
        "alert_id": str(test_alert.id),
        "tractor_id": tractor.tractor_id
    }