
"""
TractorCare - Predictive Maintenance System 
Based on manufacturer maintenance schedules ONLY
"""

import json
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple
import logging
from dataclasses import dataclass
from enum import Enum
import uuid

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# ============================================================================
# ENUMS
# ============================================================================

class UsageIntensity(Enum):
    """Tractor usage intensity levels"""
    LIGHT = "light"
    MODERATE = "moderate"
    HEAVY = "heavy"
    EXTREME = "extreme"

class MaintenancePriority(Enum):
    """Maintenance priority levels"""
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"

class MaintenanceStatus(Enum):
    """Maintenance task status"""
    SCHEDULED = "scheduled"
    DUE = "due"
    OVERDUE = "overdue"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    CANCELLED = "cancelled"

class AlertType(Enum):
    """Types of maintenance alerts"""
    ROUTINE_SCHEDULED = "routine_scheduled"
    ROUTINE_OVERDUE = "routine_overdue"
    AUDIO_ANOMALY = "audio_anomaly"
    CRITICAL_FAILURE = "critical_failure"
    TREND_DEGRADATION = "trend_degradation"

# ============================================================================
# DATA CLASSES
# ============================================================================

@dataclass
class MaintenanceTask:
    """
    Data class for maintenance tasks.
    Based on manufacturer specifications only.
    """
    task_id: str
    task_name: str
    description: str
    priority: MaintenancePriority
    interval_hours: float
    interval_days: int
    estimated_time_minutes: int  # Approximate time from manual
    category: str = "routine"  # routine, audio_triggered, emergency
    source: str = ""  # Reference to manual page/section

@dataclass
class MaintenanceRecord:
    """Data class for completed maintenance"""
    record_id: str
    tractor_id: str
    task_name: str
    completion_date: datetime
    completion_hours: float
    actual_time_minutes: int
    actual_cost_rwf: Optional[int] = None  # User can optionally enter
    notes: str = ""
    performed_by: str = ""
    parts_used: List[str] = None
    service_location: str = ""

@dataclass
class MaintenanceAlert:
    """Data class for maintenance alerts"""
    alert_id: str
    tractor_id: str
    alert_type: AlertType
    priority: MaintenancePriority
    task_name: str
    description: str
    due_date: datetime
    status: MaintenanceStatus
    created_at: datetime
    audio_anomaly_score: Optional[float] = None
    related_prediction_id: Optional[str] = None

# ============================================================================
# MAINTENANCE SCHEDULES (Manufacturer Data Only)
# ============================================================================

# Source: Massey Ferguson Operator Manuals
# MF 240 Manual: Section 7 - Maintenance Schedule
# MF 375 Manual: Section 8 - Preventive Maintenance

