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
    # RESNET_DRIVE_ID = "17OnJBfLt21PAbESv2-krhYZ0X2YbRcyc"
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
                gdown.download(url, output_path, quiet=False, timeout=300)
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
            
            # model_path = self.model_dir / "tractor_resnet_final.keras"
            model_path = self.model_dir / "tractor_resnet_transfer.h5"

            
            # Download if not exists
            if not model_path.exists():
                logger.info("📦 ResNet model not found locally, downloading from Google Drive...")
                success = self._download_from_drive(self.RESNET_DRIVE_ID, str(model_path))
                if not success:
                    raise Exception("Failed to download ResNet model from Google Drive")
            else:
                logger.info("✅ ResNet model found in cache")
            
            # Load model with custom objects
            if model_path.exists():
                # Register FocalLoss before loading
                custom_objects = {'FocalLoss': FocalLoss}
                
                self.model = keras.models.load_model(
                    model_path,
                    custom_objects=custom_objects
                )
                logger.info("✅ ResNet transfer learning model loaded successfully")
                logger.info("🎉 ML Service ready for predictions!")
            else:
                raise Exception("ResNet model file not found after download attempt")
                
        except Exception as e:
            logger.error(f"❌ Error loading model: {e}")
            raise
    
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
                raise ValueError("Model not loaded. Please check Google Drive connection.")
            
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
    
    def get_model_info(self) -> dict:
        """Get information about the loaded model"""
        return {
            "model_name": "ResNet CNN Transfer Learning",
            "model_loaded": self.model is not None,
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


# Create a global instance
ml_service = MLService()
