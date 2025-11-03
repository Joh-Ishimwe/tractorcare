"""
ML Service for Audio Prediction
Uses ResNet CNN Transfer Learning Model
"""

import librosa
import numpy as np
import os
import gdown
from pathlib import Path
import logging
import tensorflow as tf
from tensorflow import keras
from keras.saving import register_keras_serializable
from typing import Dict, Optional

# Configure logging
logger = logging.getLogger(__name__)


@register_keras_serializable()
class FocalLoss(tf.keras.losses.Loss):
    """Custom Focal Loss for handling class imbalance"""
    
    def __init__(self, gamma=2.0, alpha=0.75, name="FocalLoss", **kwargs):
        super().__init__(name=name, **kwargs)
        self.gamma = gamma
        self.alpha = alpha
    
    def call(self, y_true, y_pred):
        y_pred = tf.clip_by_value(y_pred, 1e-7, 1 - 1e-7)
        pt = y_true * y_pred + (1 - y_true) * (1 - y_pred)
        w = self.alpha * y_true + (1 - self.alpha) * (1 - y_true)
        return -tf.reduce_mean(w * tf.pow(1.0 - pt, self.gamma) * tf.math.log(pt))
    
    def get_config(self):
        config = super().get_config()
        config.update({"gamma": self.gamma, "alpha": self.alpha})
        return config


