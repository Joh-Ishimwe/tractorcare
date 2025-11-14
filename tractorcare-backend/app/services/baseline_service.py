"""
Baseline Service for Personalized Audio Anomaly Detection
Manages baseline creation, updates, and deviation calculations
File: app/services/baseline_service.py
"""

import librosa
import numpy as np
from typing import Optional, Dict, List, Tuple
from datetime import datetime
import logging
from pathlib import Path

from app.models import (
    TractorBaseline, 
    BaselineMetadata, 
    BaselineStatus,
    LoadCondition,
    TrendStatus
)

logger = logging.getLogger(__name__)


class BaselineService:
    """
    Service for managing tractor-specific audio baselines
    """
    
    # MFCC extraction parameters (must match training)
    SAMPLE_RATE = 22050
    N_MFCC = 20
    HOP_LENGTH = 512
    N_FFT = 2048
    
    # Thresholds for anomaly detection (in standard deviations)
    THRESHOLDS = {
        "normal": 2.0,      # < 2σ = Normal
        "watch": 2.5,       # 2-2.5σ = Watch
        "warning": 3.0,     # 2.5-3σ = Warning
        "critical": 3.0     # > 3σ = Critical
    }
    
    def __init__(self):
        logger.info("🎯 Baseline Service initialized")
    
    # ========================================================================
    # BASELINE CREATION
    # ========================================================================
    
    async def start_baseline_collection(
        self,
        tractor_id: str,
        target_samples: int = 5,
        BaselineMetadataModel = BaselineMetadata
    ) -> BaselineMetadata:
        """Start collecting baseline samples for a tractor"""
        logger.info(f"📝 Starting baseline collection for {tractor_id}")
        
        # Check if already collecting
        existing = await BaselineMetadataModel.find_one({
            "tractor_id": tractor_id,
            "status": BaselineStatus.ESTABLISHING
        })
        
        if existing:
            logger.warning(f"⚠️  Baseline collection already in progress for {tractor_id}")
            return existing
        
        # Create new metadata
        metadata = BaselineMetadataModel(
            tractor_id=tractor_id,
            target_samples=target_samples,
            collected_samples=0,
            sample_files=[],
            status=BaselineStatus.ESTABLISHING,
            started_at=datetime.utcnow()
        )
        
        await metadata.insert()
        logger.info(f"✅ Baseline collection started: {target_samples} samples needed")
        return metadata
    
    async def add_baseline_sample(
        self,
        tractor_id: str,
        audio_file_path: str,
        BaselineMetadataModel = BaselineMetadata
    ) -> Dict:
        """Add an audio sample to baseline collection"""
        logger.info(f"➕ Adding baseline sample for {tractor_id}")
        
        # Get metadata
        metadata = await BaselineMetadataModel.find_one({
            "tractor_id": tractor_id,
            "status": BaselineStatus.ESTABLISHING
        })
        
        if not metadata:
            raise ValueError(f"No active baseline collection for {tractor_id}. Start collection first.")
        
        # Add sample
        metadata.sample_files.append(audio_file_path)
        metadata.collected_samples += 1
        
        await metadata.save()
        
        logger.info(f"✅ Sample added: {metadata.collected_samples}/{metadata.target_samples}")
        
        return {
            "tractor_id": tractor_id,
            "collected_samples": metadata.collected_samples,
            "target_samples": metadata.target_samples,
            "progress": f"{metadata.collected_samples}/{metadata.target_samples}",
            "ready_to_finalize": metadata.collected_samples >= metadata.target_samples
        }
    
    async def finalize_baseline(
        self,
        tractor_id: str,
        tractor_hours: float,
        load_condition: LoadCondition = LoadCondition.NORMAL,
        notes: str = "",
        TractorBaselineModel = TractorBaseline,
        BaselineMetadataModel = BaselineMetadata
    ) -> TractorBaseline:
        """Calculate and activate baseline from collected samples"""
        logger.info(f"🎯 Finalizing baseline for {tractor_id}")
        
        # Get metadata
        metadata = await BaselineMetadataModel.find_one({
            "tractor_id": tractor_id,
            "status": BaselineStatus.ESTABLISHING
        })
        
        if not metadata:
            raise ValueError(f"No active baseline collection for {tractor_id}")
        
        if metadata.collected_samples < 3:
            raise ValueError(f"Need at least 3 samples. Currently have: {metadata.collected_samples}")
        
        # Extract MFCC from all samples
        logger.info(f"📊 Extracting features from {metadata.collected_samples} samples...")
        all_mfccs = []
        
        for sample_path in metadata.sample_files:
            try:
                mfcc = self.extract_mfcc_features(sample_path)
                all_mfccs.append(mfcc)
            except Exception as e:
                logger.warning(f"⚠️  Could not process {sample_path}: {e}")
        
        if len(all_mfccs) < 3:
            raise ValueError(f"Could not extract features from enough samples. Got: {len(all_mfccs)}")
        
        # Calculate baseline statistics
        logger.info("📈 Calculating baseline statistics...")
        baseline_mean, baseline_std, confidence = self._calculate_baseline_stats(all_mfccs)
        
        # Archive any existing active baseline
        await self._archive_existing_baseline(tractor_id, TractorBaselineModel)
        
        # Create new baseline
        baseline = TractorBaselineModel(
            tractor_id=tractor_id,
            baseline_mean=baseline_mean.tolist(),
            baseline_std=baseline_std.tolist(),
            tractor_hours=tractor_hours,
            num_samples=len(all_mfccs),
            sample_files=metadata.sample_files,
            confidence=confidence,
            load_condition=load_condition,
            status=BaselineStatus.ACTIVE,
            is_active=True,
            notes=notes,
            created_at=datetime.utcnow()
        )
        
        await baseline.insert()
        
        # Update metadata
        metadata.status = BaselineStatus.ACTIVE
        metadata.baseline_id = str(baseline.id)
        metadata.completed_at = datetime.utcnow()
        await metadata.save()
        
        logger.info(f"✅ Baseline finalized! ID: {baseline.id}, Confidence: {confidence:.2%}")
        return baseline
    
    # ========================================================================
    # FEATURE EXTRACTION
    # ========================================================================
    
    def extract_mfcc_features(self, audio_path: str) -> np.ndarray:
        """Extract MFCC features from audio file"""
        # Load audio
        y, sr = librosa.load(audio_path, sr=self.SAMPLE_RATE, duration=10.0)
        
        # Extract MFCCs
        mfcc = librosa.feature.mfcc(
            y=y,
            sr=sr,
            n_mfcc=self.N_MFCC,
            hop_length=self.HOP_LENGTH,
            n_fft=self.N_FFT
        )
        
        # Flatten to match model input
        mfcc_flat = mfcc.flatten()
        
        return mfcc_flat
    
    def _calculate_baseline_stats(
        self,
        mfcc_list: List[np.ndarray]
    ) -> Tuple[np.ndarray, np.ndarray, float]:
        """Calculate baseline mean, std, and confidence"""
        # Stack all samples
        mfcc_matrix = np.vstack(mfcc_list)
        
        # Calculate statistics
        baseline_mean = np.mean(mfcc_matrix, axis=0)
        baseline_std = np.std(mfcc_matrix, axis=0)
        
        # Calculate confidence based on consistency
        avg_std = np.mean(baseline_std)
        confidence = max(0.5, min(1.0, 1.0 - (avg_std / 10.0)))
        
        return baseline_mean, baseline_std, confidence
    
    # ========================================================================
    # DEVIATION CALCULATION
    # ========================================================================
    
    def calculate_deviation(
        self,
        new_mfcc: np.ndarray,
        baseline_mean: np.ndarray,
        baseline_std: np.ndarray
    ) -> Dict:
        """Calculate how much new audio deviates from baseline"""
        # Flatten MFCC arrays to 1D for comparison (handle 2D MFCC features)
        if new_mfcc.ndim == 2:
            new_mfcc = new_mfcc.flatten()
        if baseline_mean.ndim == 2:
            baseline_mean = baseline_mean.flatten()
        if baseline_std.ndim == 2:
            baseline_std = baseline_std.flatten()
            
        # Ensure same length
        min_len = min(len(new_mfcc), len(baseline_mean), len(baseline_std))
        new_mfcc = new_mfcc[:min_len]
        baseline_mean = baseline_mean[:min_len]
        baseline_std = baseline_std[:min_len]
        
        # Avoid division by zero - replace zero std with small value
        baseline_std = np.where(baseline_std == 0, 1e-6, baseline_std)
        
        # Calculate z-scores (number of standard deviations away)
        z_scores = np.abs((new_mfcc - baseline_mean) / baseline_std)
        
        # Calculate metrics
        average_deviation = float(np.mean(z_scores))
        max_deviation = float(np.max(z_scores))
        
        # Count anomalous features (> 2σ)
        anomalous_features = np.sum(z_scores > 2.0)
        percentage_anomalous = (anomalous_features / len(z_scores)) * 100
        
        return {
            "average_deviation": average_deviation,
            "max_deviation": max_deviation,
            "percentage_anomalous": float(percentage_anomalous),
            "num_anomalous_features": int(anomalous_features),
            "total_features": len(z_scores)
        }
    
    def combine_scores(
        self,
        resnet_score: float,
        deviation_score: float,
        resnet_weight: float = 0.6,
        baseline_weight: float = 0.4
    ) -> Dict:
        """Combine ResNet and baseline deviation scores"""
        # Normalize deviation score to 0-1 (3σ = 1.0)
        normalized_deviation = min(1.0, deviation_score / 3.0)
        
        # Weighted combination
        combined_score = (resnet_weight * resnet_score) + (baseline_weight * normalized_deviation)
        
        # Determine status
        if deviation_score < self.THRESHOLDS["normal"]:
            status = TrendStatus.NORMAL
            recommendation = "No action needed - operating normally"
        elif deviation_score < self.THRESHOLDS["watch"]:
            status = TrendStatus.WATCH
            recommendation = "Monitor closely - slight deviation detected"
        elif deviation_score < self.THRESHOLDS["warning"]:
            status = TrendStatus.WARNING
            recommendation = "Schedule inspection - sound differs from baseline"
        else:
            status = TrendStatus.CRITICAL
            recommendation = "Urgent: Schedule maintenance - significant deviation detected"
        
        return {
            "combined_score": float(combined_score),
            "status": status,
            "deviation_score": float(deviation_score),
            "resnet_score": float(resnet_score),
            "recommendation": recommendation
        }
    
    # ========================================================================
    # BASELINE MANAGEMENT
    # ========================================================================
    
    async def get_active_baseline(
        self,
        tractor_id: str,
        TractorBaselineModel = TractorBaseline
    ) -> Optional[TractorBaseline]:
        """Get active baseline for a tractor"""
        baseline = await TractorBaselineModel.find_one({
            "tractor_id": tractor_id,
            "is_active": True,
            "status": BaselineStatus.ACTIVE
        })
        
        return baseline
    
    async def get_baseline_status(
        self,
        tractor_id: str,
        TractorBaselineModel = TractorBaseline,
        BaselineMetadataModel = BaselineMetadata
    ) -> Dict:
        """Get comprehensive baseline status for a tractor"""
        # Check for active baseline
        baseline = await self.get_active_baseline(tractor_id, TractorBaselineModel)
        
        if baseline:
            return {
                "has_baseline": True,
                "status": "active",
                "baseline_id": str(baseline.id),
                "created_at": baseline.created_at,
                "tractor_hours": baseline.tractor_hours,
                "num_samples": baseline.num_samples,
                "confidence": baseline.confidence,
                "load_condition": baseline.load_condition
            }
        
        # Check for in-progress collection
        metadata = await BaselineMetadataModel.find_one({
            "tractor_id": tractor_id,
            "status": BaselineStatus.ESTABLISHING
        })
        
        if metadata:
            return {
                "has_baseline": False,
                "status": "collecting",
                "collected_samples": metadata.collected_samples,
                "target_samples": metadata.target_samples,
                "progress": f"{metadata.collected_samples}/{metadata.target_samples}",
                "started_at": metadata.started_at,
                "ready_to_finalize": metadata.collected_samples >= metadata.target_samples
            }
        
        # No baseline
        return {
            "has_baseline": False,
            "status": "none",
            "message": "No baseline created yet. Start collection to enable personalized analysis."
        }
    
    async def _archive_existing_baseline(
        self,
        tractor_id: str,
        TractorBaselineModel = TractorBaseline
    ) -> None:
        """Archive any existing active baseline"""
        existing = await TractorBaselineModel.find_one({
            "tractor_id": tractor_id,
            "is_active": True
        })
        
        if existing:
            logger.info(f"📦 Archiving old baseline: {existing.id}")
            existing.is_active = False
            existing.status = BaselineStatus.ARCHIVED
            await existing.save()
    
    async def delete_baseline(
        self,
        tractor_id: str,
        TractorBaselineModel = TractorBaseline,
        BaselineMetadataModel = BaselineMetadata
    ) -> Dict:
        """Delete baseline and collection metadata"""
        logger.info(f"🗑️  Deleting baseline for {tractor_id}")
        
        # Delete active baseline
        baseline = await self.get_active_baseline(tractor_id, TractorBaselineModel)
        if baseline:
            await baseline.delete()
        
        # Delete metadata
        metadata = await BaselineMetadataModel.find_one({
            "tractor_id": tractor_id,
            "status": BaselineStatus.ESTABLISHING
        })
        if metadata:
            await metadata.delete()
        
        return {
            "message": f"Baseline deleted for {tractor_id}",
            "deleted_baseline": baseline is not None,
            "deleted_metadata": metadata is not None
        }


# Create singleton instance
baseline_service = BaselineService()