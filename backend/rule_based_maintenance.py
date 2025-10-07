"""
TractorCare - Rule-Based Predictive Maintenance System
Based on manufacturer maintenance schedules
"""

import json
from datetime import datetime, timedelta
from typing import Dict, List, Tuple
import pandas as pd

# ============================================================================
# 1. MAINTENANCE SCHEDULE DATABASE 
# ============================================================================

# Massey Ferguson 240 & 375 maintenance schedules
# Source: MF operator manuals and service guidelines

MAINTENANCE_SCHEDULES = {
    "MF_240": {
        "engine_oil_change": {
            "interval_hours": 250,
            "interval_days": 180,
            "description": "Engine oil and filter change",
            "priority": "high",
            "estimated_cost_rwf": 25000,
            "estimated_time_minutes": 45
        },
        "air_filter_check": {
            "interval_hours": 100,
            "interval_days": 60,
            "description": "Air filter inspection and cleaning",
            "priority": "medium",
            "estimated_cost_rwf": 5000,
            "estimated_time_minutes": 20
        },
        "air_filter_replace": {
            "interval_hours": 500,
            "interval_days": 365,
            "description": "Air filter replacement",
            "priority": "medium",
            "estimated_cost_rwf": 15000,
            "estimated_time_minutes": 30
        },
        "fuel_filter_replace": {
            "interval_hours": 300,
            "interval_days": 180,
            "description": "Fuel filter replacement",
            "priority": "high",
            "estimated_cost_rwf": 12000,
            "estimated_time_minutes": 30
        },
        "hydraulic_oil_change": {
            "interval_hours": 600,
            "interval_days": 365,
            "description": "Hydraulic oil and filter change",
            "priority": "high",
            "estimated_cost_rwf": 35000,
            "estimated_time_minutes": 60
        },
        "coolant_check": {
            "interval_hours": 50,
            "interval_days": 30,
            "description": "Coolant level check and top-up",
            "priority": "medium",
            "estimated_cost_rwf": 3000,
            "estimated_time_minutes": 10
        },
        "battery_check": {
            "interval_hours": 100,
            "interval_days": 60,
            "description": "Battery terminals and electrolyte check",
            "priority": "medium",
            "estimated_cost_rwf": 2000,
            "estimated_time_minutes": 15
        },
        "belt_inspection": {
            "interval_hours": 200,
            "interval_days": 120,
            "description": "Fan and alternator belt inspection",
            "priority": "medium",
            "estimated_cost_rwf": 8000,
            "estimated_time_minutes": 20
        },
        "greasing_points": {
            "interval_hours": 50,
            "interval_days": 30,
            "description": "Lubricate all grease fittings",
            "priority": "low",
            "estimated_cost_rwf": 5000,
            "estimated_time_minutes": 30
        },
        "tire_pressure_check": {
            "interval_hours": 50,
            "interval_days": 15,
            "description": "Check and adjust tire pressure",
            "priority": "low",
            "estimated_cost_rwf": 1000,
            "estimated_time_minutes": 10
        },
        "transmission_oil_check": {
            "interval_hours": 100,
            "interval_days": 90,
            "description": "Transmission oil level check",
            "priority": "medium",
            "estimated_cost_rwf": 3000,
            "estimated_time_minutes": 15
        },
        "major_service": {
            "interval_hours": 1000,
            "interval_days": 365,
            "description": "Major service - comprehensive inspection",
            "priority": "high",
            "estimated_cost_rwf": 80000,
            "estimated_time_minutes": 180
        }
    },
    "MF_375": {
        # Similar structure for MF 375 (intervals may vary slightly)
        "engine_oil_change": {
            "interval_hours": 250,
            "interval_days": 180,
            "description": "Engine oil and filter change",
            "priority": "high",
            "estimated_cost_rwf": 28000,
            "estimated_time_minutes": 50
        },
        "air_filter_check": {
            "interval_hours": 100,
            "interval_days": 60,
            "description": "Air filter inspection and cleaning",
            "priority": "medium",
            "estimated_cost_rwf": 5000,
            "estimated_time_minutes": 20
        },
        "fuel_filter_replace": {
            "interval_hours": 300,
            "interval_days": 180,
            "description": "Fuel filter replacement",
            "priority": "high",
            "estimated_cost_rwf": 13000,
            "estimated_time_minutes": 35
        },
        "hydraulic_oil_change": {
            "interval_hours": 600,
            "interval_days": 365,
            "description": "Hydraulic oil and filter change",
            "priority": "high",
            "estimated_cost_rwf": 40000,
            "estimated_time_minutes": 70
        },
        "coolant_check": {
            "interval_hours": 50,
            "interval_days": 30,
            "description": "Coolant level check and top-up",
            "priority": "medium",
            "estimated_cost_rwf": 3000,
            "estimated_time_minutes": 10
        },
        "battery_check": {
            "interval_hours": 100,
            "interval_days": 60,
            "description": "Battery terminals and electrolyte check",
            "priority": "medium",
            "estimated_cost_rwf": 2000,
            "estimated_time_minutes": 15
        },
        "belt_inspection": {
            "interval_hours": 200,
            "interval_days": 120,
            "description": "Fan and alternator belt inspection",
            "priority": "medium",
            "estimated_cost_rwf": 8000,
            "estimated_time_minutes": 20
        },
        "greasing_points": {
            "interval_hours": 50,
            "interval_days": 30,
            "description": "Lubricate all grease fittings",
            "priority": "low",
            "estimated_cost_rwf": 5000,
            "estimated_time_minutes": 30
        },
        "tire_pressure_check": {
            "interval_hours": 50,
            "interval_days": 15,
            "description": "Check and adjust tire pressure",
            "priority": "low",
            "estimated_cost_rwf": 1000,
            "estimated_time_minutes": 10
        },
        "transmission_oil_check": {
            "interval_hours": 100,
            "interval_days": 90,
            "description": "Transmission oil level check",
            "priority": "medium",
            "estimated_cost_rwf": 3000,
            "estimated_time_minutes": 15
        },
        "major_service": {
            "interval_hours": 1000,
            "interval_days": 365,
            "description": "Major service - comprehensive inspection",
            "priority": "high",
            "estimated_cost_rwf": 80000,
            "estimated_time_minutes": 180
        }
    }
}