class MLService:
    """Machine Learning service using ResNet CNN Transfer Learning"""
    
    # Google Drive file ID for  model
    RESNET_DRIVE_ID = "1afNUV4GBuUwYYzqECAJhjUsZFXDh3CqB"
    
    # ResNet model configuration
    CONFIG = {
        "sample_rate": 16000,
        "duration": 10,
        "n_mfcc": 40,
        "max_len": 100,
        "apply_highpass": False
    }
    
    def __init__(self):
        self.model = None
        self.model_dir = Path("temp_models")
        self.model_dir.mkdir(exist_ok=True)
        
        # Tractor-specific models directory
        self.tractors_dir = self.model_dir / "tractors"
        self.tractors_dir.mkdir(exist_ok=True)
        
        logger.info("🚀 Initializing ML Service...")
        self._download_and_load_model()
    
    def _download_from_drive(self, file_id: str, output_path: str) -> bool:
        """Download file from Google Drive"""
        import time
        max_retries = 3
        retry_count = 0
        
        while retry_count < max_retries:
            try:
                logger.info(f"📥 Downloading from Google Drive (attempt {retry_count + 1}/{max_retries}): {output_path}")
                url = f"https://drive.google.com/uc?id={file_id}"
                
                # Try with different gdown parameter combinations for compatibility
                try:
                    # Try newer gdown API first
                    gdown.download(url, output_path, quiet=False, fuzzy=True)
                except TypeError:
                    # Fallback to older gdown API without timeout/fuzzy parameters
                    gdown.download(url, output_path, quiet=False)
                    
                logger.info(f"✅ Downloaded: {output_path}")
                return True
            except Exception as e:
                retry_count += 1
                logger.error(f"❌ Error downloading {output_path} (attempt {retry_count}): {e}")
                if retry_count < max_retries:
                    wait_time = retry_count * 10  # 10s, 20s, 30s
                    logger.info(f"⏳ Retrying in {wait_time} seconds...")
                    time.sleep(wait_time)
                else:
                    logger.error(f"❌ Failed to download after {max_retries} attempts")
                    
        return False
    
    def _download_and_load_model(self):
        """Download and load ResNet transfer learning model"""
        try:
            logger.info("🔍 Checking for ResNet model...")
            
            model_path = self.model_dir / "tractor_resnet_transfer.h5"
            
            # Try to find model in multiple locations (for production compatibility)
            possible_paths = [
                model_path,
                Path("tractor_resnet_transfer.h5"),  # Root directory
                Path("temp_models") / "tractor_resnet_transfer.h5",  # Explicit temp_models
                Path("app") / "temp_models" / "tractor_resnet_transfer.h5",  # App subdirectory
            ]
            
            model_found = False
            actual_model_path = None
            
            # Check if model exists in any of the possible locations
            for path in possible_paths:
                if path.exists():
                    actual_model_path = path
                    model_found = True
                    logger.info(f"✅ ResNet model found at: {path}")
                    break
            
            # Download if not exists
            if not model_found:
                logger.info("📦 ResNet model not found locally, downloading from Google Drive...")
                success = self._download_from_drive(self.RESNET_DRIVE_ID, str(model_path))
                if not success:
                    logger.warning("⚠️ Failed to download ResNet model from Google Drive")
                    logger.info("🔄 Service will continue without ML model (fallback mode)")
                    self.model = None
                    return
                actual_model_path = model_path
            
            # Load model with custom objects
            if actual_model_path and actual_model_path.exists():
                try:
                    # Register FocalLoss before loading
                    custom_objects = {'FocalLoss': FocalLoss}
                    
                    self.model = keras.models.load_model(
                        actual_model_path,
                        custom_objects=custom_objects
                    )
                    logger.info("✅ ResNet transfer learning model loaded successfully")
                    logger.info("🎉 ML Service ready for predictions!")
                except Exception as load_error:
                    logger.error(f"❌ Error loading model from {actual_model_path}: {load_error}")
                    logger.info("🔄 Service will continue without ML model (fallback mode)")
                    self.model = None
            else:
                logger.warning("⚠️ ResNet model file not found after download attempt")
                logger.info("🔄 Service will continue without ML model (fallback mode)")
                self.model = None
                
        except Exception as e:
            logger.error(f"❌ Error in model initialization: {e}")
            logger.info("🔄 Service will continue without ML model (fallback mode)")
            self.model = None
    
    def extract_mfcc_features(self, file_path: str) -> np.ndarray:
        """
        Extract MFCC features for ResNet model
        Returns MFCC of shape (n_mfcc, max_len)
        """
        try:
            # Load audio
            audio, sr = librosa.load(
                file_path,
                sr=self.CONFIG["sample_rate"],
                duration=self.CONFIG["duration"]
            )
            
            # Extract MFCCs
            mfcc = librosa.feature.mfcc(
                y=audio,
                sr=sr,
                n_mfcc=self.CONFIG["n_mfcc"]
            )
            
            # Pad or truncate to fixed length
            max_len = self.CONFIG["max_len"]
            if mfcc.shape[1] < max_len:
                pad_width = max_len - mfcc.shape[1]
                mfcc = np.pad(mfcc, pad_width=((0, 0), (0, pad_width)), mode='constant')
            else:
                mfcc = mfcc[:, :max_len]
            
            return mfcc
            
        except Exception as e:
            logger.error(f"❌ Error extracting MFCC: {e}")
            raise
    
    async def predict_audio(self, audio_path: str, tractor_id: str) -> dict:
        """
        Predict tractor condition from audio using ResNet transfer learning
        
        Args:
            audio_path: Path to audio file
            tractor_id: Tractor identifier
            
        Returns:
            Dictionary with prediction results
        """
        try:
            logger.info(f"🔮 Making prediction for tractor: {tractor_id}")
            
            if self.model is None:
                logger.warning("⚠️ ML model not available, using fallback prediction")
                # Fallback prediction - basic audio analysis
                return await self._fallback_prediction(audio_path, tractor_id)
            
            # Extract MFCC features
            mfcc = self.extract_mfcc_features(audio_path)
            
            # Prepare input (add batch and channel dimensions)
            X = np.expand_dims(np.expand_dims(mfcc, 0), -1)
            
            # Predict
            probability = self.model.predict(X, verbose=0)[0][0]
            is_anomaly = probability > 0.5
            confidence = probability if is_anomaly else 1 - probability
            
            # Classify anomaly type based on probability
            if probability < 0.5:
                anomaly_type = None
            elif probability > 0.9:
                anomaly_type = "critical_anomaly"
            elif probability > 0.75:
                anomaly_type = "high_vibration"
            elif probability > 0.6:
                anomaly_type = "unusual_noise"
            else:
                anomaly_type = "minor_anomaly"
            
            # Map to standard class names (Normal/Abnormal)
            prediction_class = "Abnormal" if is_anomaly else "Normal"
            anomaly_score = float(probability)
            
            logger.info(f"✅ Prediction: {prediction_class} (confidence: {confidence:.2%})")
            if anomaly_type:
                logger.info(f"   Anomaly type: {anomaly_type}")
            
            return {
                "prediction_class": prediction_class,
                "confidence": float(confidence),
                "anomaly_score": anomaly_score,
                "anomaly_type": anomaly_type,
                "tractor_id": tractor_id,
                "ml_model": "ResNet_Transfer_Learning",
                "features_count": self.CONFIG["n_mfcc"] * self.CONFIG["max_len"]
            }
            
        except Exception as e:
            logger.error(f"❌ Prediction error: {e}")
            raise
    
    async def _fallback_prediction(self, audio_path: str, tractor_id: str) -> dict:
        """
        Fallback prediction using basic audio analysis when ML model is not available
        
        Args:
            audio_path: Path to audio file
            tractor_id: Tractor identifier
            
        Returns:
            Dictionary with basic prediction results
        """
        try:
            logger.info(f"🔄 Using fallback prediction for tractor: {tractor_id}")
            
            # Basic audio analysis using librosa
            audio, sr = librosa.load(
                audio_path,
                sr=self.CONFIG["sample_rate"],
                duration=self.CONFIG["duration"]
            )
            
            # Calculate basic audio features
            # RMS energy (indicator of loudness)
            rms = librosa.feature.rms(y=audio)[0]
            avg_rms = np.mean(rms)
            
            # Zero crossing rate (indicator of noise/roughness)
            zcr = librosa.feature.zero_crossing_rate(audio)[0]
            avg_zcr = np.mean(zcr)
            
            # Spectral centroid (brightness/harshness indicator)
            centroid = librosa.feature.spectral_centroid(y=audio, sr=sr)[0]
            avg_centroid = np.mean(centroid)
            
            # Simple heuristic-based prediction
            # These thresholds are basic approximations
            anomaly_indicators = 0
            
            if avg_rms > 0.1:  # High energy
                anomaly_indicators += 1
            if avg_zcr > 0.15:  # High zero crossing rate (noisy)
                anomaly_indicators += 1
            if avg_centroid > 3000:  # High spectral centroid (harsh)
                anomaly_indicators += 1
                
            # Predict based on indicators
            probability = min(0.3 + (anomaly_indicators * 0.2), 0.9)  # Cap at 0.9
            is_anomaly = anomaly_indicators >= 2
            confidence = 0.6  # Lower confidence for fallback prediction
            
            # Basic anomaly classification
            if not is_anomaly:
                anomaly_type = None
            elif anomaly_indicators >= 3:
                anomaly_type = "high_vibration"
            else:
                anomaly_type = "minor_anomaly"
            
            prediction_class = "Abnormal" if is_anomaly else "Normal"
            
            logger.info(f"🔄 Fallback prediction: {prediction_class} (confidence: {confidence:.2%})")
            logger.warning("⚠️ Using basic audio analysis - results may be less accurate")
            
            return {
                "prediction_class": prediction_class,
                "confidence": confidence,
                "anomaly_score": float(probability),
                "anomaly_type": anomaly_type,
                "tractor_id": tractor_id,
                "ml_model": "Fallback_Basic_Analysis",
                "features_count": 3,  # RMS, ZCR, Spectral Centroid
                "warning": "ML model unavailable - using basic audio analysis"
            }
            
        except Exception as e:
            logger.error(f"❌ Fallback prediction error: {e}")
            # Return a safe default
            return {
                "prediction_class": "Unknown",
                "confidence": 0.0,
                "anomaly_score": 0.5,
                "anomaly_type": None,
                "tractor_id": tractor_id,
                "ml_model": "Error_Fallback",
                "features_count": 0,
                "error": str(e)
            }
    
    def get_model_info(self) -> dict:
        """Get information about the loaded model"""
        if self.model is not None:
            return {
                "model_name": "ResNet CNN Transfer Learning",
                "model_loaded": True,
                "model_type": "Deep Learning CNN",
                "architecture": "ResNet with Focal Loss",
                "training_data": "MIMII Industrial Sounds + Tractor Audio",
                "features": {
                    "type": "MFCC Spectrograms",
                    "n_mfcc": self.CONFIG["n_mfcc"],
                    "timesteps": self.CONFIG["max_len"],
                    "total_features": self.CONFIG["n_mfcc"] * self.CONFIG["max_len"]
                },
                "preprocessing": {
                    "sample_rate": self.CONFIG["sample_rate"],
                    "duration": self.CONFIG["duration"],
                    "highpass_filter": self.CONFIG["apply_highpass"]
                },
                "classes": ["Normal", "Abnormal"],
                "anomaly_types": [
                    "minor_anomaly (0.5-0.6)",
                    "unusual_noise (0.6-0.75)",
                    "high_vibration (0.75-0.9)",
                    "critical_anomaly (>0.9)"
                ],
                "source": "Google Drive",
                "file_id": self.RESNET_DRIVE_ID
            }
        else:
            return {
                "model_name": "Fallback Basic Audio Analysis",
                "model_loaded": False,
                "model_type": "Basic Signal Processing",
                "architecture": "RMS + Zero Crossing Rate + Spectral Centroid",
                "training_data": "Heuristic Rules",
                "features": {
                    "type": "Basic Audio Features",
                    "features": ["RMS Energy", "Zero Crossing Rate", "Spectral Centroid"],
                    "total_features": 3
                },
                "preprocessing": {
                    "sample_rate": self.CONFIG["sample_rate"],
                    "duration": self.CONFIG["duration"]
                },
                "classes": ["Normal", "Abnormal", "Unknown"],
                "anomaly_types": [
                    "minor_anomaly",
                    "high_vibration"
                ],
                "warning": "ML model unavailable - using fallback analysis",
                "note": "Reduced accuracy compared to ML model"
            }


# Create a global instance
ml_service = MLService()
