"""
Daily Usage Tracking Routes
"""

from fastapi import APIRouter, HTTPException, status, Depends
from typing import List
from datetime import datetime, timedelta
from app.schemas import DailyUsageCreate, DailyUsageResponse
from app.models import Tractor, DailyUsage, User
from app.core.security import get_current_user
from app.services.maintenance_service import UnifiedMaintenanceEngine

router = APIRouter()


@router.post("/{tractor_id}/usage", response_model=DailyUsageResponse)
async def log_daily_usage(
    tractor_id: str,
    usage_data: DailyUsageCreate,
    current_user: User = Depends(get_current_user)
):
    """Log daily tractor usage and update engine hours"""
    
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
    
    # Validate hours
    if usage_data.end_hours < tractor.engine_hours:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"End hours ({usage_data.end_hours}) cannot be less than current hours ({tractor.engine_hours})"
        )
    
    # Calculate hours used today
    hours_used = usage_data.end_hours - tractor.engine_hours
    
    # Create daily usage record
    daily_usage = DailyUsage(
        tractor_id=tractor.tractor_id,
        date=datetime.utcnow(),
        start_hours=tractor.engine_hours,
        end_hours=usage_data.end_hours,
        hours_used=hours_used,
        notes=usage_data.notes
    )
    
    await daily_usage.insert()
    
    # Update tractor engine hours
    tractor.engine_hours = usage_data.end_hours
    tractor.updated_at = datetime.utcnow()
    await tractor.save()
    
    # Check if maintenance is now due
    maintenance_engine = UnifiedMaintenanceEngine(tractor)
    alerts = await maintenance_engine.generate_all_alerts()
    
    # Save new alerts to database
    for alert in alerts:
        # Check if alert already exists
        existing = await MaintenanceAlert.find_one({
            "tractor_id": alert.tractor_id,
            "task_name": alert.task_name,
            "status": {"$ne": MaintenanceStatus.COMPLETED}
        })
        
        if not existing:
            await alert.insert()
    
    return DailyUsageResponse(
        id=str(daily_usage.id),
        tractor_id=daily_usage.tractor_id,
        date=daily_usage.date,
        start_hours=daily_usage.start_hours,
        end_hours=daily_usage.end_hours,
        hours_used=daily_usage.hours_used,
        notes=daily_usage.notes,
        created_at=daily_usage.created_at
    )


@router.get("/{tractor_id}/usage", response_model=List[DailyUsageResponse])
async def get_usage_history(
    tractor_id: str,
    current_user: User = Depends(get_current_user),
    days: int = 30
):
    """Get daily usage history"""
    
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
    
    # Get usage records
    cutoff_date = datetime.utcnow() - timedelta(days=days)
    
    records = await DailyUsage.find(
        {"tractor_id": tractor.tractor_id, "date": {"$gte": cutoff_date}}
    ).sort("-date").to_list()
    
    return [
        DailyUsageResponse(
            id=str(r.id),
            tractor_id=r.tractor_id,
            date=r.date,
            start_hours=r.start_hours,
            end_hours=r.end_hours,
            hours_used=r.hours_used,
            notes=r.notes,
            created_at=r.created_at
        )
        for r in records
    ]


@router.get("/{tractor_id}/usage/stats")
async def get_usage_stats(
    tractor_id: str,
    current_user: User = Depends(get_current_user)
):
    """Get usage statistics"""
    
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
    
    # Get records for different periods
    now = datetime.utcnow()
    
    # Last 7 days
    week_ago = now - timedelta(days=7)
    week_records = await DailyUsage.find({
        "tractor_id": tractor.tractor_id,
        "date": {"$gte": week_ago}
    }).to_list()
    
    # Last 30 days
    month_ago = now - timedelta(days=30)
    month_records = await DailyUsage.find({
        "tractor_id": tractor.tractor_id,
        "date": {"$gte": month_ago}
    }).to_list()
    
    # Calculate stats
    week_hours = sum(r.hours_used for r in week_records)
    month_hours = sum(r.hours_used for r in month_records)
    
    avg_daily = week_hours / 7 if week_hours > 0 else 0
    avg_monthly = month_hours / 30 if month_hours > 0 else 0
    
    # Predict next maintenance based on usage
    maintenance_engine = UnifiedMaintenanceEngine(tractor)
    alerts = await maintenance_engine.generate_all_alerts()
    
    # Find soonest maintenance
    next_maintenance = None
    if alerts:
        soonest = min(alerts, key=lambda a: a.due_date)
        next_maintenance = {
            "task_name": soonest.task_name,
            "due_date": soonest.due_date,
            "priority": soonest.priority,
            "status": soonest.status
        }
    
    return {
        "tractor_id": tractor.tractor_id,
        "current_hours": tractor.engine_hours,
        "usage_last_7_days": {
            "total_hours": round(week_hours, 2),
            "average_per_day": round(avg_daily, 2),
            "records_count": len(week_records)
        },
        "usage_last_30_days": {
            "total_hours": round(month_hours, 2),
            "average_per_day": round(avg_monthly, 2),
            "records_count": len(month_records)
        },
        "next_maintenance": next_maintenance,
        "pending_alerts_count": len(alerts)
    }