# ============================================================================
# 2. USAGE INTENSITY MULTIPLIERS
# ============================================================================

INTENSITY_MULTIPLIERS = {
    "light": 1.0,      # Flat terrain, normal loads
    "moderate": 0.85,  # Some hills, regular use
    "heavy": 0.70,     # Steep terrain, heavy loads, dusty conditions
    "extreme": 0.60    # Continuous heavy use, very dusty/muddy
}

# ============================================================================
# 3. TRACTOR CLASS
# ============================================================================

class Tractor:
    """Represents a tractor with maintenance tracking"""
    
    def __init__(self, tractor_id: str, model: str, purchase_date: str,
                 initial_engine_hours: float = 0, usage_intensity: str = "moderate"):
        self.tractor_id = tractor_id
        self.model = model
        self.purchase_date = datetime.strptime(purchase_date, "%Y-%m-%d")
        self.engine_hours = initial_engine_hours
        self.usage_intensity = usage_intensity
        self.maintenance_history = []
        self.schedule = MAINTENANCE_SCHEDULES.get(model, MAINTENANCE_SCHEDULES["MF_240"])
        
    def update_engine_hours(self, hours_to_add: float):
        """Update engine hours after use"""
        self.engine_hours += hours_to_add
        
    def log_maintenance(self, task_name: str, date: str, notes: str = ""):
        """Record completed maintenance"""
        maintenance_record = {
            "task": task_name,
            "date": date,
            "engine_hours_at_service": self.engine_hours,
            "notes": notes
        }
        self.maintenance_history.append(maintenance_record)
        
    def get_last_maintenance(self, task_name: str) -> Dict:
        """Get the most recent maintenance for a specific task"""
        relevant_records = [m for m in self.maintenance_history if m["task"] == task_name]
        if relevant_records:
            return max(relevant_records, key=lambda x: x["date"])
        return None
    
    def to_dict(self):
        """Export tractor data"""
        return {
            "tractor_id": self.tractor_id,
            "model": self.model,
            "purchase_date": self.purchase_date.strftime("%Y-%m-%d"),
            "engine_hours": self.engine_hours,
            "usage_intensity": self.usage_intensity,
            "maintenance_history": self.maintenance_history
        }

# ============================================================================
# 4. RULE-BASED PREDICTION ENGINE
# ============================================================================

