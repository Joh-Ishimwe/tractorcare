import numpy as np
from scipy.spatial.distance import cosine
from typing import Optional, Dict
from datetime import datetime

def calculate_drift_score(new_features: np.ndarray, baseline_features: np.ndarray) -> float:
    """
    Calculate similarity between new recording and baseline
    
    Returns:
        Cosine similarity score (0-1, where 1 = identical)
    """
    # Flatten features for cosine similarity
    new_flat = new_features.flatten()
    baseline_flat = baseline_features.flatten()
    
    # Cosine similarity (1 - cosine distance)
    similarity = 1 - cosine(new_flat, baseline_flat)
    
    return float(similarity)

def determine_status(global_score: float, drift_score: Optional[float]) -> tuple[str, str, str]:
    """
    Determine tractor status and generate messages
    
    ADJUSTED THRESHOLDS (more conservative for transfer learning model):
    - GOOD: > 60% (was 70%)
    - WARNING: 40-60% (was 40-70%)
    - CRITICAL: < 40%
    
    Returns:
        (status, message, recommendation)
    """
    if drift_score is None:
        # No baseline yet - rely only on global model
        if global_score >= 60:  # Lowered from 70
            return (
                "GOOD",
                f"Engine sounds healthy ({global_score:.1f}% normal confidence)",
                "Continue regular maintenance schedule. Record more sounds to establish baseline."
            )
        elif global_score >= 40:
            return (
                "WARNING",
                f"Potential issue detected ({global_score:.1f}% normal confidence)",
                "⚠️ Inspect soon - check oil levels, filters, and belts. Record more sounds to confirm."
            )
        else:
            return (
                "CRITICAL",
                f"Serious abnormality detected ({global_score:.1f}% normal confidence)",
                "🚨 URGENT: Stop operation and consult mechanic immediately"
            )
    
    # Has baseline - use hybrid scoring
    if global_score >= 60 and drift_score >= 0.7:
        return (
            "GOOD",
            f"Engine sounds normal ({global_score:.1f}% confidence, {drift_score:.2f} similarity to baseline)",
            "✅ Tractor is operating within expected parameters"
        )
    elif global_score >= 40 and drift_score >= 0.5:
        return (
            "WARNING",
            f"Minor anomaly detected ({global_score:.1f}% confidence, {drift_score:.2f} baseline similarity)",
            "⚠️ Monitor closely - sound is slightly different from your tractor's baseline"
        )
    elif drift_score < 0.5:
        return (
            "WARNING",
            f"Sound has changed significantly from baseline (drift: {drift_score:.2f}, score: {global_score:.1f}%)",
            "⚠️ Your tractor sounds different than usual - recommend inspection"
        )
    else:
        return (
            "CRITICAL",
            f"Serious issue detected ({global_score:.1f}% confidence, {drift_score:.2f} baseline match)",
            "🚨 URGENT: Consult mechanic before further operation"
        )

async def get_or_create_baseline(db, tractor_id: str) -> Optional[np.ndarray]:
    """Fetch baseline features from MongoDB"""
    tractor = await db.tractors.find_one({"_id": tractor_id})
    
    if tractor and "baseline" in tractor and tractor["baseline"].get("established", False):
        baseline_features = np.array(tractor["baseline"]["avg_mfcc_features"])
        return baseline_features
    
    return None

async def update_baseline(db, tractor_id: str, new_features: np.ndarray):
    """
    Add new recording to baseline (for first 5 recordings)
    """
    tractor = await db.tractors.find_one({"_id": tractor_id})
    
    if not tractor:
        # Create new tractor record
        await db.tractors.insert_one({
            "_id": tractor_id,
            "baseline": {
                "established": False,
                "recording_count": 1,
                "features_sum": new_features.flatten().tolist(),
                "established_date": None
            },
            "created_at": datetime.utcnow()
        })
        return
    
    baseline_data = tractor.get("baseline", {})
    
    if not baseline_data.get("established", False):
        # Still in baseline establishment phase (< 5 recordings)
        count = baseline_data.get("recording_count", 0)
        features_sum = np.array(baseline_data.get("features_sum", np.zeros(new_features.size)))
        
        # Accumulate features
        features_sum += new_features.flatten()
        count += 1
        
        if count >= 5:
            # Establish baseline (average of 5 recordings)
            avg_features = features_sum / count
            await db.tractors.update_one(
                {"_id": tractor_id},
                {"$set": {
                    "baseline.established": True,
                    "baseline.avg_mfcc_features": avg_features.tolist(),
                    "baseline.recording_count": count,
                    "baseline.established_date": datetime.utcnow()
                }}
            )
        else:
            await db.tractors.update_one(
                {"_id": tractor_id},
                {"$set": {
                    "baseline.features_sum": features_sum.tolist(),
                    "baseline.recording_count": count
                }}
            )