from fastapi import APIRouter, Depends
from app.models import User, Tractor, MaintenanceRecord
from app.core.security import get_current_user

router = APIRouter()


@router.get('/user')
async def get_user_statistics(current_user: User = Depends(get_current_user)):
    '''Get statistics for current user'''
    # Count tractors
    tractors = await Tractor.find(
        Tractor.owner_id == str(current_user.id)
    ).to_list()
    
    total_tractors = len(tractors)
    
    # Get maintenance records
    tractor_ids = [t.tractor_id for t in tractors]
    records = await MaintenanceRecord.find(
        {'tractor_id': {'$in': tractor_ids}}
    ).to_list()
    
    total_maintenance = len(records)
    
    # Calculate total spent (only user-entered costs)
    total_spent = sum(
        r.actual_cost_rwf for r in records
        if r.actual_cost_rwf is not None
    )
    
    return {
        'total_tractors': total_tractors,
        'total_maintenance_records': total_maintenance,
        'total_spent_rwf': total_spent if total_spent > 0 else None,
        'records_with_cost': sum(1 for r in records if r.actual_cost_rwf is not None)
    }