class MaintenancePredictor:
    """Rule-based predictive maintenance system"""
    
    def __init__(self, tractor: Tractor):
        self.tractor = tractor
        self.intensity_multiplier = INTENSITY_MULTIPLIERS.get(
            tractor.usage_intensity, 1.0
        )
        
    def predict_all_maintenance(self) -> List[Dict]:
        """Check all maintenance tasks and predict what's due"""
        predictions = []
        
        for task_name, task_info in self.tractor.schedule.items():
            prediction = self._predict_single_task(task_name, task_info)
            if prediction:
                predictions.append(prediction)
        
        # Sort by urgency
        predictions.sort(key=lambda x: x["hours_remaining"])
        return predictions
    
    def _predict_single_task(self, task_name: str, task_info: Dict) -> Dict:
        """Predict maintenance need for a single task"""
        
        # Get last maintenance
        last_service = self.tractor.get_last_maintenance(task_name)
        
        if last_service:
            hours_since_service = self.tractor.engine_hours - last_service["engine_hours_at_service"]
            days_since_service = (datetime.now() - datetime.strptime(last_service["date"], "%Y-%m-%d")).days
        else:
            # Never serviced, use current engine hours
            hours_since_service = self.tractor.engine_hours
            days_since_service = (datetime.now() - self.tractor.purchase_date).days
        
        # Apply intensity multiplier to intervals
        adjusted_hour_interval = task_info["interval_hours"] * self.intensity_multiplier
        adjusted_day_interval = task_info["interval_days"]
        
        # Calculate remaining hours and days
        hours_remaining = adjusted_hour_interval - hours_since_service
        days_remaining = adjusted_day_interval - days_since_service
        
        # Determine status based on whichever comes first
        status, urgency_level = self._determine_status(hours_remaining, days_remaining)
        
        if status != "ok":
            return {
                "task_name": task_name,
                "description": task_info["description"],
                "status": status,
                "urgency_level": urgency_level,
                "priority": task_info["priority"],
                "hours_remaining": max(0, hours_remaining),
                "days_remaining": max(0, days_remaining),
                "hours_since_last": hours_since_service,
                "days_since_last": days_since_service,
                "last_service_date": last_service["date"] if last_service else "Never",
                "estimated_cost_rwf": task_info["estimated_cost_rwf"],
                "estimated_time_minutes": task_info["estimated_time_minutes"],
                "recommendation": self._generate_recommendation(
                    hours_remaining, days_remaining, task_info
                )
            }
        
        return None
    
    def _determine_status(self, hours_remaining: float, 
                         days_remaining: int) -> Tuple[str, int]:
        """Determine maintenance status and urgency level"""
        
        # Use whichever is more urgent (hours or days)
        effective_remaining = min(
            hours_remaining / 10,  # Normalize hours (10 hours ~= 1 day of use)
            days_remaining
        )
        
        if effective_remaining <= 0:
            return "overdue", 5  # Critical
        elif effective_remaining <= 20:
            return "urgent", 4   # Very urgent
        elif effective_remaining <= 50:
            return "due_soon", 3  # Moderate
        elif effective_remaining <= 100:
            return "approaching", 2  # Low
        else:
            return "ok", 1  # No action needed
    
    def _generate_recommendation(self, hours_remaining: float, 
                                days_remaining: int, task_info: Dict) -> str:
        """Generate human-readable recommendation"""
        
        if hours_remaining <= 0 or days_remaining <= 0:
            return f"⚠️ OVERDUE: Schedule maintenance immediately. Safety risk."
        elif hours_remaining <= 20 or days_remaining <= 7:
            return f"🔴 URGENT: Maintenance due within {int(hours_remaining)} hours or {days_remaining} days."
        elif hours_remaining <= 50 or days_remaining <= 30:
            return f"🟡 DUE SOON: Plan maintenance within {int(hours_remaining)} hours or {days_remaining} days."
        else:
            return f"🟢 OK: Next service in {int(hours_remaining)} hours or {days_remaining} days."

# ============================================================================
# 5. ALERT GENERATION SYSTEM
# ============================================================================

