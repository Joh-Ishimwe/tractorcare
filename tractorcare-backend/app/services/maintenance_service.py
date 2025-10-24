"""
Maintenance Prediction Service
Rule-based predictions from manufacturer schedules
"""

from datetime import datetime, timedelta
from typing import List, Dict, Optional
import logging
from app.models import (
    Tractor,
    MaintenanceAlert,
    MaintenanceSchedule,
    Anomaly,
    MaintenancePriority,
    MaintenanceStatus,
    AlertType,
    HealthStatus,
)
from app.core.config import ANOMALY_TASK_MAPPING

logger = logging.getLogger(__name__)


class MaintenancePredictor:
    """
    Maintenance prediction engine
    Based on manufacturer schedules only
    """
    
    def __init__(self, tractor: Tractor):
        self.tractor = tractor
        self.schedule: Optional[MaintenanceSchedule] = None
    
    async def load_schedule(self):
        """Load maintenance schedule for tractor model"""
        self.schedule = await MaintenanceSchedule.find_one(
            MaintenanceSchedule.model == self.tractor.model
        )
        
        if not self.schedule:
            raise ValueError(f"No maintenance schedule found for model {self.tractor.model}")
    
    def _get_usage_factor(self) -> float:
        """Get usage intensity factor"""
        factors = {
            "light": 0.8,
            "moderate": 1.0,
            "heavy": 1.2,
            "extreme": 1.5
        }
        return factors.get(self.tractor.usage_intensity, 1.0)
    
    async def predict_single_task(self, task_info) -> Optional[MaintenanceAlert]:
        """
        Predict next maintenance for a specific task
        Returns alert if maintenance is due soon
        """
        try:
            task_name = task_info.task_name
            
            # Get last maintenance record
            last_record = self.tractor.last_maintenance.get(task_name)
            
            if not last_record:
                # No previous maintenance - use purchase date
                last_date = self.tractor.purchase_date
                last_hours = 0.0
            else:
                last_date = last_record.date
                last_hours = last_record.engine_hours
            
            # Calculate intervals with usage factor
            usage_factor = self._get_usage_factor()
            interval_hours = task_info.interval_hours / usage_factor
            interval_days = task_info.interval_days / usage_factor
            
            # Calculate progress
            hours_since = self.tractor.engine_hours - last_hours
            days_since = (datetime.utcnow() - last_date).days
            
            hours_progress = hours_since / interval_hours
            days_progress = days_since / interval_days
            progress = max(hours_progress, days_progress)
            
            # Determine if alert is needed (>90% progress)
            if progress < 0.9:
                return None
            
            # Determine status and priority
            if progress >= 1.1:
                status = MaintenanceStatus.OVERDUE
                due_date = datetime.utcnow()
                priority = MaintenancePriority.CRITICAL
            elif progress >= 1.0:
                status = MaintenanceStatus.OVERDUE
                due_date = datetime.utcnow() + timedelta(days=3)
                priority = task_info.priority
            else:  # 0.9 <= progress < 1.0
                status = MaintenanceStatus.DUE
                remaining_hours = interval_hours - hours_since
                remaining_days = interval_days - days_since
                days_until_due = min(remaining_hours / 8, remaining_days)
                due_date = datetime.utcnow() + timedelta(days=max(days_until_due, 0))
                priority = task_info.priority
            
            # Create alert
            alert = MaintenanceAlert(
                tractor_id=self.tractor.tractor_id,
                alert_type=AlertType.ROUTINE_OVERDUE if status == MaintenanceStatus.OVERDUE 
                          else AlertType.ROUTINE_SCHEDULED,
                priority=priority,
                status=status,
                task_name=task_name,
                description=task_info.description,
                estimated_time_minutes=task_info.estimated_time_minutes,
                source=task_info.source,
                due_date=due_date
            )
            
            return alert
            
        except Exception as e:
            logger.error(f"Error predicting task {task_name}: {str(e)}")
            return None
    
    async def predict_all_maintenance(self) -> List[MaintenanceAlert]:
        """
        Predict all pending maintenance tasks
        Returns list of alerts sorted by priority
        """
        await self.load_schedule()
        
        alerts = []
        
        for task_info in self.schedule.tasks:
            alert = await self.predict_single_task(task_info)
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
    
    async def create_audio_triggered_alerts(
        self,
        anomaly_score: float,
        anomaly_type: str,
        prediction_id: str
    ) -> List[MaintenanceAlert]:
        """
        Create maintenance alerts based on audio anomaly
        Maps anomaly type to suggested maintenance tasks
        """
        await self.load_schedule()
        
        # Get suggested tasks for this anomaly type
        suggested_task_names = ANOMALY_TASK_MAPPING.get(
            anomaly_type,
            ["engine_oil_change", "air_filter_check"]  # Default
        )
        
        alerts = []
        
        for task_name in suggested_task_names:
            # Find task in schedule
            task_info = next(
                (t for t in self.schedule.tasks if t.task_name == task_name),
                None
            )
            
            if not task_info:
                continue
            
            # Determine priority based on anomaly score
            if anomaly_score > 0.8:
                priority = MaintenancePriority.CRITICAL
                due_date = datetime.utcnow()
            elif anomaly_score > 0.6:
                priority = MaintenancePriority.HIGH
                due_date = datetime.utcnow() + timedelta(days=1)
            else:
                priority = MaintenancePriority.MEDIUM
                due_date = datetime.utcnow() + timedelta(days=3)
            
            # Create alert
            alert = MaintenanceAlert(
                tractor_id=self.tractor.tractor_id,
                alert_type=AlertType.AUDIO_ANOMALY,
                priority=priority,
                status=MaintenanceStatus.DUE,
                task_name=task_name,
                description=f"Audio anomaly detected: {anomaly_type}. {task_info.description}",
                estimated_time_minutes=task_info.estimated_time_minutes,
                source=task_info.source,
                due_date=due_date,
                audio_anomaly_score=anomaly_score,
                related_prediction_id=prediction_id
            )
            
            alerts.append(alert)
        
        return alerts