MAINTENANCE_SCHEDULES = {
    "MF_240": {
        "engine_oil_change": MaintenanceTask(
            task_id="mf240_oil",
            task_name="engine_oil_change",
            description="Engine oil and filter change",
            priority=MaintenancePriority.HIGH,
            interval_hours=250,
            interval_days=180,
            estimated_time_minutes=45,
            source="MF 240 Manual, Section 7.2"
        ),
        "air_filter_check": MaintenanceTask(
            task_id="mf240_air_check",
            task_name="air_filter_check",
            description="Air filter inspection and cleaning",
            priority=MaintenancePriority.MEDIUM,
            interval_hours=100,
            interval_days=60,
            estimated_time_minutes=20,
            source="MF 240 Manual, Section 7.3"
        ),
        "air_filter_replace": MaintenanceTask(
            task_id="mf240_air_replace",
            task_name="air_filter_replace",
            description="Air filter replacement",
            priority=MaintenancePriority.MEDIUM,
            interval_hours=500,
            interval_days=365,
            estimated_time_minutes=30,
            source="MF 240 Manual, Section 7.3"
        ),
        "fuel_filter_replace": MaintenanceTask(
            task_id="mf240_fuel",
            task_name="fuel_filter_replace",
            description="Fuel filter replacement",
            priority=MaintenancePriority.HIGH,
            interval_hours=300,
            interval_days=180,
            estimated_time_minutes=30,
            source="MF 240 Manual, Section 7.4"
        ),
        "hydraulic_oil_change": MaintenanceTask(
            task_id="mf240_hydraulic",
            task_name="hydraulic_oil_change",
            description="Hydraulic oil and filter change",
            priority=MaintenancePriority.HIGH,
            interval_hours=600,
            interval_days=365,
            estimated_time_minutes=60,
            source="MF 240 Manual, Section 7.5"
        ),
        "coolant_check": MaintenanceTask(
            task_id="mf240_coolant",
            task_name="coolant_check",
            description="Coolant level check and top-up",
            priority=MaintenancePriority.MEDIUM,
            interval_hours=50,
            interval_days=30,
            estimated_time_minutes=10,
            source="MF 240 Manual, Section 7.6"
        ),
        "battery_check": MaintenanceTask(
            task_id="mf240_battery",
            task_name="battery_check",
            description="Battery terminals and electrolyte check",
            priority=MaintenancePriority.MEDIUM,
            interval_hours=100,
            interval_days=60,
            estimated_time_minutes=15,
            source="MF 240 Manual, Section 7.7"
        ),
        "belt_inspection": MaintenanceTask(
            task_id="mf240_belt",
            task_name="belt_inspection",
            description="Fan and alternator belt inspection",
            priority=MaintenancePriority.MEDIUM,
            interval_hours=200,
            interval_days=120,
            estimated_time_minutes=20,
            source="MF 240 Manual, Section 7.8"
        ),
        "tire_pressure_check": MaintenanceTask(
            task_id="mf240_tire",
            task_name="tire_pressure_check",
            description="Tire pressure inspection and adjustment",
            priority=MaintenancePriority.MEDIUM,
            interval_hours=50,
            interval_days=30,
            estimated_time_minutes=15,
            source="MF 240 Manual, Section 7.9"
        ),
        "grease_points": MaintenanceTask(
            task_id="mf240_grease",
            task_name="grease_points",
            description="Lubricate all grease points",
            priority=MaintenancePriority.MEDIUM,
            interval_hours=50,
            interval_days=30,
            estimated_time_minutes=30,
            source="MF 240 Manual, Section 7.10"
        )
    },
    "MF_375": {
        "engine_oil_change": MaintenanceTask(
            task_id="mf375_oil",
            task_name="engine_oil_change",
            description="Engine oil and filter change",
            priority=MaintenancePriority.HIGH,
            interval_hours=300,
            interval_days=180,
            estimated_time_minutes=50,
            source="MF 375 Manual, Section 8.2"
        ),
        "air_filter_check": MaintenanceTask(
            task_id="mf375_air_check",
            task_name="air_filter_check",
            description="Air filter inspection and cleaning",
            priority=MaintenancePriority.MEDIUM,
            interval_hours=120,
            interval_days=60,
            estimated_time_minutes=25,
            source="MF 375 Manual, Section 8.3"
        ),
        "air_filter_replace": MaintenanceTask(
            task_id="mf375_air_replace",
            task_name="air_filter_replace",
            description="Air filter replacement",
            priority=MaintenancePriority.MEDIUM,
            interval_hours=600,
            interval_days=365,
            estimated_time_minutes=35,
            source="MF 375 Manual, Section 8.3"
        ),
        "fuel_filter_replace": MaintenanceTask(
            task_id="mf375_fuel",
            task_name="fuel_filter_replace",
            description="Fuel filter replacement",
            priority=MaintenancePriority.HIGH,
            interval_hours=350,
            interval_days=180,
            estimated_time_minutes=35,
            source="MF 375 Manual, Section 8.4"
        ),
        "hydraulic_oil_change": MaintenanceTask(
            task_id="mf375_hydraulic",
            task_name="hydraulic_oil_change",
            description="Hydraulic oil and filter change",
            priority=MaintenancePriority.HIGH,
            interval_hours=700,
            interval_days=365,
            estimated_time_minutes=70,
            source="MF 375 Manual, Section 8.5"
        ),
        "coolant_check": MaintenanceTask(
            task_id="mf375_coolant",
            task_name="coolant_check",
            description="Coolant level check and top-up",
            priority=MaintenancePriority.MEDIUM,
            interval_hours=60,
            interval_days=30,
            estimated_time_minutes=15,
            source="MF 375 Manual, Section 8.6"
        ),
        "battery_check": MaintenanceTask(
            task_id="mf375_battery",
            task_name="battery_check",
            description="Battery terminals and electrolyte check",
            priority=MaintenancePriority.MEDIUM,
            interval_hours=120,
            interval_days=60,
            estimated_time_minutes=20,
            source="MF 375 Manual, Section 8.7"
        ),
        "belt_inspection": MaintenanceTask(
            task_id="mf375_belt",
            task_name="belt_inspection",
            description="Fan and alternator belt inspection",
            priority=MaintenancePriority.MEDIUM,
            interval_hours=250,
            interval_days=120,
            estimated_time_minutes=25,
            source="MF 375 Manual, Section 8.8"
        ),
        "tire_pressure_check": MaintenanceTask(
            task_id="mf375_tire",
            task_name="tire_pressure_check",
            description="Tire pressure inspection and adjustment",
            priority=MaintenancePriority.MEDIUM,
            interval_hours=60,
            interval_days=30,
            estimated_time_minutes=20,
            source="MF 375 Manual, Section 8.9"
        ),
        "grease_points": MaintenanceTask(
            task_id="mf375_grease",
            task_name="grease_points",
            description="Lubricate all grease points",
            priority=MaintenancePriority.MEDIUM,
            interval_hours=60,
            interval_days=30,
            estimated_time_minutes=35,
            source="MF 375 Manual, Section 8.10"
        )
    }
}