class AlertSystem:
    """Generate maintenance alerts and notifications"""
    
    @staticmethod
    def generate_alerts(predictions: List[Dict]) -> List[Dict]:
        """Convert predictions to actionable alerts"""
        alerts = []
        
        for pred in predictions:
            alert = {
                "alert_id": f"ALT_{pred['task_name']}_{datetime.now().strftime('%Y%m%d')}",
                "timestamp": datetime.now().isoformat(),
                "tractor_id": None,  # Will be set by calling function
                "alert_type": "rule_based",
                "severity": pred["urgency_level"],
                "title": f"{pred['description']} - {pred['status'].replace('_', ' ').title()}",
                "message": pred["recommendation"],
                "task_details": pred,
                "action_required": pred["status"] in ["overdue", "urgent"]
            }
            alerts.append(alert)
        
        return alerts
    
    @staticmethod
    def format_summary(predictions: List[Dict]) -> str:
        """Create summary report"""
        if not predictions:
            return "✅ All maintenance tasks are up to date!"
        
        summary = f"📋 Maintenance Status Summary\n"
        summary += f"{'='*50}\n\n"
        
        overdue = [p for p in predictions if p["status"] == "overdue"]
        urgent = [p for p in predictions if p["status"] == "urgent"]
        due_soon = [p for p in predictions if p["status"] == "due_soon"]
        
        if overdue:
            summary += f"🔴 OVERDUE ({len(overdue)}):\n"
            for p in overdue:
                summary += f"  • {p['description']}\n"
            summary += "\n"
        
        if urgent:
            summary += f"🟠 URGENT ({len(urgent)}):\n"
            for p in urgent:
                summary += f"  • {p['description']} - {int(p['hours_remaining'])}h or {p['days_remaining']}d remaining\n"
            summary += "\n"
        
        if due_soon:
            summary += f"🟡 DUE SOON ({len(due_soon)}):\n"
            for p in due_soon:
                summary += f"  • {p['description']} - {int(p['hours_remaining'])}h or {p['days_remaining']}d remaining\n"
        
        # Cost estimate
        total_cost = sum(p["estimated_cost_rwf"] for p in predictions)
        summary += f"\n💰 Estimated total maintenance cost: {total_cost:,} RWF\n"
        
        return summary

# ============================================================================
# 6. DEMONSTRATION / TESTING
# ============================================================================

if __name__ == "__main__":
    print("TractorCare Rule-Based Maintenance System Demo\n")
    print("="*60)
    
    # Create sample tractor
    tractor = Tractor(
        tractor_id="TR001",
        model="MF_240",
        purchase_date="2023-01-15",
        initial_engine_hours=1200,
        usage_intensity="moderate"
    )
    
    # Log some past maintenance
    tractor.log_maintenance("engine_oil_change", "2024-06-15", "Regular service")
    tractor.log_maintenance("air_filter_check", "2024-08-01", "Cleaned filter")
    
    # Update current hours (simulate usage)
    tractor.update_engine_hours(350)  # Now at 1550 hours
    
    print(f"\n📊 Tractor Information:")
    print(f"ID: {tractor.tractor_id}")
    print(f"Model: {tractor.model}")
    print(f"Current Engine Hours: {tractor.engine_hours}")
    print(f"Usage Intensity: {tractor.usage_intensity}")
    print(f"Days since purchase: {(datetime.now() - tractor.purchase_date).days}")
    
    # Run predictions
    predictor = MaintenancePredictor(tractor)
    predictions = predictor.predict_all_maintenance()
    
    # Generate alerts
    alert_system = AlertSystem()
    alerts = alert_system.generate_alerts(predictions)
    
    # Update alerts with tractor ID
    for alert in alerts:
        alert["tractor_id"] = tractor.tractor_id
    
    # Display summary
    print("\n" + "="*60)
    summary = alert_system.format_summary(predictions)
    print(summary)
    
    # Detailed predictions
    print("\n" + "="*60)
    print("📝 Detailed Maintenance Schedule:\n")
    
    for pred in predictions:
        print(f"\n{pred['description'].upper()}")
        print(f"  Status: {pred['status'].replace('_', ' ').title()}")
        print(f"  Priority: {pred['priority'].upper()}")
        print(f"  Hours remaining: {int(pred['hours_remaining'])}")
        print(f"  Days remaining: {pred['days_remaining']}")
        print(f"  Last service: {pred['last_service_date']}")
        print(f"  Estimated cost: {pred['estimated_cost_rwf']:,} RWF")
        print(f"  Estimated time: {pred['estimated_time_minutes']} minutes")
        print(f"  ➜ {pred['recommendation']}")
    
    # Save results
    print("\n" + "="*60)
    print("💾 Saving results...")
    
    # Save tractor data
    with open('tractor_data.json', 'w') as f:
        json.dump(tractor.to_dict(), f, indent=4)
    
    # Save predictions
    with open('maintenance_predictions.json', 'w') as f:
        json.dump(predictions, f, indent=4)
    
    # Save alerts
    with open('maintenance_alerts.json', 'w') as f:
        json.dump(alerts, f, indent=4)
    
    print("✓ Tractor data saved: tractor_data.json")
    print("✓ Predictions saved: maintenance_predictions.json")
    print("✓ Alerts saved: maintenance_alerts.json")
    
    print("\n" + "="*60)
    print("✅ Rule-Based System Demo Complete!")
    print("\nNext steps:")
    print("1. Integrate with FastAPI backend")
    print("2. Connect to mobile app UI")
    print("3. Combine with ML audio predictions")