class UnifiedMaintenanceEngine:
    """
    Unified engine combining routine and audio-triggered maintenance
    NO COST CALCULATIONS!
    """
    
    def __init__(self, tractor: Tractor):
        self.tractor = tractor
        self.predictor = MaintenancePredictor(tractor)
    
    async def generate_all_alerts(self) -> List[MaintenanceAlert]:
        """
        Generate comprehensive maintenance alerts
        Combines routine predictions and audio anomaly alerts
        """
        # Get routine alerts
        routine_alerts = await self.predictor.predict_all_maintenance()
        
        # Get recent unhandled anomalies (last 30 days)
        cutoff_date = datetime.utcnow() - timedelta(days=30)
        anomalies = await Anomaly.find(
            Anomaly.tractor_id == self.tractor.tractor_id,
            Anomaly.handled == False,
            Anomaly.created_at >= cutoff_date
        ).to_list()
        
        # Create alerts from anomalies
        audio_alerts = []
        for anomaly in anomalies:
            new_alerts = await self.predictor.create_audio_triggered_alerts(
                anomaly_score=anomaly.anomaly_score,
                anomaly_type=anomaly.anomaly_type,
                prediction_id=anomaly.prediction_id
            )
            audio_alerts.extend(new_alerts)
        
        # Combine and deduplicate
        all_alerts = routine_alerts + audio_alerts
        deduplicated = self._deduplicate_alerts(all_alerts)
        
        return deduplicated
    
    def _deduplicate_alerts(self, alerts: List[MaintenanceAlert]) -> List[MaintenanceAlert]:
        """
        Remove duplicate alerts
        Keep highest priority for each task
        """
        task_alerts: Dict[str, MaintenanceAlert] = {}
        
        priority_order = {
            MaintenancePriority.CRITICAL: 0,
            MaintenancePriority.HIGH: 1,
            MaintenancePriority.MEDIUM: 2,
            MaintenancePriority.LOW: 3
        }
        
        for alert in alerts:
            if alert.task_name not in task_alerts:
                task_alerts[alert.task_name] = alert
            else:
                existing = task_alerts[alert.task_name]
                if priority_order[alert.priority] < priority_order[existing.priority]:
                    task_alerts[alert.task_name] = alert
        
        return list(task_alerts.values())
    
    async def get_maintenance_summary(self) -> Dict:
        """
        Get comprehensive maintenance summary
        NO COST ESTIMATES!
        """
        # Generate all alerts
        alerts = await self.generate_all_alerts()
        
        # Calculate counts
        critical_count = sum(1 for a in alerts if a.priority == MaintenancePriority.CRITICAL)
        high_count = sum(1 for a in alerts if a.priority == MaintenancePriority.HIGH)
        overdue_count = sum(1 for a in alerts if a.status == MaintenanceStatus.OVERDUE)
        
        # Calculate total estimated time
        total_time_minutes = sum(a.estimated_time_minutes for a in alerts)
        
        # Calculate health score
        health_score = self._calculate_health_score(alerts)
        health_status = self._get_health_status(health_score)
        
        # Get user-tracked costs (if any)
        from app.models import MaintenanceRecord
        records = await MaintenanceRecord.find(
            MaintenanceRecord.tractor_id == self.tractor.tractor_id,
            MaintenanceRecord.actual_cost_rwf != None
        ).to_list()
        
        total_spent = sum(r.actual_cost_rwf for r in records) if records else None
        
        # Get recent anomaly count
        cutoff_date = datetime.utcnow() - timedelta(days=7)
        recent_anomalies = await Anomaly.find(
            Anomaly.tractor_id == self.tractor.tractor_id,
            Anomaly.created_at >= cutoff_date
        ).count()
        
        # Get last maintenance date
        all_records = await MaintenanceRecord.find(
            MaintenanceRecord.tractor_id == self.tractor.tractor_id
        ).sort("-completion_date").limit(1).to_list()
        
        last_maintenance_date = all_records[0].completion_date if all_records else None
        
        return {
            "tractor_id": self.tractor.tractor_id,
            "model": self.tractor.model,
            "engine_hours": self.tractor.engine_hours,
            "health_score": health_score,
            "health_status": health_status,
            "alerts_summary": {
                "total": len(alerts),
                "critical": critical_count,
                "high": high_count,
                "overdue": overdue_count
            },
            "estimated_maintenance": {
                "total_time_minutes": total_time_minutes,
                "total_time_hours": round(total_time_minutes / 60, 1),
                "cost_note": "Contact local mechanic for pricing"
            },
            "user_tracked_costs": {
                "total_spent_rwf": total_spent,
                "records_count": len(records)
            } if total_spent else None,
            "recent_anomaly_count": recent_anomalies,
            "last_maintenance_date": last_maintenance_date,
            "alerts": alerts
        }
    
    def _calculate_health_score(self, alerts: List[MaintenanceAlert]) -> float:
        """Calculate health score based on alerts"""
        score = 100.0
        
        for alert in alerts:
            if alert.status == MaintenanceStatus.OVERDUE:
                if alert.priority == MaintenancePriority.CRITICAL:
                    score -= 20
                elif alert.priority == MaintenancePriority.HIGH:
                    score -= 10
                else:
                    score -= 5
        
        return max(score, 0)
    
    def _get_health_status(self, health_score: float) -> HealthStatus:
        """Convert health score to status"""
        if health_score >= 90:
            return HealthStatus.EXCELLENT
        elif health_score >= 75:
            return HealthStatus.GOOD
        elif health_score >= 60:
            return HealthStatus.FAIR
        elif health_score >= 40:
            return HealthStatus.POOR
        else:
            return HealthStatus.CRITICAL