# Audio anomaly to maintenance task mapping
ANOMALY_TASK_MAPPING = {
    "high_vibration": ["belt_inspection", "engine_oil_change"],
    "unusual_noise": ["engine_oil_change", "belt_inspection", "air_filter_check"],
    "knocking_sound": ["engine_oil_change", "fuel_filter_replace"],
    "whining_sound": ["hydraulic_oil_change", "belt_inspection"],
    "overheating": ["coolant_check", "air_filter_check"],
    "grinding_noise": ["belt_inspection", "grease_points"],
}

# ============================================================================
# CLASSES (Corrected - No Cost Estimates)
# ============================================================================

class Tractor:
    """Enhanced Tractor class without cost estimates"""
    
    def __init__(
        self,
        tractor_id: str,
        model: str,
        make: str,
        purchase_date: str,
        initial_engine_hours: float = 0.0,
        usage_intensity: UsageIntensity = UsageIntensity.MODERATE,
        owner_id: Optional[str] = None,
        location: Optional[Dict] = None
    ):
        self.tractor_id = tractor_id
        self.model = model
        self.make = make
        self.purchase_date = datetime.strptime(purchase_date, "%Y-%m-%d")
        self.engine_hours = initial_engine_hours
        self.usage_intensity = usage_intensity
        self.owner_id = owner_id
        self.location = location or {}
        self.baseline_status = "pending"
        
        # Initialize last maintenance tracking
        self.last_maintenance = {}
        schedule = MAINTENANCE_SCHEDULES.get(model, {})
        for task_name in schedule:
            self.last_maintenance[task_name] = {
                "date": self.purchase_date,
                "engine_hours": initial_engine_hours,
                "record_id": None
            }
        
        self.maintenance_history: List[MaintenanceRecord] = []
        self.recent_anomalies: List[Dict] = []
        
    def update_engine_hours(self, new_hours: float) -> bool:
        """Update engine hours with validation"""
        if new_hours < self.engine_hours:
            logger.warning(
                f"Attempted to set lower engine hours for {self.tractor_id}"
            )
            return False
        
        old_hours = self.engine_hours
        self.engine_hours = new_hours
        logger.info(f"Updated engine hours: {old_hours} -> {new_hours}")
        return True
    
    def get_usage_factor(self) -> float:
        """Return usage intensity factor"""
        factors = {
            UsageIntensity.LIGHT: 0.8,
            UsageIntensity.MODERATE: 1.0,
            UsageIntensity.HEAVY: 1.2,
            UsageIntensity.EXTREME: 1.5
        }
        return factors.get(self.usage_intensity, 1.0)
    
    def record_maintenance(self, record: MaintenanceRecord):
        """Record completed maintenance with optional cost"""
        self.maintenance_history.append(record)
        
        if record.task_name in self.last_maintenance:
            self.last_maintenance[record.task_name] = {
                "date": record.completion_date,
                "engine_hours": record.completion_hours,
                "record_id": record.record_id
            }
        
        logger.info(f"Recorded maintenance: {record.task_name}")
    
    def add_anomaly(self, anomaly_data: Dict):
        """Add audio anomaly to recent history"""
        self.recent_anomalies.append({
            **anomaly_data,
            "timestamp": datetime.now()
        })
        
        # Keep only last 30 days
        cutoff = datetime.now() - timedelta(days=30)
        self.recent_anomalies = [
            a for a in self.recent_anomalies
            if a["timestamp"] > cutoff
        ]
    
    def get_anomaly_count(self, days: int = 7) -> int:
        """Get count of anomalies in last N days"""
        cutoff = datetime.now() - timedelta(days=days)
        return sum(1 for a in self.recent_anomalies if a["timestamp"] > cutoff)
    
    def get_total_maintenance_cost(self) -> Optional[int]:
        """
        Calculate total maintenance costs from user-entered data.
        Returns None if no costs have been recorded.
        """
        costs = [r.actual_cost_rwf for r in self.maintenance_history 
                 if r.actual_cost_rwf is not None]
        return sum(costs) if costs else None
    
    def to_dict(self) -> Dict:
        """Convert to dictionary"""
        return {
            "tractor_id": self.tractor_id,
            "model": self.model,
            "make": self.make,
            "purchase_date": self.purchase_date.isoformat(),
            "engine_hours": self.engine_hours,
            "usage_intensity": self.usage_intensity.value,
            "baseline_status": self.baseline_status,
            "maintenance_count": len(self.maintenance_history),
            "recent_anomaly_count": len(self.recent_anomalies)
        }


class MaintenancePredictor:
    """Maintenance prediction without cost estimates"""
    
    def __init__(self, tractor: Tractor):
        self.tractor = tractor
        self.schedule = MAINTENANCE_SCHEDULES.get(tractor.model, {})
        
        if not self.schedule:
            raise ValueError(f"No schedule for model {tractor.model}")
    
    def predict_maintenance(self, task_name: str) -> Optional[MaintenanceAlert]:
        """Predict next maintenance for a specific task"""
        try:
            task = self.schedule.get(task_name)
            if not task:
                return None
            
            last_entry = self.tractor.last_maintenance.get(
                task_name,
                {"date": self.tractor.purchase_date, "engine_hours": 0.0}
            )
            
            last_date = last_entry["date"]
            last_engine_hours = float(last_entry["engine_hours"])
            
            # Apply usage factor
            usage_factor = self.tractor.get_usage_factor()
            interval_hours = task.interval_hours / usage_factor
            interval_days = task.interval_days / usage_factor
            
            # Calculate progress
            hours_since = self.tractor.engine_hours - last_engine_hours
            days_since = (datetime.now() - last_date).days
            
            hours_progress = hours_since / interval_hours
            days_progress = days_since / interval_days
            progress = max(hours_progress, days_progress)
            
            # Determine status
            if progress >= 1.1:
                status = MaintenanceStatus.OVERDUE
                due_date = datetime.now()
                priority = MaintenancePriority.CRITICAL
            elif progress >= 1.0:
                status = MaintenanceStatus.OVERDUE
                due_date = datetime.now() + timedelta(days=3)
                priority = task.priority
            elif progress >= 0.9:
                status = MaintenanceStatus.DUE
                remaining_hours = interval_hours - hours_since
                remaining_days = interval_days - days_since
                days_until_due = min(remaining_hours / 8, remaining_days)
                due_date = datetime.now() + timedelta(days=max(days_until_due, 0))
                priority = task.priority
            else:
                return None
            
            # Create alert
            alert = MaintenanceAlert(
                alert_id=str(uuid.uuid4()),
                tractor_id=self.tractor.tractor_id,
                alert_type=AlertType.ROUTINE_OVERDUE if status == MaintenanceStatus.OVERDUE 
                          else AlertType.ROUTINE_SCHEDULED,
                priority=priority,
                task_name=task_name,
                description=task.description,
                due_date=due_date,
                status=status,
                created_at=datetime.now()
            )
            
            return alert
            
        except Exception as e:
            logger.error(f"Error predicting maintenance: {str(e)}")
            return None
    
    def predict_all_maintenance(self) -> List[MaintenanceAlert]:
        """Predict all pending maintenance tasks"""
        alerts = []
        for task_name in self.schedule:
            alert = self.predict_maintenance(task_name)
            if alert:
                alerts.append(alert)
        
        # Sort by priority and due date
        priority_order = {
            MaintenancePriority.CRITICAL: 0,
            MaintenancePriority.HIGH: 1,
            MaintenancePriority.MEDIUM: 2,
            MaintenancePriority.LOW: 3
        }
        
        alerts.sort(key=lambda x: (priority_order[x.priority], x.due_date))
        return alerts
    
    def create_audio_triggered_alert(
        self,
        anomaly_score: float,
        anomaly_type: str,
        prediction_id: str
    ) -> List[MaintenanceAlert]:
        """Create maintenance alerts based on audio anomaly"""
        suggested_tasks = ANOMALY_TASK_MAPPING.get(anomaly_type, [])
        
        if not suggested_tasks:
            suggested_tasks = ["engine_oil_change", "air_filter_check"]
        
        alerts = []
        
        for task_name in suggested_tasks:
            task = self.schedule.get(task_name)
            if not task:
                continue
            
            # Determine priority based on score
            if anomaly_score > 0.8:
                priority = MaintenancePriority.CRITICAL
                due_date = datetime.now()
            elif anomaly_score > 0.6:
                priority = MaintenancePriority.HIGH
                due_date = datetime.now() + timedelta(days=1)
            else:
                priority = MaintenancePriority.MEDIUM
                due_date = datetime.now() + timedelta(days=3)
            
            alert = MaintenanceAlert(
                alert_id=str(uuid.uuid4()),
                tractor_id=self.tractor.tractor_id,
                alert_type=AlertType.AUDIO_ANOMALY,
                priority=priority,
                task_name=task_name,
                description=f"Audio anomaly detected: {anomaly_type}. {task.description}",
                due_date=due_date,
                status=MaintenanceStatus.DUE,
                created_at=datetime.now(),
                audio_anomaly_score=anomaly_score,
                related_prediction_id=prediction_id
            )
            
            alerts.append(alert)
        
        return alerts


class UnifiedMaintenanceEngine:
    """Unified engine without cost calculations"""
    
    def __init__(self, tractor: Tractor):
        self.tractor = tractor
        self.predictor = MaintenancePredictor(tractor)
        self.all_alerts: List[MaintenanceAlert] = []
    
    def generate_all_alerts(self) -> List[MaintenanceAlert]:
        """Generate comprehensive maintenance alerts"""
        routine_alerts = self.predictor.predict_all_maintenance()
        
        audio_alerts = []
        for anomaly in self.tractor.recent_anomalies:
            if anomaly.get("handled"):
                continue
            
            new_alerts = self.predictor.create_audio_triggered_alert(
                anomaly_score=anomaly.get("anomaly_score", 0),
                anomaly_type=anomaly.get("anomaly_type", "unknown"),
                prediction_id=anomaly.get("prediction_id", "")
            )
            audio_alerts.extend(new_alerts)
        
        all_alerts = routine_alerts + audio_alerts
        deduplicated = self._deduplicate_alerts(all_alerts)
        
        self.all_alerts = deduplicated
        return deduplicated
    
    def _deduplicate_alerts(self, alerts: List[MaintenanceAlert]) -> List[MaintenanceAlert]:
        """Remove duplicate alerts"""
        task_alerts = {}
        
        for alert in alerts:
            if alert.task_name not in task_alerts:
                task_alerts[alert.task_name] = alert
            else:
                existing = task_alerts[alert.task_name]
                priority_order = {
                    MaintenancePriority.CRITICAL: 0,
                    MaintenancePriority.HIGH: 1,
                    MaintenancePriority.MEDIUM: 2,
                    MaintenancePriority.LOW: 3
                }
                
                if priority_order[alert.priority] < priority_order[existing.priority]:
                    task_alerts[alert.task_name] = alert
        
        return list(task_alerts.values())
    
    def get_maintenance_summary(self) -> Dict:
        """Get comprehensive maintenance summary WITHOUT cost estimates"""
        alerts = self.generate_all_alerts()
        
        critical_count = sum(1 for a in alerts if a.priority == MaintenancePriority.CRITICAL)
        high_count = sum(1 for a in alerts if a.priority == MaintenancePriority.HIGH)
        overdue_count = sum(1 for a in alerts if a.status == MaintenanceStatus.OVERDUE)
        
        # Calculate estimated time only
        total_estimated_time = sum(
            self.predictor.schedule[a.task_name].estimated_time_minutes
            for a in alerts
            if a.task_name in self.predictor.schedule
        )
        
        health_score = self._calculate_health_score()
        
        # Get user-tracked costs if available
        total_tracked_cost = self.tractor.get_total_maintenance_cost()
        
        return {
            "tractor_id": self.tractor.tractor_id,
            "model": self.tractor.model,
            "engine_hours": self.tractor.engine_hours,
            "health_score": health_score,
            "health_status": self._get_health_status(health_score),
            "alerts_summary": {
                "total": len(alerts),
                "critical": critical_count,
                "high": high_count,
                "overdue": overdue_count
            },
            "estimated_maintenance": {
                "total_time_minutes": total_estimated_time,
                "total_time_hours": round(total_estimated_time / 60, 1),
                # No cost estimate
                "cost_note": "Contact local mechanic for pricing"
            },
            "user_tracked_costs": {
                "total_spent_rwf": total_tracked_cost,
                "records_count": len([r for r in self.tractor.maintenance_history 
                                     if r.actual_cost_rwf is not None])
            } if total_tracked_cost else None,
            "recent_anomaly_count": self.tractor.get_anomaly_count(days=7),
            "last_maintenance_date": self._get_last_maintenance_date(),
            "alerts": [self._alert_to_dict(a) for a in alerts]
        }
    
    def _calculate_health_score(self) -> float:
        """Calculate health score"""
        score = 100.0
        
        for alert in self.all_alerts:
            if alert.status == MaintenanceStatus.OVERDUE:
                if alert.priority == MaintenancePriority.CRITICAL:
                    score -= 20
                elif alert.priority == MaintenancePriority.HIGH:
                    score -= 10
                else:
                    score -= 5
        
        anomaly_count = self.tractor.get_anomaly_count(days=7)
        score -= min(anomaly_count * 5, 30)
        
        return max(score, 0)
    
    def _get_health_status(self, health_score: float) -> str:
        """Convert health score to status"""
        if health_score >= 90:
            return "excellent"
        elif health_score >= 75:
            return "good"
        elif health_score >= 60:
            return "fair"
        elif health_score >= 40:
            return "poor"
        else:
            return "critical"
    
    def _get_last_maintenance_date(self) -> Optional[str]:
        """Get date of most recent maintenance"""
        if not self.tractor.maintenance_history:
            return None
        
        latest = max(
            self.tractor.maintenance_history,
            key=lambda x: x.completion_date
        )
        
        return latest.completion_date.isoformat()
    
    def _alert_to_dict(self, alert: MaintenanceAlert) -> Dict:
        """Convert alert to dictionary"""
        task = self.predictor.schedule.get(alert.task_name)
        
        return {
            "alert_id": alert.alert_id,
            "alert_type": alert.alert_type.value,
            "priority": alert.priority.value,
            "task_name": alert.task_name,
            "description": alert.description,
            "due_date": alert.due_date.isoformat(),
            "status": alert.status.value,
            "created_at": alert.created_at.isoformat(),
            "estimated_time_minutes": task.estimated_time_minutes if task else None,
            "source": task.source if task else None,
            "audio_anomaly_score": alert.audio_anomaly_score,
            "cost_note": "Contact your mechanic for pricing quote"
        }


# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

def print_maintenance_report(summary: Dict):
    """Print formatted maintenance report WITHOUT cost estimates"""
    print("\n" + "="*60)
    print(f"MAINTENANCE REPORT - {summary['tractor_id']}")
    print("="*60)
    print(f"Model: {summary['model']}")
    print(f"Engine Hours: {summary['engine_hours']}")
    print(f"Health Score: {summary['health_score']}/100 ({summary['health_status'].upper()})")
    print(f"Recent Anomalies (7 days): {summary['recent_anomaly_count']}")
    
    print(f"\n--- ALERTS SUMMARY ---")
    print(f"Total Alerts: {summary['alerts_summary']['total']}")
    print(f"  Critical: {summary['alerts_summary']['critical']}")
    print(f"  High: {summary['alerts_summary']['high']}")
    print(f"  Overdue: {summary['alerts_summary']['overdue']}")
    
    print(f"\n--- ESTIMATED TIME ---")
    print(f"Total Time: {summary['estimated_maintenance']['total_time_hours']} hours")
    print(f"Cost: {summary['estimated_maintenance']['cost_note']}")
    
    # Show user-tracked costs if available
    if summary.get('user_tracked_costs'):
        tracked = summary['user_tracked_costs']
        print(f"\n--- YOUR MAINTENANCE SPENDING ---")
        print(f"Total Spent: {tracked['total_spent_rwf']:,} RWF")
        print(f"Based on {tracked['records_count']} recorded service(s)")
    
    if summary['alerts']:
        print(f"\n--- PENDING MAINTENANCE TASKS ---")
        for i, alert in enumerate(summary['alerts'], 1):
            print(f"\n{i}. {alert['task_name'].replace('_', ' ').title()}")
            print(f"   Priority: {alert['priority'].upper()}")
            print(f"   Status: {alert['status'].upper()}")
            print(f"   Due: {alert['due_date'][:10]}")
            print(f"   Estimated Time: {alert['estimated_time_minutes']} minutes")
            print(f"   Description: {alert['description']}")
            print(f"   Source: {alert['source']}")
            if alert.get('audio_anomaly_score'):
                print(f"   ⚠️  Audio Anomaly Score: {alert['audio_anomaly_score']:.2f}")
    
    print("\n" + "="*60)
    print("💡 TIP: Ask your mechanic for a quote before service")
    print("="*60 + "\n")


# ============================================================================
# EXAMPLE USAGE
# ============================================================================

if __name__ == "__main__":
    # Create sample tractor
    tractor = Tractor(
        tractor_id="TRC001",
        model="MF_240",
        make="Massey Ferguson",
        purchase_date="2023-01-15",
        initial_engine_hours=0.0,
        usage_intensity=UsageIntensity.MODERATE
    )
    
    # Simulate usage
    tractor.update_engine_hours(960)  # 6 months usage
    
    # Add audio anomaly
    tractor.add_anomaly({
        "prediction_id": "PRED001",
        "anomaly_score": 0.75,
        "anomaly_type": "high_vibration",
        "confidence": 0.85
    })
    
    # Record a completed maintenance (user enters cost)
    record = MaintenanceRecord(
        record_id="REC001",
        tractor_id="TRC001",
        task_name="coolant_check",
        completion_date=datetime.now() - timedelta(days=15),
        completion_hours=900,
        actual_time_minutes=12,
        actual_cost_rwf=5000,  # User-entered cost
        notes="Topped up coolant",
        performed_by="Local Mechanic - Kigali"
    )
    tractor.record_maintenance(record)
    
    # Generate report
    engine = UnifiedMaintenanceEngine(tractor)
    summary = engine.get_maintenance_summary()
    
    print_maintenance_report(summary)


class CostDatabase:
    """
    User-contributed cost database
    with proper attribution and regional data
    """
    
    def __init__(self):
        self.cost_data = {}  # Store user-reported costs
    
    def add_cost_report(
        self,
        task_name: str,
        actual_cost: int,
        location: str,
        date: datetime,
        service_provider: str,
        parts_quality: str  # OEM, aftermarket, etc.
    ):
        """Users contribute actual costs they paid"""
        # Store with proper metadata
        pass
    
    def get_cost_range(
        self,
        task_name: str,
        location: str,
        days_ago: int = 90
    ) -> Dict:
        """Get cost range from recent user reports"""
        # Return: min, max, average, sample_size
        # e.g., "25,000-35,000 RWF based on 12 reports"
        pass
